import AppKit

/// Reusable form for editing a global shortcut.
@MainActor
final class ShortcutEditorView {
    let keyField = NSTextField(string: "")
    let modifiersField = NSTextField(string: "")
    let view: NSView

    var shortcut: Configuration.Shortcut? {
        let key = keyField.stringValue.trimmingCharacters(in: .whitespaces)
        let raw = modifiersField.stringValue
        let modifiers = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard !key.isEmpty, !modifiers.isEmpty else { return nil }
        for mod in modifiers {
            guard Configuration.allowedModifiers.contains(mod) else { return nil }
        }
        return Configuration.Shortcut(key: key, modifiers: modifiers)
    }

    init(configuration: Configuration.Shortcut) {
        keyField.stringValue = configuration.key
        modifiersField.stringValue = configuration.modifiers.joined(separator: ", ")
        let stack = NSStackView(views: [
            NSTextField(labelWithString: "Key:"),
            keyField,
            NSTextField(labelWithString: "Modifiers (comma-separated, e.g. command, shift):"),
            modifiersField
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        view = stack
    }
}
