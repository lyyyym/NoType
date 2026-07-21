import AppKit

/// Window controller for managing the personal dictionary.
@MainActor
final class DictionaryWindowController: NSWindowController {

    private let dictionaryStore: DictionaryStore
    private var tableView: NSTableView!
    private let termField = NSTextField(string: "")
    private let hintField = NSTextField(string: "")

    init(dictionaryStore: DictionaryStore) {
        self.dictionaryStore = dictionaryStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Personal Dictionary"
        super.init(window: window)

        setupUI()
        reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        tableView = NSTableView()
        tableView.usesAlternatingRowBackgroundColors = true

        let termColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Term"))
        termColumn.title = "Term"
        termColumn.width = 180
        tableView.addTableColumn(termColumn)

        let hintColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Hint"))
        hintColumn.title = "Hint"
        hintColumn.width = 240
        tableView.addTableColumn(hintColumn)

        tableView.delegate = self
        tableView.dataSource = self
        scrollView.documentView = tableView

        termField.placeholderString = "Term"
        hintField.placeholderString = "Hint (optional)"

        let addButton = NSButton(title: "Add", target: self, action: #selector(addEntry))
        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteSelected))
        let editButton = NSButton(title: "Update", target: self, action: #selector(updateSelected))

        let inputStack = NSStackView(views: [termField, hintField, addButton])
        inputStack.orientation = .horizontal
        inputStack.spacing = 8
        inputStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(inputStack)

        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(deleteButton)
        contentView.addSubview(editButton)

        NSLayoutConstraint.activate([
            inputStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            inputStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            inputStack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: inputStack.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: deleteButton.topAnchor, constant: -12),

            deleteButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            deleteButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            editButton.leadingAnchor.constraint(equalTo: deleteButton.trailingAnchor, constant: 12),
            editButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    private func reload() {
        dictionaryStore.load()
        tableView.reloadData()
    }

    @objc private func addEntry() {
        let term = termField.stringValue
        let hint = hintField.stringValue
        guard !term.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let entry = PersonalDictionaryEntry(term: term, hint: hint.isEmpty ? nil : hint)
        if dictionaryStore.add(entry) {
            termField.stringValue = ""
            hintField.stringValue = ""
            reload()
        } else {
            showError("Duplicate or invalid term.")
        }
    }

    @objc private func updateSelected() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        let entry = dictionaryStore.allEntries()[row]
        let term = termField.stringValue
        let hint = hintField.stringValue
        guard !term.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if dictionaryStore.update(id: entry.id, term: term, hint: hint.isEmpty ? nil : hint) {
            termField.stringValue = ""
            hintField.stringValue = ""
            reload()
        } else {
            showError("Duplicate or invalid term.")
        }
    }

    @objc private func deleteSelected() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        let entry = dictionaryStore.allEntries()[row]
        if dictionaryStore.delete(id: entry.id) {
            reload()
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

extension DictionaryWindowController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        dictionaryStore.allEntries().count
    }
}

extension DictionaryWindowController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = dictionaryStore.allEntries()[row]
        let cell = NSTextField(labelWithString: "")
        cell.lineBreakMode = .byTruncatingTail

        switch tableColumn?.identifier.rawValue {
        case "Term":
            cell.stringValue = entry.term
        case "Hint":
            cell.stringValue = entry.hint ?? ""
        default:
            break
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        let entry = dictionaryStore.allEntries()[row]
        termField.stringValue = entry.term
        hintField.stringValue = entry.hint ?? ""
    }
}
