import Foundation
import Testing
@testable import NoType

@Suite("DictionaryStore")
struct DictionaryStoreTests {

    @Test func addsAndLoadsEntry() {
        let store = DictionaryStore()
        store.load()
        store.deleteAllForTests()
        let entry = PersonalDictionaryEntry(term: "SwiftUI", hint: "Use SwiftUI spelling")
        #expect(store.add(entry) == true)
        #expect(store.allEntries().count == 1)
        #expect(store.allEntries().first?.term == "SwiftUI")
    }

    @Test func rejectsDuplicateTerm() {
        let store = DictionaryStore()
        store.load()
        store.deleteAllForTests()
        store.add(PersonalDictionaryEntry(term: "SwiftUI"))
        #expect(store.add(PersonalDictionaryEntry(term: "SwiftUI")) == false)
    }

    @Test func updatesEntry() {
        let store = DictionaryStore()
        store.load()
        store.deleteAllForTests()
        let entry = PersonalDictionaryEntry(term: "SwiftUI")
        store.add(entry)
        #expect(store.update(id: entry.id, term: "UIKit", hint: nil) == true)
        #expect(store.allEntries().first?.term == "UIKit")
    }

    @Test func rejectsUpdateToDuplicateTerm() {
        let store = DictionaryStore()
        store.load()
        store.deleteAllForTests()
        let a = PersonalDictionaryEntry(term: "SwiftUI")
        let b = PersonalDictionaryEntry(term: "UIKit")
        store.add(a)
        store.add(b)
        #expect(store.update(id: a.id, term: "UIKit", hint: nil) == false)
    }

    @Test func formatsPromptHint() {
        let store = DictionaryStore()
        store.load()
        store.deleteAllForTests()
        store.add(PersonalDictionaryEntry(term: "SwiftUI", hint: "Apple framework"))
        store.add(PersonalDictionaryEntry(term: "NoType"))
        let hint = store.promptHint()
        #expect(hint.contains("SwiftUI"))
        #expect(hint.contains("Apple framework"))
        #expect(hint.contains("NoType"))
    }

    @Test func emptyDictionaryProducesEmptyHint() {
        let store = DictionaryStore()
        store.load()
        store.deleteAllForTests()
        #expect(store.promptHint().isEmpty)
    }
}

extension DictionaryStore {
    fileprivate func deleteAllForTests() {
        allEntries().forEach { _ = delete(id: $0.id) }
    }
}
