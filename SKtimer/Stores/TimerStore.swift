import Combine
import Foundation

struct MeaningfulPromptAnswerEvent: Identifiable, Equatable {
    var id: UUID { promptID }

    var promptID: UUID
    var sourceTimerID: UUID
    var timer: TimerRecord?
    var sourceVisibleIndex: Int
    var record: MeaningfulTimeRecord?
    var wasMeaningful: Bool
    var answeredAt: Date
}

@MainActor
final class TimerStore: ObservableObject {
    @Published private(set) var timers: [TimerRecord]
    @Published private(set) var recentDurations: [Int]
    @Published private(set) var pendingMeaningfulPrompts: [PendingMeaningfulPrompt]
    @Published private(set) var meaningfulTimeRecords: [MeaningfulTimeRecord]
    @Published private(set) var latestMeaningfulPromptAnswer: MeaningfulPromptAnswerEvent?
    @Published private(set) var now: Date

    private static let recentDurationLimit = 6

    private let persistence: TimerPersistence
    private let notificationScheduler: TimerNotificationScheduling
    private let soundPlayer: TimerSoundPlaying
    private let completionDelayOverrideForTesting: TimeInterval?
    private var completionTimer: Timer?

    init(
        persistence: TimerPersistence,
        notificationScheduler: TimerNotificationScheduling,
        soundPlayer: TimerSoundPlaying,
        completionDelayOverrideForTesting: TimeInterval? = nil,
        now: Date = Date()
    ) {
        self.persistence = persistence
        self.notificationScheduler = notificationScheduler
        self.soundPlayer = soundPlayer
        self.completionDelayOverrideForTesting = completionDelayOverrideForTesting
        self.now = now

        let snapshot = persistence.loadSnapshot()
        self.timers = snapshot?.timers ?? []
        self.recentDurations = Self.normalizedRecentDurations(snapshot?.recentDurations ?? [])
        self.pendingMeaningfulPrompts = Self.sortedPendingPrompts(snapshot?.pendingMeaningfulPrompts ?? [])
        self.meaningfulTimeRecords = snapshot?.meaningfulTimeRecords ?? []

        recoverExpiredTimers(at: now)
    }

    deinit {
        completionTimer?.invalidate()
    }

    var activeTimers: [TimerRecord] {
        timers.filter { $0.state != .completed }
    }

    var visibleTimers: [TimerRecord] {
        let pendingTimerIDs = Set(pendingMeaningfulPrompts.map(\.sourceTimerID))
        return timers.filter { timer in
            timer.state != .completed || pendingTimerIDs.contains(timer.id)
        }
    }

    var completedTimers: [TimerRecord] {
        timers.filter { $0.state == .completed }
    }

    var nextRunningTimer: TimerRecord? {
        timers
            .filter(\.isRunning)
            .min { $0.endDate < $1.endDate }
    }

    var menuBarTitle: String {
        menuBarTitle(at: Date())
    }

    var nextMeaningfulPrompt: PendingMeaningfulPrompt? {
        pendingMeaningfulPrompts.first
    }

    var meaningfulStats: MeaningfulTimeStats {
        meaningfulStats(at: now)
    }

    func menuBarTitle(at date: Date) -> String {
        guard let timer = nextRunningTimer else {
            return String(localized: "app.name")
        }

        return TimerDurationFormatter.menuBar(seconds: timer.remainingSeconds(at: date))
    }

    func startClock() {
        scheduleNextCompletionTimer()
    }

    func stopClock() {
        completionTimer?.invalidate()
        completionTimer = nil
    }

    @discardableResult
    func startTimer(durationMinutes: Int, at date: Date? = nil) -> TimerRecord {
        let date = date ?? Date()
        now = date

        var timer = TimerRecord(durationMinutes: durationMinutes, now: date)
        if let completionDelayOverrideForTesting {
            timer.endDate = date.addingTimeInterval(completionDelayOverrideForTesting)
        }
        timers.insert(timer, at: 0)
        rememberDuration(durationMinutes)
        persist()
        notificationScheduler.scheduleCompletion(for: timer)
        scheduleNextCompletionTimer()
        return timer
    }

    func pauseTimer(id: UUID, at date: Date? = nil) {
        let date = date ?? Date()
        now = date
        mutateTimer(id: id) { timer in
            timer.pause(at: date)
            notificationScheduler.cancelNotification(for: id)
        }
        scheduleNextCompletionTimer()
    }

    func resumeTimer(id: UUID, at date: Date? = nil) {
        let date = date ?? Date()
        now = date
        mutateTimer(id: id) { timer in
            timer.resume(at: date)
            notificationScheduler.scheduleCompletion(for: timer)
        }
        scheduleNextCompletionTimer()
    }

    func restartTimer(id: UUID, at date: Date? = nil) {
        let date = date ?? Date()
        now = date
        mutateTimer(id: id) { timer in
            timer.restart(at: date)
            if let completionDelayOverrideForTesting {
                timer.endDate = date.addingTimeInterval(completionDelayOverrideForTesting)
            }
            rememberDuration(timer.durationMinutes)
            notificationScheduler.scheduleCompletion(for: timer)
        }
        scheduleNextCompletionTimer()
    }

    func deleteTimer(id: UUID) {
        timers.removeAll { $0.id == id }
        pendingMeaningfulPrompts.removeAll { $0.sourceTimerID == id }
        notificationScheduler.cancelNotification(for: id)
        persist()
        scheduleNextCompletionTimer()
    }

    func clearCompletedTimers() {
        let completedIDs = timers.filter(\.isFinished).map(\.id)
        timers.removeAll { $0.isFinished }
        pendingMeaningfulPrompts.removeAll { completedIDs.contains($0.sourceTimerID) }
        completedIDs.forEach(notificationScheduler.cancelNotification)
        persist()
        scheduleNextCompletionTimer()
    }

    func tick(at date: Date = Date()) {
        now = date
        var completedTimers: [TimerRecord] = []

        for index in timers.indices where timers[index].completeIfDue(at: date) {
            completedTimers.append(timers[index])
        }

        guard !completedTimers.isEmpty else {
            return
        }

        enqueueMeaningfulPrompts(for: completedTimers, createdAt: date)
        completedTimers.forEach(notificationScheduler.deliverCompletion)

        if !notificationScheduler.canDeliverAudibleNotifications {
            soundPlayer.playCompletionSound()
        }

        persist()
        scheduleNextCompletionTimer()
    }

    func answerMeaningfulPrompt(id: UUID, wasMeaningful: Bool, at date: Date = Date()) {
        guard let index = pendingMeaningfulPrompts.firstIndex(where: { $0.id == id }) else {
            return
        }

        let visibleTimersBeforeAnswer = visibleTimers
        let prompt = pendingMeaningfulPrompts.remove(at: index)
        let sourceTimer = timers.first { $0.id == prompt.sourceTimerID }
        let sourceVisibleIndex = visibleTimersBeforeAnswer.firstIndex { $0.id == prompt.sourceTimerID } ?? 0
        var meaningfulRecord: MeaningfulTimeRecord?

        if wasMeaningful {
            let record = MeaningfulTimeRecord(
                promptID: prompt.id,
                sourceTimerID: prompt.sourceTimerID,
                durationSeconds: prompt.durationSeconds,
                completedAt: prompt.completedAt,
                answeredAt: date,
                wasMeaningful: true,
                focusSegments: prompt.focusSegments
            )
            meaningfulTimeRecords.append(record)
            meaningfulRecord = record
        }

        timers.removeAll { $0.id == prompt.sourceTimerID }
        notificationScheduler.cancelNotification(for: prompt.sourceTimerID)
        latestMeaningfulPromptAnswer = MeaningfulPromptAnswerEvent(
            promptID: prompt.id,
            sourceTimerID: prompt.sourceTimerID,
            timer: sourceTimer,
            sourceVisibleIndex: sourceVisibleIndex,
            record: meaningfulRecord,
            wasMeaningful: wasMeaningful,
            answeredAt: date
        )
        persist()
        scheduleNextCompletionTimer()
    }

    private func scheduleNextCompletionTimer() {
        completionTimer?.invalidate()
        completionTimer = nil

        guard let nextTimer = nextRunningTimer else {
            return
        }

        let interval = max(0.1, nextTimer.endDate.timeIntervalSince(Date()))
        completionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    func meaningfulStats(at date: Date, calendar: Calendar = .current) -> MeaningfulTimeStats {
        let meaningfulRecords = meaningfulTimeRecords.filter(\.wasMeaningful)

        return MeaningfulTimeStats(
            todaySeconds: Self.totalSeconds(in: Self.rollingInterval(for: .daily, endingAt: date), records: meaningfulRecords),
            weekSeconds: Self.totalSeconds(in: Self.rollingInterval(for: .weekly, endingAt: date), records: meaningfulRecords),
            monthSeconds: Self.totalSeconds(in: Self.rollingInterval(for: .monthly, endingAt: date), records: meaningfulRecords)
        )
    }

    func meaningfulChartBars(for period: MeaningfulStatsPeriod, at date: Date? = nil, calendar: Calendar = .current) -> [MeaningfulChartBar] {
        let date = date ?? now
        let meaningfulRecords = meaningfulTimeRecords.filter(\.wasMeaningful)
        let interval = Self.rollingInterval(for: period, endingAt: date)

        return Self.chartBuckets(for: period, in: interval, calendar: calendar).map { bucket in
            MeaningfulChartBar(
                id: "\(period.rawValue)-\(bucket.startAt.timeIntervalSinceReferenceDate)",
                label: Self.chartLabel(for: period, startAt: bucket.startAt, endAt: bucket.endAt, calendar: calendar),
                startAt: bucket.startAt,
                endAt: bucket.endAt,
                seconds: Self.totalSeconds(in: DateInterval(start: bucket.startAt, end: bucket.endAt), records: meaningfulRecords)
            )
        }
    }

    private func mutateTimer(id: UUID, mutation: (inout TimerRecord) -> Void) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutation(&timers[index])
        persist()
    }

    private func rememberDuration(_ durationMinutes: Int) {
        let validDuration = min(max(durationMinutes, TimerRecord.minimumMinutes), TimerRecord.maximumMinutes)
        recentDurations.removeAll { $0 == validDuration }
        recentDurations.insert(validDuration, at: 0)
        recentDurations = Array(recentDurations.prefix(Self.recentDurationLimit))
    }

    private func recoverExpiredTimers(at date: Date) {
        var recoveredTimers: [TimerRecord] = []
        var changed = false

        for index in timers.indices where timers[index].completeIfDue(at: date) {
            notificationScheduler.cancelNotification(for: timers[index].id)
            recoveredTimers.append(timers[index])
            changed = true
        }

        if changed {
            enqueueMeaningfulPrompts(for: recoveredTimers, createdAt: date)
            persist()
        }
    }

    private func enqueueMeaningfulPrompts(for completedTimers: [TimerRecord], createdAt: Date) {
        let prompts = completedTimers
            .sorted { meaningfulCompletedDate(for: $0) < meaningfulCompletedDate(for: $1) }
            .compactMap { timer -> PendingMeaningfulPrompt? in
                let completedAt = meaningfulCompletedDate(for: timer)
                guard !hasMeaningfulPromptOrRecord(for: timer, completedAt: completedAt) else {
                    return nil
                }

                return PendingMeaningfulPrompt(
                    sourceTimerID: timer.id,
                    durationSeconds: timer.durationSeconds,
                    completedAt: completedAt,
                    createdAt: createdAt,
                    focusSegments: timer.focusSegments
                )
            }

        guard !prompts.isEmpty else {
            return
        }

        pendingMeaningfulPrompts.append(contentsOf: prompts)
        pendingMeaningfulPrompts = Self.sortedPendingPrompts(pendingMeaningfulPrompts)
    }

    private func hasMeaningfulPromptOrRecord(for timer: TimerRecord, completedAt: Date) -> Bool {
        let promptExists = pendingMeaningfulPrompts.contains {
            $0.sourceTimerID == timer.id && $0.completedAt == completedAt
        }

        let recordExists = meaningfulTimeRecords.contains {
            $0.sourceTimerID == timer.id && $0.completedAt == completedAt
        }

        return promptExists || recordExists
    }

    private func meaningfulCompletedDate(for timer: TimerRecord) -> Date {
        timer.completedAt ?? timer.endDate
    }

    private func persist() {
        persistence.saveSnapshot(TimerStoreSnapshot(
            timers: timers,
            recentDurations: recentDurations,
            pendingMeaningfulPrompts: pendingMeaningfulPrompts,
            meaningfulTimeRecords: meaningfulTimeRecords
        ))
    }

    private static func normalizedRecentDurations(_ durations: [Int]) -> [Int] {
        var result: [Int] = []

        for duration in durations where (TimerRecord.minimumMinutes...TimerRecord.maximumMinutes).contains(duration) {
            if !result.contains(duration) {
                result.append(duration)
            }

            if result.count == Self.recentDurationLimit {
                break
            }
        }

        return result
    }

    private static func sortedPendingPrompts(_ prompts: [PendingMeaningfulPrompt]) -> [PendingMeaningfulPrompt] {
        prompts.sorted {
            if $0.completedAt == $1.completedAt {
                return $0.createdAt < $1.createdAt
            }

            return $0.completedAt < $1.completedAt
        }
    }

    private static func rollingInterval(for period: MeaningfulStatsPeriod, endingAt date: Date) -> DateInterval {
        DateInterval(start: date.addingTimeInterval(-period.durationSeconds), end: date)
    }

    private static func chartBuckets(for period: MeaningfulStatsPeriod, in interval: DateInterval, calendar: Calendar) -> [(startAt: Date, endAt: Date)] {
        switch period {
        case .daily:
            return calendarAlignedBuckets(in: interval, component: .hour, calendar: calendar)
        case .weekly:
            return calendarAlignedBuckets(in: interval, component: .day, calendar: calendar)
        case .monthly:
            return rollingBuckets(in: interval, dayCount: 7, calendar: calendar)
        }
    }

    private static func calendarAlignedBuckets(in interval: DateInterval, component: Calendar.Component, calendar: Calendar) -> [(startAt: Date, endAt: Date)] {
        let firstBucketStart = calendar.dateInterval(of: component, for: interval.start)?.start ?? interval.start
        var buckets: [(startAt: Date, endAt: Date)] = []
        var cursor = firstBucketStart

        while cursor < interval.end {
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor), next > cursor else {
                break
            }

            let startAt = max(cursor, interval.start)
            let endAt = min(next, interval.end)
            if endAt > startAt {
                buckets.append((startAt, endAt))
            }

            cursor = next
        }

        return buckets
    }

    private static func rollingBuckets(in interval: DateInterval, dayCount: Int, calendar: Calendar) -> [(startAt: Date, endAt: Date)] {
        var buckets: [(startAt: Date, endAt: Date)] = []
        var cursor = interval.start

        while cursor < interval.end {
            guard let next = calendar.date(byAdding: .day, value: dayCount, to: cursor), next > cursor else {
                break
            }

            let endAt = min(next, interval.end)
            buckets.append((cursor, endAt))
            cursor = next
        }

        return buckets
    }

    private static func chartLabel(for period: MeaningfulStatsPeriod, startAt: Date, endAt: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone

        switch period {
        case .daily:
            formatter.dateFormat = "ha"
            return formatter.string(from: startAt).lowercased()
        case .weekly:
            formatter.dateFormat = "E M/d"
            return formatter.string(from: startAt)
        case .monthly:
            formatter.dateFormat = "M/d"
            let startLabel = formatter.string(from: startAt)
            let endLabel = formatter.string(from: endAt.addingTimeInterval(-1))
            return startLabel == endLabel ? startLabel : "\(startLabel)-\(endLabel)"
        }
    }

    private static func totalSeconds(in interval: DateInterval, records: [MeaningfulTimeRecord]) -> Int {
        records.reduce(0) { total, record in
            total + totalSeconds(in: interval, record: record)
        }
    }

    private static func totalSeconds(in interval: DateInterval, record: MeaningfulTimeRecord) -> Int {
        focusSegments(for: record).reduce(0) { total, segment in
            let startAt = max(interval.start, segment.startAt)
            let endAt = min(interval.end, segment.endAt)
            guard endAt > startAt else {
                return total
            }

            return total + Int(endAt.timeIntervalSince(startAt))
        }
    }

    private static func focusSegments(for record: MeaningfulTimeRecord) -> [FocusTimeSegment] {
        if !record.focusSegments.isEmpty {
            return record.focusSegments
        }

        return [
            FocusTimeSegment(
                startAt: record.completedAt.addingTimeInterval(TimeInterval(-record.durationSeconds)),
                endAt: record.completedAt
            )
        ]
    }
}
