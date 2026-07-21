import Foundation
import Testing
@testable import NoType

@Suite("HistoryStore")
struct HistoryStoreTests {

    @Test func appendsEntryToFront() {
        let store = HistoryStore()
        store.reset()
        store.append(RecordingEntry(rawText: "hello", polishedText: "Hello"))
        store.append(RecordingEntry(rawText: "world", polishedText: "World"))
        let entries = store.allEntries()
        #expect(entries.count == 2)
        #expect(entries.first?.polishedText == "World")
    }

    @Test func evictsOldestAfter50() {
        let store = HistoryStore()
        store.reset()
        for i in 0..<52 {
            store.append(RecordingEntry(rawText: "\(i)", polishedText: "\(i)"))
        }
        let entries = store.allEntries()
        #expect(entries.count == 50)
        #expect(entries.first?.polishedText == "51")
        #expect(entries.last?.polishedText == "2")
    }

    @Test func deleteRemovesEntry() {
        let store = HistoryStore()
        store.reset()
        let entry = RecordingEntry(rawText: "x", polishedText: "X")
        store.append(entry)
        let removed = store.delete(id: entry.id)
        #expect(removed != nil)
        #expect(store.allEntries().isEmpty)
    }
}
