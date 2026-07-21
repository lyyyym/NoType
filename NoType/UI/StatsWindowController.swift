import AppKit

/// Window controller for displaying daily and cumulative word counts.
@MainActor
final class StatsWindowController: NSWindowController {

    private let statsStore: StatsStore
    private let dailyLabel = NSTextField(labelWithString: "Today: 0")
    private let cumulativeLabel = NSTextField(labelWithString: "Total: 0")

    init(statsStore: StatsStore) {
        self.statsStore = statsStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 160),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Statistics"
        super.init(window: window)

        setupUI()
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        dailyLabel.font = NSFont.systemFont(ofSize: 24, weight: .semibold)
        cumulativeLabel.font = NSFont.systemFont(ofSize: 18, weight: .regular)

        let stack = NSStackView(views: [dailyLabel, cumulativeLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func refresh() {
        let stats = statsStore.currentStats()
        dailyLabel.stringValue = "Today: \(stats.dailyCount)"
        cumulativeLabel.stringValue = "Total: \(stats.cumulativeCount)"
    }
}
