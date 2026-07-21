import AppKit

/// Manages the macOS menu-bar status item and its menu.
///
/// See `contracts` and `spec.md` User Story 3.
final class StatusBarController {

    private let statusItem: NSStatusItem
    private var state: State = .idle

    /// Called when the user selects Settings from the menu.
    var onOpenSettings: (() -> Void)?
    /// Called when the user selects History from the menu.
    var onOpenHistory: (() -> Void)?
    /// Called when the user selects Dictionary from the menu.
    var onOpenDictionary: (() -> Void)?
    /// Called when the user selects Statistics from the menu.
    var onOpenStats: (() -> Void)?

    enum State {
        case idle
        case recording
        case processing
        case success
        case error

        var title: String {
            switch self {
            case .idle: return "⚪"
            case .recording: return "🔴"
            case .processing: return "⏳"
            case .success: return "✅"
            case .error: return "⚠️"
            }
        }

        /// Title with an optional mode label appended (used while recording).
        func title(modeName: String?) -> String {
            guard let modeName = modeName?.trimmingCharacters(in: .whitespacesAndNewlines), !modeName.isEmpty else {
                return title
            }
            return "\(title) \(modeName)"
        }
    }

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = State.idle.title
        }
        rebuildMenu()
    }

    func update(_ state: State, modeName: String? = nil) {
        self.state = state
        let title = state.title(modeName: modeName)
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.button?.title = title
        }
        if state == .success || state == .error {
            // Brief completion signal, then return to idle.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                if self.state == .success || self.state == .error {
                    self.update(.idle)
                }
            }
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "NoType", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let settingsItem = menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self

        let historyItem = menu.addItem(withTitle: "History…", action: #selector(openHistory), keyEquivalent: "")
        historyItem.target = self

        let dictionaryItem = menu.addItem(withTitle: "Dictionary…", action: #selector(openDictionary), keyEquivalent: "")
        dictionaryItem.target = self

        let statsItem = menu.addItem(withTitle: "Statistics…", action: #selector(openStats), keyEquivalent: "")
        statsItem.target = self

        menu.addItem(.separator())

        let configItem = menu.addItem(withTitle: "Open config folder", action: #selector(openConfigFolder), keyEquivalent: "")
        configItem.target = self

        let accessibilityItem = menu.addItem(withTitle: "Request Accessibility…", action: #selector(requestAccessibility), keyEquivalent: "")
        accessibilityItem.target = self

        menu.addItem(.separator())
        let quitItem = menu.addItem(withTitle: "Quit NoType", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self

        statusItem.menu = menu
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func openHistory() {
        onOpenHistory?()
    }

    @objc private func openDictionary() {
        onOpenDictionary?()
    }

    @objc private func openStats() {
        onOpenStats?()
    }

    @objc private func openConfigFolder() {
        do {
            let url = try ConfigLoader.defaultPath()
            let dir = url.deletingLastPathComponent()
            NSWorkspace.shared.open(dir)
        } catch {
            update(.error)
        }
    }

    func showError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "NoType"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
            self?.update(.idle)
        }
    }

    @objc private func requestAccessibility() {
        _ = KeyboardInjector.isTrusted(prompt: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
