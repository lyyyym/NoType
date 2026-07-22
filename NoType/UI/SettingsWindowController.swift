import AppKit

/// Window controller for editing NoType settings, including polishing modes.
@MainActor
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    var onSave: ((Configuration) -> Void)?
    /// Fired when modes are added, edited, or deleted so the caller can rebuild shortcuts.
    var onModesChanged: (() -> Void)?

    private var configuration: Configuration
    private let modeStore: ModeStore
    private let asrFields: ServiceConfigFields
    private let llmFields: LLMConfigFields
    private let bubbleCheckbox = NSButton(checkboxWithTitle: "Show floating bubble while recording", target: nil, action: nil)
    private let bubblePositionPopup = NSPopUpButton()
    private let previewCheckbox = NSButton(checkboxWithTitle: "Show editable preview before injecting", target: nil, action: nil)

    private let modesTable = NSTableView()
    private var modesSnapshot: [PolishingMode] = []

    // Editor sheet state.
    private var editorWindow: NSWindow?
    private var pendingEditor: ModeEditorView?

    init(configuration: Configuration, modeStore: ModeStore) {
        self.configuration = configuration
        self.modeStore = modeStore
        self.asrFields = ServiceConfigFields(title: "ASR", config: configuration.asr)
        self.llmFields = LLMConfigFields(configuration: configuration.llm)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NoType Settings"
        window.titlebarAppearsTransparent = false
        window.center()
        super.init(window: window)

        refreshModesSnapshot()
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        // Section cards.
        let cards = [
            SettingsUI.card(title: "Polishing Modes", content: modesSection()),
            SettingsUI.card(title: "ASR Service", content: asrFields.view),
            SettingsUI.card(title: "LLM Service", content: llmFields.view),
            SettingsUI.card(title: "Recording & Preview", content: appearanceSection())
        ]

        let mainStack = NSStackView(views: cards)
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 18
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(mainStack)
        scrollView.documentView = documentView

        // Initialize control values.
        bubbleCheckbox.state = configuration.showFloatingBubble ? .on : .off
        previewCheckbox.state = configuration.showPreviewBeforeInjection ? .on : .off
        bubblePositionPopup.addItems(withTitles: ["Near cursor", "Under menu bar"])
        bubblePositionPopup.selectItem(at: configuration.bubblePosition == .cursor ? 0 : 1)

        // Bottom button.
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(close))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.controlSize = .large
        cancelButton.bezelStyle = .rounded

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.controlSize = .large
        saveButton.bezelStyle = .rounded

        let buttonBar = NSStackView(views: [cancelButton, saveButton])
        buttonBar.orientation = .horizontal
        buttonBar.spacing = 10
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separator)
        contentView.addSubview(buttonBar)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: separator.topAnchor),

            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: buttonBar.topAnchor, constant: -8),

            buttonBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            buttonBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            // Document view: no horizontal scrolling; vertical content drives height.
            mainStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 4),
            mainStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -4),
            mainStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -20),
            mainStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor, constant: -8)
        ])

        // Stretch every card to the stack width.
        for card in cards {
            card.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        }
    }

    // MARK: - Polishing modes section

    private func modesSection() -> NSView {
        modesTable.dataSource = self
        modesTable.delegate = self
        modesTable.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        modesTable.usesAlternatingRowBackgroundColors = true
        modesTable.rowHeight = 22
        modesTable.backgroundColor = .clear
        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Name"
        let shortcutCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("shortcut"))
        shortcutCol.title = "Shortcut"
        let typeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeCol.title = "Type"
        modesTable.addTableColumn(nameCol)
        modesTable.addTableColumn(shortcutCol)
        modesTable.addTableColumn(typeCol)

        let tableScroll = NSScrollView()
        tableScroll.documentView = modesTable
        tableScroll.hasVerticalScroller = true
        tableScroll.autohidesScrollers = true
        tableScroll.borderType = .noBorder
        tableScroll.drawsBackground = false
        tableScroll.translatesAutoresizingMaskIntoConstraints = false
        tableScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true

        let addButton = NSButton(title: "Add", target: self, action: #selector(addMode))
        addButton.controlSize = .small
        let editButton = NSButton(title: "Edit", target: self, action: #selector(editMode))
        editButton.controlSize = .small
        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteMode))
        deleteButton.controlSize = .small
        let buttonRow = NSStackView(views: [addButton, editButton, deleteButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let stack = NSStackView(views: [tableScroll, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        tableScroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func appearanceSection() -> NSView {
        let positionRow = SettingsUI.row(label: "Bubble position", field: bubblePositionPopup, labelWidth: 140)
        let stack = NSStackView(views: [bubbleCheckbox, positionRow, previewCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        for arranged in stack.arrangedSubviews {
            arranged.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func refreshModesSnapshot() {
        modesSnapshot = modeStore.allModes()
        modesTable.reloadData()
    }

    private func shortcutLabel(_ shortcut: Configuration.Shortcut) -> String {
        let mods = shortcut.modifiers.map { $0.capitalized }.joined(separator: "+")
        return "\(mods)+\(shortcut.key)"
    }

    // MARK: NSTableView data source / delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        modesSnapshot.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier.rawValue ?? ""
        let mode = modesSnapshot[row]
        let text: String
        switch identifier {
        case "name": text = mode.name
        case "shortcut": text = shortcutLabel(mode.shortcut)
        case "type": text = mode.isBuiltin ? "Built-in" : "Custom"
        default: text = ""
        }
        let cell = (tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("cell"), owner: nil) as? NSTextField)
            ?? {
                let field = NSTextField(labelWithString: "")
                field.identifier = NSUserInterfaceItemIdentifier("cell")
                field.font = .systemFont(ofSize: 12)
                return field
            }()
        cell.stringValue = text
        return cell
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        true
    }

    private func selectedMode() -> PolishingMode? {
        let row = modesTable.selectedRow
        guard row >= 0, row < modesSnapshot.count else { return nil }
        return modesSnapshot[row]
    }

    // MARK: - Mode actions

    @objc private func addMode() {
        guard let editor = presentModeEditor(existing: nil) else { return }
        let mode = PolishingMode(name: editor.name,
                                 shortcut: editor.shortcut ?? .default,
                                 instruction: editor.instruction,
                                 outputLanguage: editor.outputLanguage)
        do {
            try modeStore.add(mode)
            refreshModesSnapshot()
            onModesChanged?()
        } catch ModeStore.ModeError.duplicateShortcut {
            showError("That shortcut is already used by another mode.")
        } catch ModeStore.ModeError.emptyName {
            showError("Please enter a mode name.")
        } catch {
            showError("Could not add mode: \(error.localizedDescription)")
        }
    }

    @objc private func editMode() {
        guard let existing = selectedMode() else {
            showError("Select a mode to edit.")
            return
        }
        guard let editor = presentModeEditor(existing: existing) else { return }
        guard let shortcut = editor.shortcut else {
            showError("Please enter a valid shortcut key and at least one modifier.")
            return
        }
        do {
            try modeStore.update(id: existing.id,
                                 name: editor.name,
                                 shortcut: shortcut,
                                 instruction: editor.instruction,
                                 outputLanguage: editor.outputLanguage)
            refreshModesSnapshot()
            onModesChanged?()
        } catch ModeStore.ModeError.duplicateShortcut {
            showError("That shortcut is already used by another mode.")
        } catch ModeStore.ModeError.emptyName {
            showError("Please enter a mode name.")
        } catch {
            showError("Could not save mode: \(error.localizedDescription)")
        }
    }

    @objc private func deleteMode() {
        guard let existing = selectedMode() else {
            showError("Select a mode to delete.")
            return
        }
        do {
            try modeStore.delete(id: existing.id)
            refreshModesSnapshot()
            onModesChanged?()
        } catch ModeStore.ModeError.lastMode {
            showError("You must keep at least one mode.")
        } catch {
            showError("Could not delete mode: \(error.localizedDescription)")
        }
    }

    // MARK: - Editor sheet

    private func presentModeEditor(existing: PolishingMode?) -> ModeEditorView? {
        let editor = ModeEditorView()
        if let existing = existing {
            editor.populate(existing)
        }
        pendingEditor = editor

        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
                             styleMask: [.titled, .closable],
                             backing: .buffered,
                             defer: false)
        panel.title = existing == nil ? "Add Mode" : "Edit Mode"
        panel.isReleasedWhenClosed = false
        panel.center()
        editorWindow = panel

        guard let contentView = panel.contentView else { return nil }
        editor.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(editor.view)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(editorConfirm))
        saveButton.keyEquivalent = "\r"
        saveButton.controlSize = .large
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(editorCancel))
        cancelButton.keyEquivalent = "\u{1B}"
        cancelButton.controlSize = .large
        let buttonRow = NSStackView(views: [cancelButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            editor.view.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            editor.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            editor.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            editor.view.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -14),
            buttonRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            buttonRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])

        NSApp.runModal(for: panel)
        panel.orderOut(nil)
        let result = pendingEditor
        pendingEditor = nil
        editorWindow = nil
        return result
    }

    @objc private func editorConfirm() {
        NSApp.stopModal(withCode: .OK)
    }

    @objc private func editorCancel() {
        pendingEditor = nil
        NSApp.stopModal(withCode: .cancel)
    }

    // MARK: - Save (service config + UI toggles)

    @objc private func save() {
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
            shortcut: configuration.shortcut,
            asr: asr,
            llm: llm,
            showFloatingBubble: bubbleCheckbox.state == .on,
            bubblePosition: position,
            showPreviewBeforeInjection: previewCheckbox.state == .on
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
