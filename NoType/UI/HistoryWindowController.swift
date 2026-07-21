import AppKit

/// Window controller for viewing, copying, and deleting recording history.
@MainActor
final class HistoryWindowController: NSWindowController {

    private let historyStore: HistoryStore
    private let onDelete: ((Int) -> Void)?
    private var tableView: NSTableView!

    init(historyStore: HistoryStore, onDelete: ((Int) -> Void)? = nil) {
        self.historyStore = historyStore
        self.onDelete = onDelete

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "History"
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
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        let columns = [
            ("Time", 120),
            ("Polished", 300),
            ("Words", 60),
            ("Raw", 120)
        ]
        for (title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(title))
            column.title = title
            column.width = CGFloat(width)
            column.minWidth = 60
            tableView.addTableColumn(column)
        }

        tableView.delegate = self
        tableView.dataSource = self
        scrollView.documentView = tableView

        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copySelected))
        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteSelected))

        copyButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(copyButton)
        contentView.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: copyButton.topAnchor, constant: -12),

            copyButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            copyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            deleteButton.leadingAnchor.constraint(equalTo: copyButton.trailingAnchor, constant: 12),
            deleteButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    private func reload() {
        historyStore.load()
        tableView.reloadData()
    }

    @objc private func copySelected() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        let entry = historyStore.allEntries()[row]
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.polishedText, forType: .string)
    }

    @objc private func deleteSelected() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        let entry = historyStore.allEntries()[row]
        if let removed = historyStore.delete(id: entry.id) {
            onDelete?(removed.wordCount)
            reload()
        }
    }
}

extension HistoryWindowController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        historyStore.allEntries().count
    }
}

extension HistoryWindowController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = historyStore.allEntries()[row]
        let cell = NSTextField(labelWithString: "")
        cell.lineBreakMode = .byTruncatingTail

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        switch tableColumn?.identifier.rawValue {
        case "Time":
            cell.stringValue = formatter.string(from: entry.timestamp)
        case "Polished":
            cell.stringValue = entry.polishedText
        case "Words":
            cell.stringValue = String(entry.wordCount)
        case "Raw":
            cell.stringValue = entry.rawText
        default:
            break
        }
        return cell
    }
}
