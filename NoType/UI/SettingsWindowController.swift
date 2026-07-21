import AppKit

/// Window controller for editing NoType settings.
@MainActor
final class SettingsWindowController: NSWindowController {

    var onSave: ((Configuration) -> Void)?

    private var configuration: Configuration
    private let shortcutEditor: ShortcutEditorView
    private let asrFields: ServiceConfigFields
    private let llmFields: LLMConfigFields
    private let bubbleCheckbox = NSButton(checkboxWithTitle: "Show floating bubble while recording", target: nil, action: nil)
    private let bubblePositionPopup = NSPopUpButton()

    init(configuration: Configuration) {
        self.configuration = configuration
        self.shortcutEditor = ShortcutEditorView(configuration: configuration.shortcut)
        self.asrFields = ServiceConfigFields(title: "ASR", config: configuration.asr)
        self.llmFields = LLMConfigFields(configuration: configuration.llm)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NoType Settings"
        super.init(window: window)

        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        let stack = NSStackView(views: [
            group(title: "Shortcut", views: [shortcutEditor.view]),
            group(title: "ASR Service", views: [asrFields.view]),
            group(title: "LLM Service", views: [llmFields.view]),
            group(title: "Floating Bubble", views: [bubbleCheckbox, bubblePositionPopup])
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)
        scrollView.documentView = documentView

        bubbleCheckbox.state = configuration.showFloatingBubble ? .on : .off
        bubblePositionPopup.addItems(withTitles: ["Cursor", "Menu Bar"])
        bubblePositionPopup.selectItem(at: configuration.bubblePosition == .cursor ? 0 : 1)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(close))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -8),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -16),

            cancelButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])
    }

    private func group(title: String, views: [NSView]) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 13)

        var arranged: [NSView] = [label]
        arranged.append(contentsOf: views)
        let stack = NSStackView(views: arranged)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        return stack
    }

    // MARK: - Actions

    @objc private func save() {
        guard let shortcut = shortcutEditor.shortcut else {
            showError("Please enter a shortcut key and at least one modifier.")
            return
        }
        guard let asr = asrFields.serviceConfig else {
            showError("Please complete all ASR fields.")
            return
        }
        guard let llm = llmFields.llmConfig else {
            showError("Please complete all LLM fields.")
            return
        }

        let position: Configuration.BubblePosition = bubblePositionPopup.indexOfSelectedItem == 0 ? .cursor : .menuBar
        let updated = Configuration(
            shortcut: shortcut,
            asr: asr,
            llm: llm,
            showFloatingBubble: bubbleCheckbox.state == .on,
            bubblePosition: position
        )

        do {
            try ConfigStore.save(updated)
            configuration = updated
            onSave?(updated)
            close()
        } catch {
            showError("Could not save settings: \(error.localizedDescription)")
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "NoType"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
