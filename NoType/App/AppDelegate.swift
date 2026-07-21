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
    private var historyWindow: HistoryWindowController?
    private var statsWindow: StatsWindowController?
    private var dictionaryWindow: DictionaryWindowController?

    private let onboardingStore = OnboardingStore()
    private let historyStore = HistoryStore()
    private let statsStore = StatsStore()
    private let dictionaryStore = DictionaryStore()
    private let modeStore = ModeStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] applicationDidFinishLaunching")
        // 1. Load configuration. If missing or invalid, use a default config so
        //    onboarding can collect the real values from the user.
        let config: Configuration
        do {
            let path = try ConfigLoader.defaultPath()
            config = try ConfigLoader.load(from: path)
            print("[AppDelegate] loaded config from \(path.path)")
        } catch {
            print("[AppDelegate] config load failed: \(error.localizedDescription); starting onboarding with defaults")
            config = AppDelegate.defaultConfiguration()
        }
        self.configuration = config

        // 2. First-launch onboarding.
        let state = onboardingStore.load()
        print("[AppDelegate] onboarding completed: \(state.hasCompletedOnboarding)")
        if !state.hasCompletedOnboarding {
            showOnboarding(config: config)
        } else {
            startNormalFlow(config: config)
        }
    }

    // MARK: - Onboarding

    private func showOnboarding(config: Configuration) {
        print("[AppDelegate] showing onboarding")
        let controller = OnboardingWindowController(configuration: config)
        controller.onComplete = { [weak self] in
            guard let self = self else { return }
            print("[AppDelegate] onboarding complete")
            self.onboardingWindow = nil
            // Reload configuration in case onboarding changed it.
            let freshConfig = (try? ConfigStore.load()) ?? config
            self.configuration = freshConfig
            self.startNormalFlow(config: freshConfig)
        }
        self.onboardingWindow = controller
        controller.showWindow(nil)
        if let window = controller.window {
            print("[AppDelegate] onboarding window is non-nil, ordering front")
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.level = .modalPanel
        } else {
            print("[AppDelegate] onboarding window is nil, falling back to normal flow")
            startNormalFlow(config: config)
        }
    }

    // MARK: - Normal flow

    private func startNormalFlow(config: Configuration) {
        print("[AppDelegate] starting normal flow")
        // 0. Load/seed polishing modes (migrates the legacy shortcut into the
        //    "Everyday polish" default on first launch).
        modeStore.load(legacyEverydayShortcut: config.shortcut)

        // 1. Set up the menu-bar UI.
        let status = StatusBarController()
        status.onOpenSettings = { [weak self] in self?.openSettings() }
        status.onOpenHistory = { [weak self] in self?.openHistory() }
        status.onOpenDictionary = { [weak self] in self?.openDictionary() }
        status.onOpenStats = { [weak self] in self?.openStats() }
        self.statusBar = status

        // 2. Wire the dictation pipeline (mode-aware).
        let controller = DictationController(
            config: config,
            status: status,
            history: historyStore,
            stats: statsStore,
            dictionary: dictionaryStore,
            modes: modeStore
        )
        self.dictation = controller

        // 3. Register one global shortcut per mode.
        let monitor = makeShortcutMonitor(controller: controller)
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

    /// Rebuilds the shortcut monitor (from the current modes) and the dictation
    /// controller (to pick up new ASR/LLM config), called after Settings is saved.
    private func reloadShortcut(configuration: Configuration) {
        guard let status = statusBar else { return }
        // Re-create the dictation controller with the fresh config + shared mode store.
        let controller = DictationController(
            config: configuration,
            status: status,
            history: historyStore,
            stats: statsStore,
            dictionary: dictionaryStore,
            modes: modeStore
        )
        self.dictation = controller

        let monitor = makeShortcutMonitor(controller: controller)
        _ = monitor.start()
        self.shortcut = monitor
    }

    // MARK: - Shortcut wiring

    /// Builds a monitor bound to every current mode's shortcut, forwarding
    /// press/release (with the matched mode id) to the controller.
    private func makeShortcutMonitor(controller: DictationController) -> GlobalShortcut {
        let bindings = modeStore.allModes().map { mode in
            GlobalShortcut.Binding(modeID: mode.id, shortcut: mode.shortcut)
        }
        let monitor = GlobalShortcut(bindings: bindings)
        monitor.onPress = { [weak controller] modeID in
            print("[App] shortcut pressed (mode \(modeID))")
            Task { @MainActor in controller?.didPressShortcut(modeID: modeID) }
        }
        monitor.onRelease = { [weak controller] _ in
            print("[App] shortcut released")
            Task { @MainActor in controller?.didReleaseShortcut(modeID: UUID()) }
        }
        return monitor
    }

    private func openHistory() {
        let controller = HistoryWindowController(historyStore: historyStore) { [weak self] words in
            self?.statsStore.remove(words: words)
            self?.statsWindow?.refresh()
        }
        self.historyWindow = controller
        controller.showWindow(nil)
    }

    private func openDictionary() {
        let controller = DictionaryWindowController(dictionaryStore: dictionaryStore)
        self.dictionaryWindow = controller
        controller.showWindow(nil)
    }

    private func openStats() {
        let controller = StatsWindowController(statsStore: statsStore)
        self.statsWindow = controller
        controller.showWindow(nil)
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
