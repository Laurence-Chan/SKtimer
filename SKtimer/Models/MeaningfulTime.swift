import Foundation

struct PendingMeaningfulPrompt: Identifiable, Codable, Equatable {
    var id: UUID
    var sourceTimerID: UUID
    var durationSeconds: Int
    var completedAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sourceTimerID: UUID,
        durationSeconds: Int,
        completedAt: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceTimerID = sourceTimerID
        self.durationSeconds = durationSeconds
        self.completedAt = completedAt
        self.createdAt = createdAt
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

    init(
        promptID: UUID,
        sourceTimerID: UUID,
        durationSeconds: Int,
        completedAt: Date,
        answeredAt: Date = Date(),
        wasMeaningful: Bool
    ) {
        self.promptID = promptID
        self.sourceTimerID = sourceTimerID
        self.durationSeconds = durationSeconds
        self.completedAt = completedAt
        self.answeredAt = answeredAt
        self.wasMeaningful = wasMeaningful
    }
}

struct MeaningfulTimeStats: Equatable {
    var todaySeconds: Int
    var weekSeconds: Int
    var monthSeconds: Int

    static let empty = MeaningfulTimeStats(todaySeconds: 0, weekSeconds: 0, monthSeconds: 0)
}
