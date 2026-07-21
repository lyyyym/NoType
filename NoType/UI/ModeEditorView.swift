import AppKit

/// Reusable form for creating or editing a polishing mode.
///
/// Exposes the edited fields; validation (non-empty name, unique shortcut) is enforced
/// by `ModeStore` when the caller saves. See spec US3.
@MainActor
final class ModeEditorView {

    let nameField = NSTextField(string: "")
    let shortcutEditor: ShortcutEditorView
    let languageField = NSTextField(string: "")
    let instructionTextView: NSTextView
    let view: NSView

    init() {
        self.shortcutEditor = ShortcutEditorView(configuration: .default)
        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 12)
        textView.isRichText = false
        textView.minSize = NSSize(width: 0, height: 80)
        self.instructionTextView = textView

        let instructionScroll = NSScrollView()
        instructionScroll.hasVerticalScroller = true
        instructionScroll.autohidesScrollers = true
        instructionScroll.documentView = textView
        instructionScroll.borderType = .bezelBorder
        instructionScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true

        let stack = NSStackView(views: [
            NSTextField(labelWithString: "Name:"),
            nameField,
            NSTextField(labelWithString: "Shortcut — key (e.g. . or f5):"),
            shortcutEditor.view,
            NSTextField(labelWithString: "Output language (optional, e.g. English):"),
            languageField,
            NSTextField(labelWithString: "Polishing instruction (empty = plain dictation):"),
            instructionScroll
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        view = stack
    }

    /// Fills the fields from an existing mode (for editing).
    func populate(_ mode: PolishingMode) {
        nameField.stringValue = mode.name
        shortcutEditor.keyField.stringValue = mode.shortcut.key
        shortcutEditor.modifiersField.stringValue = mode.shortcut.modifiers.joined(separator: ", ")
        languageField.stringValue = mode.outputLanguage ?? ""
        instructionTextView.string = mode.instruction
    }

    /// The edited name (trimmed).
    var name: String {
        nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The edited shortcut, or nil if invalid.
    var shortcut: Configuration.Shortcut? {
        shortcutEditor.shortcut
    }

    /// The edited polishing instruction.
    var instruction: String {
        instructionTextView.string
    }

    /// The edited output language, or nil when left blank.
    var outputLanguage: String? {
        let value = languageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
