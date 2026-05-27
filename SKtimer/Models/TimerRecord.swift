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
    var focusSegments: [FocusTimeSegment]
    var activeFocusStartedAt: Date?

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
        self.focusSegments = []
        self.activeFocusStartedAt = now
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endDate = try container.decode(Date.self, forKey: .endDate)
        pausedRemainingSeconds = try container.decodeIfPresent(Int.self, forKey: .pausedRemainingSeconds)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        state = try container.decode(TimerState.self, forKey: .state)
        focusSegments = try container.decodeIfPresent([FocusTimeSegment].self, forKey: .focusSegments) ?? []
        activeFocusStartedAt = try container.decodeIfPresent(Date.self, forKey: .activeFocusStartedAt)

        if state == .running, activeFocusStartedAt == nil {
            activeFocusStartedAt = startedAt
        }
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

        appendActiveFocusSegment(endingAt: date)
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
        activeFocusStartedAt = date
        state = .running
    }

    mutating func restart(at date: Date) {
        startedAt = date
        endDate = date.addingTimeInterval(TimeInterval(durationSeconds))
        pausedRemainingSeconds = nil
        completedAt = nil
        focusSegments = []
        activeFocusStartedAt = date
        state = .running
    }

    mutating func complete(at date: Date? = nil) {
        let completedDate = date ?? endDate
        appendActiveFocusSegment(endingAt: completedDate)
        pausedRemainingSeconds = 0
        completedAt = completedDate
        state = .completed
    }

    mutating func completeIfDue(at date: Date) -> Bool {
        guard state == .running, endDate <= date else {
            return false
        }

        complete(at: endDate)
        return true
    }

    private mutating func appendActiveFocusSegment(endingAt endAt: Date) {
        guard let startAt = activeFocusStartedAt, endAt > startAt else {
            activeFocusStartedAt = nil
            return
        }

        focusSegments.append(FocusTimeSegment(startAt: startAt, endAt: endAt))
        activeFocusStartedAt = nil
    }
}
