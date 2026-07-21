import AppKit

/// App-level lifecycle and coordinator for the menu-bar voice input app.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBar: StatusBarController?
    private var shortcut: GlobalShortcut?
    private var dictation: DictationController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Load configuration. Missing/invalid config is fatal for the MVP.
        let config: Configuration
        do {
            let path = try ConfigLoader.defaultPath()
            config = try ConfigLoader.load(from: path)
        } catch {
            presentFatalConfigError(error)
            NSApp.terminate(nil)
            return
        }

        // 2. Set up the menu-bar UI.
        let status = StatusBarController()
        self.statusBar = status

        // 3. Wire the dictation pipeline.
        let controller = DictationController(config: config, status: status)
        self.dictation = controller

        // 4. Register the global shortcut.
        let monitor = GlobalShortcut(configuration: config.shortcut)
        monitor.onPress = { [weak controller] in
            print("[App] shortcut pressed")
            Task { @MainActor in controller?.didPressShortcut() }
        }
        monitor.onRelease = { [weak controller] in
            print("[App] shortcut released")
            Task { @MainActor in controller?.didReleaseShortcut() }
        }
        if !monitor.start() {
            status.showError("NoType needs Accessibility permission to listen for global shortcuts. Use the menu to request it.")
        }
        self.shortcut = monitor

        // 5. Prompt for Accessibility up front so injection works later.
        if !KeyboardInjector.isTrusted(prompt: false) {
            status.showError("NoType needs Accessibility permission to inject text at the cursor. Use the menu to request it.")
        }
    }

    private func presentFatalConfigError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "NoType configuration error"
        alert.informativeText = "\(error)\n\nExpected at: ~/.config/notype/config.toml"
        alert.addButton(withTitle: "Quit")
        _ = alert.runModal()
    }
}
