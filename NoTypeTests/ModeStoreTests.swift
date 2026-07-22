import Foundation
import Testing
@testable import NoType

@Suite("ModeStore", .serialized)
struct ModeStoreTests {

    /// Each test uses an isolated file so the user's real `modes.json` is untouched.
    private func makeStore() -> ModeStore {
        let store = ModeStore(filename: "modes-test.json")
        store.resetFile()
        return store
    }

    private func shortcut(_ key: String, _ mods: [String]) -> Configuration.Shortcut {
        .init(key: key, modifiers: mods)
    }

    @Test func seedsDefaultsWhenFileMissing() {
        let store = makeStore()
        let modes = store.load()
        #expect(modes.count == 3)
        #expect(modes.contains { $0.name == "Everyday polish" })
        #expect(modes.contains { $0.name == "Translate to English" })
        #expect(modes.contains { $0.name == "Formal / email" })
    }

    @Test func defaultShortcutsAreDistinct() {
        let store = makeStore()
        let modes = store.load()
        let shortcuts = modes.map { $0.shortcut }
        #expect(Set(shortcuts).count == shortcuts.count)
    }

    @Test func migrationUsesLegacyShortcutForEveryday() {
        let store = makeStore()
        let legacy = shortcut("/", ["command"])
        let modes = store.load(legacyEverydayShortcut: legacy)
        let everyday = modes.first { $0.name == "Everyday polish" }
        #expect(everyday?.shortcut == legacy)
    }

    @Test func everydayInstructionMatchesV2Prompt() {
        let store = makeStore()
        let everyday = store.load().first { $0.name == "Everyday polish" }
        #expect(everyday?.instruction == PolishingMode.everydayInstruction)
        #expect(everyday?.instruction == PolishPrompt.systemPrompt)
    }

    @Test func addInsertsMode() throws {
        let store = makeStore()
        _ = store.load()
        let mode = PolishingMode(name: "Notes", shortcut: shortcut("n", ["command", "shift"]), instruction: "Be concise.")
        try store.add(mode)
        #expect(store.allModes().contains { $0.id == mode.id })
        #expect(store.mode(forShortcut: mode.shortcut)?.name == "Notes")
    }

    @Test func addRejectsDuplicateShortcut() throws {
        let store = makeStore()
        let modes = store.load()
        let taken = modes[0].shortcut
        let dup = PolishingMode(name: "Dup", shortcut: taken, instruction: "x")
        #expect(throws: ModeStore.ModeError.self) {
            try store.add(dup)
        }
    }

    @Test func addRejectsEmptyName() throws {
        let store = makeStore()
        _ = store.load()
        let bad = PolishingMode(name: "   ", shortcut: shortcut("q", ["command", "shift"]), instruction: "x")
        #expect(throws: ModeStore.ModeError.self) {
            try store.add(bad)
        }
    }

    @Test func updateChangesFields() throws {
        let store = makeStore()
        _ = store.load()
        let mode = PolishingMode(name: "Temp", shortcut: shortcut("t", ["command", "shift"]), instruction: "old")
        try store.add(mode)
        try store.update(id: mode.id,
                         name: "Renamed",
                         shortcut: shortcut("u", ["command", "shift"]),
                         instruction: "new",
                         outputLanguage: "English")
        let updated = store.mode(for: mode.id)
        #expect(updated?.name == "Renamed")
        #expect(updated?.instruction == "new")
        #expect(updated?.outputLanguage == "English")
        #expect(updated?.shortcut == .init(key: "u", modifiers: ["command", "shift"]))
    }

    @Test func updateRejectsShortcutCollisionWithOtherMode() throws {
        let store = makeStore()
        let modes = store.load()
        let target = modes[0]
        let other = modes[1]
        #expect(throws: ModeStore.ModeError.self) {
            try store.update(id: target.id, name: target.name, shortcut: other.shortcut, instruction: "x", outputLanguage: nil)
        }
    }

    @Test func deleteRemovesMode() throws {
        let store = makeStore()
        _ = store.load()
        let mode = PolishingMode(name: "Gone", shortcut: shortcut("g", ["command", "shift"]), instruction: "x")
        try store.add(mode)
        try store.delete(id: mode.id)
        #expect(store.mode(for: mode.id) == nil)
    }

    @Test func deleteRefusesLastMode() {
        let store = makeStore()
        let modes = store.load()
        // Delete down to one mode.
        for mode in modes.dropLast() {
            try? store.delete(id: mode.id)
        }
        let last = store.allModes().first!
        #expect(throws: ModeStore.ModeError.self) {
            try store.delete(id: last.id)
        }
    }

    @Test func replaceAllEnforcesUniquenessAndMinimum() throws {
        let store = makeStore()
        let s1 = shortcut("a", ["command"])
        let s2 = shortcut("b", ["command"])
        let modes = [
            PolishingMode(name: "A", shortcut: s1, instruction: "x"),
            PolishingMode(name: "B", shortcut: s2, instruction: "y")
        ]
        try store.replaceAll(modes)
        #expect(store.allModes().count == 2)

        let dupShortcuts = [
            PolishingMode(name: "A", shortcut: s1, instruction: "x"),
            PolishingMode(name: "C", shortcut: s1, instruction: "z")
        ]
        #expect(throws: ModeStore.ModeError.self) {
            try store.replaceAll(dupShortcuts)
        }
        #expect(throws: ModeStore.ModeError.self) {
            try store.replaceAll([])
        }
    }

    @Test func deduplicatesShortcutsOnLoad() throws {
        let store = makeStore()
        store.resetFile()
        // Write a raw file with two modes sharing a shortcut (simulating a hand-edit
        // or stale file). The encoder does not enforce uniqueness, so this produces
        // a genuine duplicate on disk.
        let dupes = [
            PolishingMode(name: "First", shortcut: shortcut("z", ["command"]), instruction: "x"),
            PolishingMode(name: "Second", shortcut: shortcut("z", ["command"]), instruction: "y")
        ]
        let url = try PersistenceDirectory.url().appendingPathComponent("modes-test.json")
        try JSONEncoder().encode(dupes).write(to: url)

        let reloaded = ModeStore(filename: "modes-test.json")
        let modes = reloaded.load(legacyEverydayShortcut: .default)
        let withShortcut = modes.filter { $0.shortcut == shortcut("z", ["command"]) }
        // The colliding second entry is dropped; the first is kept.
        #expect(withShortcut.count == 1)
        #expect(withShortcut.first?.name == "First")
    }
}
