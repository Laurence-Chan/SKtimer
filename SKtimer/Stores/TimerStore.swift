import Combine
import Foundation

@MainActor
final class TimerStore: ObservableObject {
    @Published private(set) var timers: [TimerRecord]
    @Published private(set) var recentDurations: [Int]
    @Published private(set) var pendingMeaningfulPrompts: [PendingMeaningfulPrompt]
    @Published private(set) var meaningfulTimeRecords: [MeaningfulTimeRecord]
    @Published private(set) var now: Date

    private let persistence: TimerPersistence
    private let notificationScheduler: TimerNotificationScheduling
    private let soundPlayer: TimerSoundPlaying
    private let completionDelayOverrideForTesting: TimeInterval?
    private var tickerTask: Task<Void, Never>?

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
        tickerTask?.cancel()
    }

    var activeTimers: [TimerRecord] {
        timers.filter { $0.state != .completed }
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
        guard let timer = nextRunningTimer else {
            return String(localized: "app.name")
        }

        return TimerDurationFormatter.menuBar(seconds: timer.remainingSeconds(at: now))
    }

    var nextMeaningfulPrompt: PendingMeaningfulPrompt? {
        pendingMeaningfulPrompts.first
    }

    var meaningfulStats: MeaningfulTimeStats {
        meaningfulStats(at: now)
    }

    func startClock() {
        guard tickerTask == nil else {
            return
        }

        tickerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else {
                    return
                }
                self?.tick()
            }
        }
    }

    func stopClock() {
        tickerTask?.cancel()
        tickerTask = nil
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
        return timer
    }

    func pauseTimer(id: UUID, at date: Date? = nil) {
        mutateTimer(id: id) { timer in
            timer.pause(at: date ?? now)
            notificationScheduler.cancelNotification(for: id)
        }
    }

    func resumeTimer(id: UUID, at date: Date? = nil) {
        mutateTimer(id: id) { timer in
            timer.resume(at: date ?? now)
            notificationScheduler.scheduleCompletion(for: timer)
        }
    }

    func restartTimer(id: UUID, at date: Date? = nil) {
        mutateTimer(id: id) { timer in
            timer.restart(at: date ?? now)
            if let completionDelayOverrideForTesting {
                timer.endDate = (date ?? now).addingTimeInterval(completionDelayOverrideForTesting)
            }
            rememberDuration(timer.durationMinutes)
            notificationScheduler.scheduleCompletion(for: timer)
        }
    }

    func deleteTimer(id: UUID) {
        timers.removeAll { $0.id == id }
        pendingMeaningfulPrompts.removeAll { $0.sourceTimerID == id }
        notificationScheduler.cancelNotification(for: id)
        persist()
    }

    func clearCompletedTimers() {
        let completedIDs = timers.filter(\.isFinished).map(\.id)
        timers.removeAll { $0.isFinished }
        pendingMeaningfulPrompts.removeAll { completedIDs.contains($0.sourceTimerID) }
        completedIDs.forEach(notificationScheduler.cancelNotification)
        persist()
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
    }

    func answerMeaningfulPrompt(id: UUID, wasMeaningful: Bool, at date: Date = Date()) {
        guard let index = pendingMeaningfulPrompts.firstIndex(where: { $0.id == id }) else {
            return
        }

        let prompt = pendingMeaningfulPrompts.remove(at: index)
        meaningfulTimeRecords.append(MeaningfulTimeRecord(
            promptID: prompt.id,
            sourceTimerID: prompt.sourceTimerID,
            durationSeconds: prompt.durationSeconds,
            completedAt: prompt.completedAt,
            answeredAt: date,
            wasMeaningful: wasMeaningful
        ))
        persist()
    }

    func meaningfulStats(at date: Date, calendar: Calendar = .current) -> MeaningfulTimeStats {
        let meaningfulRecords = meaningfulTimeRecords.filter(\.wasMeaningful)

        guard
            let dayInterval = calendar.dateInterval(of: .day, for: date),
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date),
            let monthInterval = calendar.dateInterval(of: .month, for: date)
        else {
            return .empty
        }

        return MeaningfulTimeStats(
            todaySeconds: Self.totalSeconds(in: dayInterval, records: meaningfulRecords),
            weekSeconds: Self.totalSeconds(in: weekInterval, records: meaningfulRecords),
            monthSeconds: Self.totalSeconds(in: monthInterval, records: meaningfulRecords)
        )
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
        recentDurations = Array(recentDurations.prefix(4))
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
                    createdAt: createdAt
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

            if result.count == 4 {
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

    private static func totalSeconds(in interval: DateInterval, records: [MeaningfulTimeRecord]) -> Int {
        records.reduce(0) { total, record in
            interval.contains(record.completedAt) ? total + record.durationSeconds : total
        }
    }
}
