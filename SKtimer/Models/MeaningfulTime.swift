import Foundation

struct FocusTimeSegment: Codable, Equatable {
    var startAt: Date
    var endAt: Date

    var durationSeconds: Int {
        max(0, Int(endAt.timeIntervalSince(startAt)))
    }

    init(startAt: Date, endAt: Date) {
        self.startAt = startAt
        self.endAt = endAt
    }
}

struct PendingMeaningfulPrompt: Identifiable, Codable, Equatable {
    var id: UUID
    var sourceTimerID: UUID
    var durationSeconds: Int
    var completedAt: Date
    var createdAt: Date
    var focusSegments: [FocusTimeSegment]

    init(
        id: UUID = UUID(),
        sourceTimerID: UUID,
        durationSeconds: Int,
        completedAt: Date,
        createdAt: Date = Date(),
        focusSegments: [FocusTimeSegment] = []
    ) {
        self.id = id
        self.sourceTimerID = sourceTimerID
        self.durationSeconds = durationSeconds
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.focusSegments = focusSegments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceTimerID = try container.decode(UUID.self, forKey: .sourceTimerID)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        focusSegments = try container.decodeIfPresent([FocusTimeSegment].self, forKey: .focusSegments) ?? []
    }
}

struct MeaningfulTimeRecord: Identifiable, Codable, Equatable {
    var id: UUID { promptID }

    var promptID: UUID
    var sourceTimerID: UUID
    var durationSeconds: Int
    var completedAt: Date
    var answeredAt: Date
    var wasMeaningful: Bool
    var focusSegments: [FocusTimeSegment]

    init(
        promptID: UUID,
        sourceTimerID: UUID,
        durationSeconds: Int,
        completedAt: Date,
        answeredAt: Date = Date(),
        wasMeaningful: Bool,
        focusSegments: [FocusTimeSegment] = []
    ) {
        self.promptID = promptID
        self.sourceTimerID = sourceTimerID
        self.durationSeconds = durationSeconds
        self.completedAt = completedAt
        self.answeredAt = answeredAt
        self.wasMeaningful = wasMeaningful
        self.focusSegments = focusSegments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        promptID = try container.decode(UUID.self, forKey: .promptID)
        sourceTimerID = try container.decode(UUID.self, forKey: .sourceTimerID)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        answeredAt = try container.decode(Date.self, forKey: .answeredAt)
        wasMeaningful = try container.decode(Bool.self, forKey: .wasMeaningful)
        focusSegments = try container.decodeIfPresent([FocusTimeSegment].self, forKey: .focusSegments) ?? []
    }
}

struct MeaningfulTimeStats: Equatable {
    var todaySeconds: Int
    var weekSeconds: Int
    var monthSeconds: Int

    static let empty = MeaningfulTimeStats(todaySeconds: 0, weekSeconds: 0, monthSeconds: 0)

    func seconds(for period: MeaningfulStatsPeriod) -> Int {
        switch period {
        case .daily:
            todaySeconds
        case .weekly:
            weekSeconds
        case .monthly:
            monthSeconds
        }
    }
}

enum MeaningfulStatsPeriod: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String {
        rawValue
    }

    var durationSeconds: TimeInterval {
        switch self {
        case .daily:
            24 * 60 * 60
        case .weekly:
            7 * 24 * 60 * 60
        case .monthly:
            30 * 24 * 60 * 60
        }
    }

    var titleKey: String {
        switch self {
        case .daily:
            "meaningful.stats.daily"
        case .weekly:
            "meaningful.stats.weekly"
        case .monthly:
            "meaningful.stats.monthly"
        }
    }

    var chartTitleKey: String {
        switch self {
        case .daily:
            "meaningful.chart.daily.title"
        case .weekly:
            "meaningful.chart.weekly.title"
        case .monthly:
            "meaningful.chart.monthly.title"
        }
    }

    var valueAccessibilityIdentifier: String {
        switch self {
        case .daily:
            "meaningfulStatsTodayValue"
        case .weekly:
            "meaningfulStatsWeekValue"
        case .monthly:
            "meaningfulStatsMonthValue"
        }
    }

    var buttonAccessibilityIdentifier: String {
        switch self {
        case .daily:
            "meaningfulStatsDailyButton"
        case .weekly:
            "meaningfulStatsWeeklyButton"
        case .monthly:
            "meaningfulStatsMonthlyButton"
        }
    }
}

struct MeaningfulChartBar: Identifiable, Equatable {
    var id: String
    var label: String
    var startAt: Date
    var endAt: Date
    var seconds: Int
}
