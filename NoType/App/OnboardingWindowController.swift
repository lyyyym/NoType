import AppKit
import AVFoundation

/// First-launch onboarding wizard: microphone, accessibility, basic configuration.
@MainActor
final class OnboardingWindowController: NSWindowController {

    var onComplete: (() -> Void)?

    private var currentPage = 0
    private var pages: [NSView] = []
    private let nextButton = NSButton(title: "Next", target: nil, action: nil)
    private let backButton = NSButton(title: "Back", target: nil, action: nil)
    private let container = NSBox()
    private let pageLabel = NSTextField(labelWithString: "")
    private var configuration: Configuration

    private let onboardingStore = OnboardingStore()
    private var shortcutEditor: ShortcutEditorView?
    private var asrFields: ServiceConfigFields?
    private var llmFields: ServiceConfigFields?

    init(configuration: Configuration) {
        self.configuration = configuration
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to NoType"
        window.center()
        super.init(window: window)

        self.pages = [
            createMicrophonePage(),
            createAccessibilityPage(),
            createConfigPage()
        ]
        setupUI()
        showPage(0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        container.boxType = .custom
        container.isTransparent = true
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)

        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        pageLabel.alignment = .center
        pageLabel.font = NSFont.boldSystemFont(ofSize: 13)
        contentView.addSubview(pageLabel)

        backButton.target = self
        backButton.action = #selector(goBack)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backButton)

        nextButton.target = self
        nextButton.action = #selector(goNext)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.keyEquivalent = "\r"
        contentView.addSubview(nextButton)

        NSLayoutConstraint.activate([
            pageLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            pageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            pageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            container.topAnchor.constraint(equalTo: pageLabel.bottomAnchor, constant: 12),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            container.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -16),

            backButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            backButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            nextButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            nextButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])
    }

    // MARK: - Page navigation

    private func showPage(_ index: Int) {
        currentPage = index
        container.contentView?.removeFromSuperview()
        let page = pages[index]
        page.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(page)
        NSLayoutConstraint.activate([
            page.topAnchor.constraint(equalTo: container.topAnchor),
            page.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            page.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        pageLabel.stringValue = "Step \(index + 1) of \(pages.count)"
        backButton.isHidden = (index == 0)
        nextButton.title = (index == pages.count - 1) ? "Finish" : "Next"
    }

    @objc private func goNext() {
        if currentPage == pages.count - 1 {
            finish()
        } else {
            showPage(currentPage + 1)
        }
    }

    @objc private func goBack() {
        showPage(currentPage - 1)
    }

    // MARK: - Page 1: Microphone

    private func createMicrophonePage() -> NSView {
        let stack = NSStackView(views: [
            NSTextField(wrappingLabelWithString: "NoType needs microphone access to record your voice. Audio stays on your device until it is sent to your chosen ASR service."),
            makeButton(title: "Request Microphone Access", action: #selector(requestMicrophone))
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    @objc private func requestMicrophone() {
        AVAudioApplication.requestRecordPermission { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let state = self.onboardingStore.load()
                self.onboardingStore.save(OnboardingStoreMutator.microphoneRequested(state))
            }
        }
    }

    // MARK: - Page 2: Accessibility

    private func createAccessibilityPage() -> NSView {
        let text = NSTextField(wrappingLabelWithString: "NoType needs Accessibility permission to listen for your global shortcut and to inject text at the cursor. macOS will open System Settings for you.")
        let button = makeButton(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings))
        let stack = NSStackView(views: [text, button])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    @objc private func openAccessibilitySettings() {
        onboardingStore.save(OnboardingStoreMutator.accessibilityRequested(onboardingStore.load()))
        _ = KeyboardInjector.isTrusted(prompt: true)
    }

    // MARK: - Page 3: Basic config

    private func createConfigPage() -> NSView {
        let shortcut = ShortcutEditorView(configuration: configuration.shortcut)
        self.shortcutEditor = shortcut

        let asr = ServiceConfigFields(title: "ASR", baseURL: configuration.asr.baseURL, apiKey: configuration.asr.apiKey, model: configuration.asr.model)
        self.asrFields = asr

        let llm = ServiceConfigFields(title: "LLM", baseURL: configuration.llm.baseURL, apiKey: configuration.llm.apiKey, model: configuration.llm.model)
        self.llmFields = llm

        let stack = NSStackView(views: [
            NSTextField(wrappingLabelWithString: "Enter your ASR and LLM service details. You can change these later in Settings."),
            shortcut.view,
            asr.view,
            llm.view
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    // MARK: - Finish

    private func finish() {
        guard let shortcut = shortcutEditor?.shortcut,
              let asr = asrFields?.serviceConfig,
              let llm = llmFields?.llmConfig else {
            showError("Please complete all configuration fields.")
            return
        }
        configuration.shortcut = shortcut
        configuration.asr = asr
        configuration.llm = llm

        do {
            try ConfigStore.save(configuration)
            var state = onboardingStore.load()
            state.basicConfigSaved = true
            state.hasCompletedOnboarding = true
            onboardingStore.save(state)
            onComplete?()
            close()
        } catch {
            showError("Could not save configuration: \(error.localizedDescription)")
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

    // MARK: - Helpers

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }
}

// MARK: - Onboarding state mutations

private enum OnboardingStoreMutator {
    static func microphoneRequested(_ state: OnboardingState) -> OnboardingState {
        var state = state
        state.microphonePermissionRequested = true
        return state
    }

    static func accessibilityRequested(_ state: OnboardingState) -> OnboardingState {
        var state = state
        state.accessibilityPermissionRequested = true
        return state
    }
}

// MARK: - Reusable form views

@MainActor
private final class ShortcutEditorView {
    let keyField = NSTextField(string: "")
    let modifiersField = NSTextField(string: "")
    let view: NSView

    var shortcut: Configuration.Shortcut? {
        let key = keyField.stringValue.trimmingCharacters(in: .whitespaces)
        let raw = modifiersField.stringValue
        let modifiers = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard !key.isEmpty, !modifiers.isEmpty else { return nil }
        return Configuration.Shortcut(key: key, modifiers: modifiers)
    }

    init(configuration: Configuration.Shortcut) {
        keyField.stringValue = configuration.key
        modifiersField.stringValue = configuration.modifiers.joined(separator: ", ")
        let stack = NSStackView(views: [
            NSTextField(labelWithString: "Shortcut key:"),
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

@MainActor
private final class ServiceConfigFields {
    let title: String
    let baseURLField = NSTextField(string: "")
    let apiKeyField = NSTextField(string: "")
    let modelField = NSTextField(string: "")
    let view: NSView

    var serviceConfig: Configuration.ServiceConfig? {
        let baseURL = baseURLField.stringValue.trimmingCharacters(in: .whitespaces)
        let apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespaces)
        let model = modelField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !baseURL.isEmpty, !apiKey.isEmpty, !model.isEmpty else { return nil }
        return Configuration.ServiceConfig(baseURL: baseURL, apiKey: apiKey, model: model)
    }

    var llmConfig: Configuration.LLMConfig? {
        guard let service = serviceConfig else { return nil }
        return Configuration.LLMConfig(baseURL: service.baseURL, apiKey: service.apiKey, model: service.model, temperature: 0.0, maxTokens: 4096)
    }

    init(title: String, baseURL: String, apiKey: String, model: String) {
        self.title = title
        baseURLField.stringValue = baseURL
        apiKeyField.stringValue = apiKey
        modelField.stringValue = model
        let stack = NSStackView(views: [
            NSTextField(labelWithString: "\(title) base URL:"),
            baseURLField,
            NSTextField(labelWithString: "\(title) API key:"),
            apiKeyField,
            NSTextField(labelWithString: "\(title) model:"),
            modelField
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        view = stack
    }
}
