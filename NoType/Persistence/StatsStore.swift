import Foundation

/// Persists and updates daily/cumulative word counts.
final class StatsStore {

    private let store = JSONFileStore<WordCountStats>(filename: "stats.json")
    private var stats: WordCountStats = WordCountStats()

    /// Loads stats from disk.
    @discardableResult
    func load() -> WordCountStats {
        do {
            stats = (try store.load()) ?? WordCountStats()
        } catch {
            print("[StatsStore] failed to load: \(error.localizedDescription)")
            stats = WordCountStats()
        }
        reconcileDailyCount()
        return stats
    }

    /// Current stats, reconciled to today's date.
    func currentStats() -> WordCountStats {
        reconcileDailyCount()
        return stats
    }

    /// Records a newly injected phrase's word count.
    func record(words: Int) {
        reconcileDailyCount()
        stats.dailyCount += words
        stats.cumulativeCount += words
        save()
    }

    /// Removes a previously recorded phrase's word count.
    func remove(words: Int) {
        stats.dailyCount = max(0, stats.dailyCount - words)
        stats.cumulativeCount = max(0, stats.cumulativeCount - words)
        save()
    }

    /// Resets today's count. Does not affect cumulative total.
    func resetDaily() {
        stats.dailyCount = 0
        stats.currentDay = WordCountStats.today()
        save()
    }

    /// Replaces the in-memory stats (used when history is recomputed).
    func replace(_ newStats: WordCountStats) {
        stats = newStats
        save()
    }

    private func reconcileDailyCount() {
        let today = WordCountStats.today()
        if stats.currentDay != today {
            stats.currentDay = today
            stats.dailyCount = 0
            save()
        }
    }

    private func save() {
        do {
            try store.save(stats)
        } catch {
            print("[StatsStore] failed to save: \(error.localizedDescription)")
        }
    }
}
