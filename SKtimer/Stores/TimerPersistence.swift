import Foundation

struct TimerStoreSnapshot: Codable, Equatable {
    static let currentVersion = 2

    var version: Int
    var timers: [TimerRecord]
    var recentDurations: [Int]
    var pendingMeaningfulPrompts: [PendingMeaningfulPrompt]
    var meaningfulTimeRecords: [MeaningfulTimeRecord]

    init(
        version: Int = Self.currentVersion,
        timers: [TimerRecord],
        recentDurations: [Int],
        pendingMeaningfulPrompts: [PendingMeaningfulPrompt] = [],
        meaningfulTimeRecords: [MeaningfulTimeRecord] = []
    ) {
        self.version = version
        self.timers = timers
        self.recentDurations = recentDurations
        self.pendingMeaningfulPrompts = pendingMeaningfulPrompts
        self.meaningfulTimeRecords = meaningfulTimeRecords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        timers = try container.decodeIfPresent([TimerRecord].self, forKey: .timers) ?? []
        recentDurations = try container.decodeIfPresent([Int].self, forKey: .recentDurations) ?? []
        pendingMeaningfulPrompts = try container.decodeIfPresent([PendingMeaningfulPrompt].self, forKey: .pendingMeaningfulPrompts) ?? []
        meaningfulTimeRecords = try container.decodeIfPresent([MeaningfulTimeRecord].self, forKey: .meaningfulTimeRecords) ?? []
    }
}

protocol TimerPersistence {
    func loadSnapshot() -> TimerStoreSnapshot?
    func saveSnapshot(_ snapshot: TimerStoreSnapshot)
    func reset()
}

final class UserDefaultsTimerPersistence: TimerPersistence {
    static let storageKey = "SKtimer.TimerStoreSnapshot.v1"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSnapshot() -> TimerStoreSnapshot? {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return nil
        }

        return try? decoder.decode(TimerStoreSnapshot.self, from: data)
    }

    func saveSnapshot(_ snapshot: TimerStoreSnapshot) {
        guard let data = try? encoder.encode(snapshot) else {
            return
        }

        defaults.set(data, forKey: Self.storageKey)
    }

    func reset() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
