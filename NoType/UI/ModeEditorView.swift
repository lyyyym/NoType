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

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 380, height: 110))
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.font = .systemFont(ofSize: 12)
        textView.isRichText = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        self.instructionTextView = textView

        let instructionScroll = NSScrollView()
        instructionScroll.hasVerticalScroller = true
        instructionScroll.autohidesScrollers = true
        instructionScroll.documentView = textView
        instructionScroll.borderType = .bezelBorder
        instructionScroll.translatesAutoresizingMaskIntoConstraints = false
        instructionScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 110).isActive = true

        let hint = NSTextField(labelWithString: "Empty instruction = plain dictation (raw transcript, no LLM).")
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .tertiaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [
            SettingsUI.row(label: "Name", field: nameField),
            SettingsUI.row(label: "Key", field: shortcutEditor.keyField),
            SettingsUI.row(label: "Modifiers", field: shortcutEditor.modifiersField),
            SettingsUI.row(label: "Output language", field: languageField),
            SettingsUI.row(label: "Instruction", field: instructionScroll),
            hint
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        for arranged in stack.arrangedSubviews {
            arranged.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
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
