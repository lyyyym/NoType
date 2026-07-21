import Foundation
import AppKit
import Testing
@testable import NoType

@MainActor
@Suite("ModeEditor")
struct ModeEditorValidationTests {

    @Test func populateAndReadRoundTrips() {
        let editor = ModeEditorView()
        let mode = PolishingMode(name: "Notes",
                                 shortcut: .init(key: "n", modifiers: ["command", "shift"]),
                                 instruction: "Be brief.",
                                 outputLanguage: "English")
        editor.populate(mode)
        #expect(editor.name == "Notes")
        #expect(editor.shortcut == .init(key: "n", modifiers: ["command", "shift"]))
        #expect(editor.instruction == "Be brief.")
        #expect(editor.outputLanguage == "English")
    }

    @Test func emptyLanguageReturnsNil() {
        let editor = ModeEditorView()
        editor.populate(PolishingMode(name: "X", shortcut: .default, instruction: "x"))
        #expect(editor.outputLanguage == nil)
    }

    @Test func whitespaceLanguageReturnsNil() {
        let editor = ModeEditorView()
        editor.populate(PolishingMode(name: "X", shortcut: .default, instruction: "x", outputLanguage: "   "))
        #expect(editor.outputLanguage == nil)
    }

    @Test func nameIsTrimmed() {
        let editor = ModeEditorView()
        editor.nameField.stringValue = "  spaced  "
        #expect(editor.name == "spaced")
    }

    @Test func invalidShortcutReturnsNil() {
        let editor = ModeEditorView()
        editor.shortcutEditor.keyField.stringValue = ""
        editor.shortcutEditor.modifiersField.stringValue = "command"
        #expect(editor.shortcut == nil)
    }

    @Test func shortcutParsedFromCommaSeparatedModifiers() {
        let editor = ModeEditorView()
        editor.shortcutEditor.keyField.stringValue = "."
        editor.shortcutEditor.modifiersField.stringValue = "command, shift"
        #expect(editor.shortcut == .init(key: ".", modifiers: ["command", "shift"]))
    }
}
