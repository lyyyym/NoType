import Foundation

/// Daily and cumulative word counts derived from recording history.
struct WordCountStats: Codable {
    /// Calendar day for which `dailyCount` is valid (ISO-8601 date string).
    var currentDay: String
    /// Words injected today.
    var dailyCount: Int
    /// Words injected since first use.
    var cumulativeCount: Int

    init(currentDay: String = WordCountStats.today(), dailyCount: Int = 0, cumulativeCount: Int = 0) {
        self.currentDay = currentDay
        self.dailyCount = dailyCount
        self.cumulativeCount = cumulativeCount
    }

    static func today() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: Date())
    }
}
