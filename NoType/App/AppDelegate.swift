import AppKit

/// App-level lifecycle and coordinator for the menu-bar voice input app.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBar: StatusBarController?
    private var shortcut: GlobalShortcut?
    private var dictation: DictationController?
    private var onboardingWindow: OnboardingWindowController?
    private var configuration: Configuration?

    private var settingsWindow: SettingsWindowController?

    private let onboardingStore = OnboardingStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Load configuration. If missing or invalid, use a default config so
        //    onboarding can collect the real values from the user.
        let config: Configuration
        do {
            let path = try ConfigLoader.defaultPath()
            config = try ConfigLoader.load(from: path)
        } catch {
            print("[AppDelegate] config load failed: \(error.localizedDescription); starting onboarding with defaults")
            config = AppDelegate.defaultConfiguration()
        }
        self.configuration = config

        // 2. First-launch onboarding.
        let state = onboardingStore.load()
        if !state.hasCompletedOnboarding {
            showOnboarding(config: config)
        } else {
            startNormalFlow(config: config)
        }
    }

    // MARK: - Onboarding

    private func showOnboarding(config: Configuration) {
        let controller = OnboardingWindowController(configuration: config)
        controller.onComplete = { [weak self] in
            guard let self = self else { return }
            self.onboardingWindow = nil
            // Reload configuration in case onboarding changed it.
            let freshConfig = (try? ConfigStore.load()) ?? config
            self.configuration = freshConfig
            self.startNormalFlow(config: freshConfig)
        }
        self.onboardingWindow = controller
        controller.showWindow(nil)
    }

    // MARK: - Normal flow

    private func startNormalFlow(config: Configuration) {
        // 1. Set up the menu-bar UI.
        let status = StatusBarController()
        status.onOpenSettings = { [weak self] in self?.openSettings() }
        status.onOpenHistory = { [weak self] in self?.openHistory() }
        status.onOpenDictionary = { [weak self] in self?.openDictionary() }
        status.onOpenStats = { [weak self] in self?.openStats() }
        self.statusBar = status

        // 2. Wire the dictation pipeline.
        let controller = DictationController(config: config, status: status)
        self.dictation = controller

        // 3. Register the global shortcut.
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

        // 4. Prompt for Accessibility up front so injection works later.
        if !KeyboardInjector.isTrusted(prompt: false) {
            status.showError("NoType needs Accessibility permission to inject text at the cursor. Use the menu to request it.")
        }
    }

    // MARK: - Menu actions

    private func openSettings() {
        guard let config = configuration else { return }
        let controller = SettingsWindowController(configuration: config)
        controller.onSave = { [weak self] updated in
            self?.configuration = updated
            self?.reloadShortcut(configuration: updated)
        }
        self.settingsWindow = controller
        controller.showWindow(nil)
    }

    private func reloadShortcut(configuration: Configuration) {
        shortcut?.stop()
        let monitor = GlobalShortcut(configuration: configuration.shortcut)
        guard let controller = dictation else { return }
        monitor.onPress = { [weak controller] in
            print("[App] shortcut pressed")
            Task { @MainActor in controller?.didPressShortcut() }
        }
        monitor.onRelease = { [weak controller] in
            print("[App] shortcut released")
            Task { @MainActor in controller?.didReleaseShortcut() }
        }
        _ = monitor.start()
        self.shortcut = monitor

        // Re-create dictation controller so it picks up new ASR/LLM config.
        if let status = statusBar {
            self.dictation = DictationController(config: configuration, status: status)
        }
    }

    private func openHistory() {
        // TODO: Implement in User Story 3.
    }

    private func openDictionary() {
        // TODO: Implement in User Story 5.
    }

    private func openStats() {
        // TODO: Implement in User Story 4.
    }

    // MARK: - Defaults

    private static func defaultConfiguration() -> Configuration {
        Configuration(
            shortcut: .default,
            asr: .init(baseURL: "", apiKey: "", model: ""),
            llm: .init(baseURL: "", apiKey: "", model: "", temperature: Configuration.LLMConfig.defaultTemperature, maxTokens: Configuration.LLMConfig.defaultMaxTokens),
            showFloatingBubble: true,
            bubblePosition: .cursor
        )
    }
}
