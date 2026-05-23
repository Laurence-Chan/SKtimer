import Foundation

enum TimerState: String, Codable, Equatable, CaseIterable {
    case running
    case paused
    case completed

    var localizedKey: String {
        switch self {
        case .running:
            "timer.state.running"
        case .paused:
            "timer.state.paused"
        case .completed:
            "timer.state.completed"
        }
    }
}

struct TimerRecord: Identifiable, Codable, Equatable {
    static let minimumMinutes = 1
    static let maximumMinutes = (999 * 60) + 59

    var id: UUID
    var durationSeconds: Int
    var createdAt: Date
    var startedAt: Date
    var endDate: Date
    var pausedRemainingSeconds: Int?
    var completedAt: Date?
    var state: TimerState

    init(id: UUID = UUID(), durationMinutes: Int, now: Date = Date()) {
        let durationSeconds = durationMinutes * 60
        self.id = id
        self.durationSeconds = durationSeconds
        self.createdAt = now
        self.startedAt = now
        self.endDate = now.addingTimeInterval(TimeInterval(durationSeconds))
        self.pausedRemainingSeconds = nil
        self.completedAt = nil
        self.state = .running
    }

    var durationMinutes: Int {
        durationSeconds / 60
    }

    var isRunning: Bool {
        state == .running
    }

    var isFinished: Bool {
        state == .completed
    }

    func remainingSeconds(at date: Date) -> Int {
        switch state {
        case .running:
            max(0, Int(ceil(endDate.timeIntervalSince(date))))
        case .paused:
            max(0, pausedRemainingSeconds ?? 0)
        case .completed:
            0
        }
    }

    func progress(at date: Date) -> Double {
        guard durationSeconds > 0 else {
            return 1
        }

        let elapsed = Double(durationSeconds - remainingSeconds(at: date))
        return min(max(elapsed / Double(durationSeconds), 0), 1)
    }

    mutating func pause(at date: Date) {
        guard state == .running else {
            return
        }

        pausedRemainingSeconds = remainingSeconds(at: date)
        state = .paused
    }

    mutating func resume(at date: Date) {
        guard state == .paused else {
            return
        }

        let remaining = max(0, pausedRemainingSeconds ?? durationSeconds)
        startedAt = date
        endDate = date.addingTimeInterval(TimeInterval(remaining))
        pausedRemainingSeconds = nil
        completedAt = nil
        state = .running
    }

    mutating func restart(at date: Date) {
        startedAt = date
        endDate = date.addingTimeInterval(TimeInterval(durationSeconds))
        pausedRemainingSeconds = nil
        completedAt = nil
        state = .running
    }

    mutating func complete(at date: Date? = nil) {
        pausedRemainingSeconds = 0
        completedAt = date ?? endDate
        state = .completed
    }

    mutating func completeIfDue(at date: Date) -> Bool {
        guard state == .running, endDate <= date else {
            return false
        }

        complete(at: endDate)
        return true
    }
}
