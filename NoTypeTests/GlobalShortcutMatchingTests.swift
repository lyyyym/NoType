import Foundation
import AppKit
import Testing
@testable import NoType

@Suite("GlobalShortcutMatching")
struct GlobalShortcutMatchingTests {

    private func binding(_ id: String, _ key: String, _ mods: [String]) -> GlobalShortcut.Binding {
        GlobalShortcut.Binding(modeID: UUID(uuidString: id)!,
                               shortcut: .init(key: key, modifiers: mods))
    }

    @Test func matchesSingleCharShortcutByCharacter() {
        let b = binding("00000000-0000-0000-0000-000000000001", "a", ["command"])
        let match = GlobalShortcut.match(bindings: [b],
                                         eventModifiers: .command,
                                         characters: "a",
                                         keyCode: 0)
        #expect(match?.modeID == b.modeID)
    }

    @Test func noMatchWhenModifiersDiffer() {
        let b = binding("00000000-0000-0000-0000-000000000001", "a", ["command", "shift"])
        let match = GlobalShortcut.match(bindings: [b],
                                         eventModifiers: .command,
                                         characters: "a",
                                         keyCode: 0)
        #expect(match == nil)
    }

    @Test func noMatchWhenKeyDiffers() {
        let b = binding("00000000-0000-0000-0000-000000000001", "a", ["command"])
        let match = GlobalShortcut.match(bindings: [b],
                                         eventModifiers: .command,
                                         characters: "b",
                                         keyCode: 0)
        #expect(match == nil)
    }

    @Test func periodMatchesByKeyCode() {
        let b = binding("00000000-0000-0000-0000-000000000001", ".", ["command"])
        // kVK_ANSI_Period = 0x2F (47)
        let match = GlobalShortcut.match(bindings: [b],
                                         eventModifiers: .command,
                                         characters: nil,
                                         keyCode: 47)
        #expect(match?.modeID == b.modeID)
    }

    @Test func periodMatchesByCharacter() {
        let b = binding("00000000-0000-0000-0000-000000000001", ".", ["command"])
        let match = GlobalShortcut.match(bindings: [b],
                                         eventModifiers: .command,
                                         characters: ".",
                                         keyCode: 999)
        #expect(match?.modeID == b.modeID)
    }

    @Test func namedKeyMatchesByKeyCode() {
        let b = binding("00000000-0000-0000-0000-000000000001", "f5", ["command"])
        // kVK_F5 = 0x60 (96)
        let match = GlobalShortcut.match(bindings: [b],
                                         eventModifiers: .command,
                                         characters: nil,
                                         keyCode: 96)
        #expect(match?.modeID == b.modeID)
    }

    @Test func selectsCorrectModeAmongMany() {
        let everyday = binding("00000000-0000-0000-0000-000000000001", ".", ["command"])
        let translate = binding("00000000-0000-0000-0000-000000000002", ".", ["command", "shift"])
        let formal = binding("00000000-0000-0000-0000-000000000003", ".", ["command", "option"])
        let bindings = [everyday, translate, formal]

        let m1 = GlobalShortcut.match(bindings: bindings, eventModifiers: .command, characters: ".", keyCode: 47)
        let m2 = GlobalShortcut.match(bindings: bindings, eventModifiers: [.command, .shift], characters: ".", keyCode: 47)
        let m3 = GlobalShortcut.match(bindings: bindings, eventModifiers: [.command, .option], characters: ".", keyCode: 47)

        #expect(m1?.modeID == everyday.modeID)
        #expect(m2?.modeID == translate.modeID)
        #expect(m3?.modeID == formal.modeID)
    }

    @Test func returnsNilWhenNothingMatches() {
        let b = binding("00000000-0000-0000-0000-000000000001", ".", ["command"])
        let match = GlobalShortcut.match(bindings: [b],
                                         eventModifiers: [.command, .option],
                                         characters: ".",
                                         keyCode: 47)
        #expect(match == nil)
    }

    @Test func deduplicatesShortcutBindings() {
        let id1 = UUID()
        let id2 = UUID()
        let shortcut = Configuration.Shortcut(key: ".", modifiers: ["command"])
        let monitor = GlobalShortcut(bindings: [
            .init(modeID: id1, shortcut: shortcut),
            .init(modeID: id2, shortcut: shortcut)
        ])
        // Only the first binding for a given shortcut is retained.
        #expect(monitor.currentBindings().count == 1)
        #expect(monitor.currentBindings().first?.modeID == id1)
    }

    @Test func modifiersMatchExactOnly() {
        // Extra modifiers held should NOT match (exact set required).
        #expect(GlobalShortcut.modifiersMatch([.command, .shift], ["command", "shift"]))
        #expect(!GlobalShortcut.modifiersMatch([.command, .shift, .option], ["command", "shift"]))
        #expect(!GlobalShortcut.modifiersMatch([.command], ["command", "shift"]))
    }
}
