import Foundation
import Testing
@testable import SKtimer

@MainActor
struct SKtimerTests {
    @Test func validatesTimerInput() {
        #expect(TimerInputValidator.durationMinutes(hoursText: "0", minutesText: "1") == .success(1))
        #expect(TimerInputValidator.durationMinutes(hoursText: "8", minutesText: "0") == .success(480))
        #expect(TimerInputValidator.durationMinutes(hoursText: "", minutesText: "") == .failure(.durationTooShort))
        #expect(TimerInputValidator.durationMinutes(hoursText: "1000", minutesText: "0") == .failure(.invalidHours))
        #expect(TimerInputValidator.durationMinutes(hoursText: "0", minutesText: "60") == .failure(.invalidMinutes))
        #expect(TimerInputValidator.durationMinutes(hoursText: "abc", minutesText: "1") == .failure(.invalidHours))
    }

    @Test func timerRecordPausesResumesAndRestarts() {
        let base = Date(timeIntervalSinceReferenceDate: 1_000)
        var timer = TimerRecord(durationMinutes: 25, now: base)

        timer.pause(at: base.addingTimeInterval(300))
        #expect(timer.state == .paused)
        #expect(timer.remainingSeconds(at: base.addingTimeInterval(999)) == 1_200)

        timer.resume(at: base.addingTimeInterval(600))
        #expect(timer.state == .running)
        #expect(timer.remainingSeconds(at: base.addingTimeInterval(600)) == 1_200)

        timer.restart(at: base.addingTimeInterval(900))
        #expect(timer.remainingSeconds(at: base.addingTimeInterval(900)) == 1_500)
        let didComplete = timer.completeIfDue(at: base.addingTimeInterval(2_401))
        #expect(didComplete)
        #expect(timer.state == .completed)
    }

    @Test func recentDurationsUseFourItemMRUOrder() {
        let harness = StoreHarness()
        let store = harness.store

        store.startTimer(durationMinutes: 480)
        store.startTimer(durationMinutes: 25)
        store.startTimer(durationMinutes: 1)
        store.startTimer(durationMinutes: 5)
        #expect(store.recentDurations == [5, 1, 25, 480])

        store.startTimer(durationMinutes: 6)
        #expect(store.recentDurations == [6, 5, 1, 25])

        store.startTimer(durationMinutes: 25)
        #expect(store.recentDurations == [25, 6, 5, 1])
    }

    @Test func storeSchedulesAndCancelsNotificationsForTimerLifecycle() {
        let harness = StoreHarness()
        let store = harness.store
        let timer = store.startTimer(durationMinutes: 10)

        #expect(harness.scheduler.scheduledIDs == [timer.id])

        store.pauseTimer(id: timer.id)
        #expect(harness.scheduler.cancelledIDs.contains(timer.id))

        store.resumeTimer(id: timer.id)
        #expect(harness.scheduler.scheduledIDs.filter { $0 == timer.id }.count == 2)

        store.restartTimer(id: timer.id)
        #expect(harness.scheduler.scheduledIDs.filter { $0 == timer.id }.count == 3)

        store.deleteTimer(id: timer.id)
        #expect(store.timers.isEmpty)
        #expect(harness.scheduler.cancelledIDs.filter { $0 == timer.id }.count >= 2)
    }

    @Test func completedTimerUsesFallbackSoundWhenNotificationsAreUnavailable() {
        let base = Date(timeIntervalSinceReferenceDate: 2_000)
        let harness = StoreHarness(now: base)
        harness.scheduler.canDeliverAudibleNotifications = false

        let timer = harness.store.startTimer(durationMinutes: 1, at: base)
        harness.store.tick(at: base.addingTimeInterval(60))

        #expect(harness.store.timers.first?.state == .completed)
        #expect(harness.scheduler.deliveredIDs == [timer.id])
        #expect(harness.soundPlayer.playCount == 1)
    }

    @Test func completedTimerDeliversImmediateNotificationWhenAllowed() {
        let base = Date(timeIntervalSinceReferenceDate: 2_500)
        let harness = StoreHarness(now: base)
        harness.scheduler.canDeliverAudibleNotifications = true

        let timer = harness.store.startTimer(durationMinutes: 1, at: base)
        harness.store.tick(at: base.addingTimeInterval(60))

        #expect(harness.store.timers.first?.state == .completed)
        #expect(harness.scheduler.deliveredIDs == [timer.id])
        #expect(harness.soundPlayer.playCount == 0)
    }

    @Test func completedTimerCreatesOnePendingMeaningfulPrompt() {
        let base = Date(timeIntervalSinceReferenceDate: 2_600)
        let harness = StoreHarness(now: base)

        let timer = harness.store.startTimer(durationMinutes: 1, at: base)
        harness.store.tick(at: base.addingTimeInterval(60))
        harness.store.tick(at: base.addingTimeInterval(120))

        #expect(harness.store.pendingMeaningfulPrompts.count == 1)
        #expect(harness.store.pendingMeaningfulPrompts.first?.sourceTimerID == timer.id)
        #expect(harness.store.pendingMeaningfulPrompts.first?.durationSeconds == 60)
    }

    @Test func answeringYesAddsMeaningfulTimeToStats() {
        let base = testDate(year: 2026, month: 5, day: 23, hour: 10)
        let harness = StoreHarness(now: base)

        let timer = harness.store.startTimer(durationMinutes: 25, at: base)
        harness.store.tick(at: base.addingTimeInterval(TimeInterval(timer.durationSeconds)))
        let prompt = harness.store.pendingMeaningfulPrompts[0]

        harness.store.answerMeaningfulPrompt(id: prompt.id, wasMeaningful: true, at: base.addingTimeInterval(1_600))
        let stats = harness.store.meaningfulStats(at: testDate(year: 2026, month: 5, day: 23, hour: 12), calendar: testCalendar)

        #expect(harness.store.pendingMeaningfulPrompts.isEmpty)
        #expect(harness.store.meaningfulTimeRecords.count == 1)
        #expect(harness.store.meaningfulTimeRecords.first?.wasMeaningful == true)
        #expect(stats.todaySeconds == 1_500)
        #expect(stats.weekSeconds == 1_500)
        #expect(stats.monthSeconds == 1_500)
    }

    @Test func answeringNoRecordsButDoesNotAddToStats() {
        let base = testDate(year: 2026, month: 5, day: 23, hour: 11)
        let harness = StoreHarness(now: base)

        let timer = harness.store.startTimer(durationMinutes: 5, at: base)
        harness.store.tick(at: base.addingTimeInterval(TimeInterval(timer.durationSeconds)))
        let prompt = harness.store.pendingMeaningfulPrompts[0]

        harness.store.answerMeaningfulPrompt(id: prompt.id, wasMeaningful: false, at: base.addingTimeInterval(400))
        let stats = harness.store.meaningfulStats(at: testDate(year: 2026, month: 5, day: 23, hour: 12), calendar: testCalendar)

        #expect(harness.store.meaningfulTimeRecords.count == 1)
        #expect(harness.store.meaningfulTimeRecords.first?.wasMeaningful == false)
        #expect(stats == .empty)
    }

    @Test func multipleCompletedTimersQueuePromptsByCompletedAt() {
        let base = Date(timeIntervalSinceReferenceDate: 2_700)
        let harness = StoreHarness(now: base)

        let twoMinuteTimer = harness.store.startTimer(durationMinutes: 2, at: base)
        let oneMinuteTimer = harness.store.startTimer(durationMinutes: 1, at: base)
        harness.store.tick(at: base.addingTimeInterval(120))

        #expect(harness.store.pendingMeaningfulPrompts.map(\.sourceTimerID) == [oneMinuteTimer.id, twoMinuteTimer.id])
        #expect(harness.store.nextMeaningfulPrompt?.sourceTimerID == oneMinuteTimer.id)
    }

    @Test func restoreMarksExpiredRunningTimersCompleteWithoutPlayingSound() {
        let base = Date(timeIntervalSinceReferenceDate: 3_000)
        let expired = TimerRecord(durationMinutes: 1, now: base)
        let persistence = MemoryTimerPersistence(snapshot: TimerStoreSnapshot(timers: [expired], recentDurations: [1]))
        let scheduler = SpyNotificationScheduler()
        let sound = SpySoundPlayer()

        let store = TimerStore(
            persistence: persistence,
            notificationScheduler: scheduler,
            soundPlayer: sound,
            now: base.addingTimeInterval(120)
        )

        #expect(store.timers.first?.state == .completed)
        #expect(sound.playCount == 0)
        #expect(scheduler.cancelledIDs == [expired.id])
        #expect(store.pendingMeaningfulPrompts.count == 1)
        #expect(store.pendingMeaningfulPrompts.first?.sourceTimerID == expired.id)
    }

    @Test func decodesVersionOneSnapshotsWithEmptyMeaningfulState() throws {
        let data = """
        {"version":1,"timers":[],"recentDurations":[25,5]}
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(TimerStoreSnapshot.self, from: data)

        #expect(snapshot.version == 1)
        #expect(snapshot.timers.isEmpty)
        #expect(snapshot.recentDurations == [25, 5])
        #expect(snapshot.pendingMeaningfulPrompts.isEmpty)
        #expect(snapshot.meaningfulTimeRecords.isEmpty)
    }

    @Test func restartingCompletedTimerCreatesNewPromptWithoutOverwritingAnswer() {
        let base = Date(timeIntervalSinceReferenceDate: 3_500)
        let harness = StoreHarness(now: base)

        let timer = harness.store.startTimer(durationMinutes: 1, at: base)
        harness.store.tick(at: base.addingTimeInterval(60))
        let firstPrompt = harness.store.pendingMeaningfulPrompts[0]
        harness.store.answerMeaningfulPrompt(id: firstPrompt.id, wasMeaningful: true, at: base.addingTimeInterval(61))

        harness.store.restartTimer(id: timer.id, at: base.addingTimeInterval(120))
        harness.store.tick(at: base.addingTimeInterval(180))

        #expect(harness.store.meaningfulTimeRecords.count == 1)
        #expect(harness.store.pendingMeaningfulPrompts.count == 1)
        #expect(harness.store.pendingMeaningfulPrompts.first?.id != firstPrompt.id)
        #expect(harness.store.pendingMeaningfulPrompts.first?.sourceTimerID == timer.id)
    }
}

private let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

private func testDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    DateComponents(
        calendar: testCalendar,
        timeZone: testCalendar.timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    ).date!
}

@MainActor
private struct StoreHarness {
    let persistence: MemoryTimerPersistence
    let scheduler: SpyNotificationScheduler
    let soundPlayer: SpySoundPlayer
    let store: TimerStore

    init(now: Date = Date(timeIntervalSinceReferenceDate: 10_000)) {
        persistence = MemoryTimerPersistence()
        scheduler = SpyNotificationScheduler()
        soundPlayer = SpySoundPlayer()
        store = TimerStore(
            persistence: persistence,
            notificationScheduler: scheduler,
            soundPlayer: soundPlayer,
            now: now
        )
    }
}

private final class MemoryTimerPersistence: TimerPersistence {
    var snapshot: TimerStoreSnapshot?

    init(snapshot: TimerStoreSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func loadSnapshot() -> TimerStoreSnapshot? {
        snapshot
    }

    func saveSnapshot(_ snapshot: TimerStoreSnapshot) {
        self.snapshot = snapshot
    }

    func reset() {
        snapshot = nil
    }
}

@MainActor
private final class SpyNotificationScheduler: TimerNotificationScheduling {
    var canDeliverAudibleNotifications = true
    var scheduledIDs: [UUID] = []
    var deliveredIDs: [UUID] = []
    var cancelledIDs: [UUID] = []

    func requestAuthorizationIfNeeded() {}
    func refreshAuthorizationStatus() {}

    func scheduleCompletion(for timer: TimerRecord) {
        scheduledIDs.append(timer.id)
    }

    func deliverCompletion(for timer: TimerRecord) {
        deliveredIDs.append(timer.id)
    }

    func cancelNotification(for id: UUID) {
        cancelledIDs.append(id)
    }
}

@MainActor
private final class SpySoundPlayer: TimerSoundPlaying {
    var playCount = 0

    func playCompletionSound() {
        playCount += 1
    }
}
