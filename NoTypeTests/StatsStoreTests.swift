import Foundation
import Testing
@testable import NoType

@Suite("StatsStore")
struct StatsStoreTests {

    @Test func recordsWords() {
        let store = StatsStore()
        store.replace(WordCountStats(currentDay: WordCountStats.today(), dailyCount: 0, cumulativeCount: 0))
        store.record(words: 10)
        let stats = store.currentStats()
        #expect(stats.dailyCount == 10)
        #expect(stats.cumulativeCount == 10)
    }

    @Test func removesWords() {
        let store = StatsStore()
        store.replace(WordCountStats(currentDay: WordCountStats.today(), dailyCount: 10, cumulativeCount: 10))
        store.remove(words: 3)
        let stats = store.currentStats()
        #expect(stats.dailyCount == 7)
        #expect(stats.cumulativeCount == 7)
    }

    @Test func clampsAtZero() {
        let store = StatsStore()
        store.replace(WordCountStats(currentDay: WordCountStats.today(), dailyCount: 2, cumulativeCount: 2))
        store.remove(words: 5)
        let stats = store.currentStats()
        #expect(stats.dailyCount == 0)
        #expect(stats.cumulativeCount == 0)
    }

    @Test func resetsDailyForNewDay() {
        let yesterday = "2026-07-20"
        let store = StatsStore()
        store.replace(WordCountStats(currentDay: yesterday, dailyCount: 50, cumulativeCount: 100))
        let stats = store.currentStats()
        #expect(stats.currentDay != yesterday)
        #expect(stats.dailyCount == 0)
        #expect(stats.cumulativeCount == 100)
    }
}
