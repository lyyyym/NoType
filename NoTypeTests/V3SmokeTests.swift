import Foundation
import AppKit
import Testing
@testable import NoType

/// End-to-end smoke tests for the V3 flow, driving `DictationController` with stub
/// recorder / ASR / LLM / injector so no microphone, network, or real key injection
/// is required. Proves the wiring: mode selection → instruction forwarding → inject,
/// the plain-dictation short-circuit, and the preview-confirm path.
@MainActor
@Suite("V3Smoke", .serialized)
struct V3SmokeTests {

    // MARK: - Stubs

    final class StubRecorder: AudioRecorder {
        override func start() throws { /* no microphone in tests */ }
        override func stop(reason: AudioRecorder.StopReason = .userReleased) { /* no-op */ }
    }

    final class StubASR: ASRClient {
        let canned: String
        init(canned: String) {
            self.canned = canned
            super.init(config: Configuration.ServiceConfig(baseURL: "https://x.test/v1", apiKey: "k", model: "m"))
        }
        override func transcribe(wavData: Data) async throws -> String { canned }
    }

    final class StubLLM: LLMClient {
        var capturedInstruction = ""
        let canned: String
        init(canned: String) {
            self.canned = canned
            super.init(config: Configuration.LLMConfig(baseURL: "https://x.test/v1", apiKey: "k", model: "m", temperature: 0, maxTokens: 16))
        }
        override func polish(transcript: String, dictionaryHint: String, systemInstruction: String, outputLanguage: String?) async throws -> String {
            capturedInstruction = systemInstruction
            return canned
        }
    }

    final class StubInjector: KeyboardInjector {
        var lastInjected: String?
        override func inject(text: String) throws { lastInjected = text }
    }

    final class StubStatus: DictationStatusReporting {
        func update(_ state: StatusBarController.State, modeName: String?) {}
        func showError(_ message: String) {}
    }

    // MARK: - Helpers

    private func service() -> Configuration.ServiceConfig {
        Configuration.ServiceConfig(baseURL: "https://x.test/v1", apiKey: "k", model: "m")
    }
    private func llmConfig() -> Configuration.LLMConfig {
        Configuration.LLMConfig(baseURL: "https://x.test/v1", apiKey: "k", model: "m", temperature: 0, maxTokens: 16)
    }
    private func twoModeStore(everydayInstruction: String = "Polish it.") throws -> (ModeStore, PolishingMode, PolishingMode) {
        let store = ModeStore(filename: "modes-smoke.json")
        store.resetFile()
        let everyday = PolishingMode(name: "Everyday",
                                     shortcut: .init(key: ".", modifiers: ["command"]),
                                     instruction: everydayInstruction,
                                     isBuiltin: true)
        let plain = PolishingMode(name: "Plain",
                                  shortcut: .init(key: "/", modifiers: ["command", "shift"]),
                                  instruction: "")
        try store.replaceAll([everyday, plain])
        return (store, everyday, plain)
    }

    private func waitFor(timeout: TimeInterval = 2.0, _ condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // MARK: - Tests

    @Test func everydayModeForwardsInstructionAndInjects() async throws {
        let (modes, everyday, _) = try twoModeStore()
        let buffer = AudioBuffer()
        buffer.append(Data(repeating: 0x10, count: 200)) // PCM payload so wavData() > 44 bytes

        let asr = StubASR(canned: "raw text")
        let llm = StubLLM(canned: "polished")
        let injector = StubInjector()

        let config = Configuration(shortcut: .default, asr: service(), llm: llmConfig()) // preview off
        let status = StubStatus()
        let controller = DictationController(config: config,
                                             status: status,
                                             buffer: buffer,
                                             recorder: StubRecorder(buffer: buffer),
                                             asr: asr,
                                             llm: llm,
                                             injector: injector,
                                             modes: modes)
        controller.didPressShortcut(modeID: everyday.id)
        controller.didReleaseShortcut(modeID: everyday.id)

        await waitFor { injector.lastInjected != nil }

        #expect(llm.capturedInstruction == "Polish it.")
        #expect(injector.lastInjected == "polished")
    }

    @Test func plainDictationModeInjectsRawWithoutLLM() async throws {
        let (modes, _, plain) = try twoModeStore()
        let buffer = AudioBuffer()
        buffer.append(Data(repeating: 0x10, count: 200))

        let asr = StubASR(canned: "  raw text  ")
        // Real LLM client: empty instruction short-circuits to the normalized raw transcript.
        let llm = LLMClient(config: llmConfig(), timeout: 1)
        let injector = StubInjector()

        let config = Configuration(shortcut: .default, asr: service(), llm: llmConfig())
        let status = StubStatus()
        let controller = DictationController(config: config,
                                             status: status,
                                             buffer: buffer,
                                             recorder: StubRecorder(buffer: buffer),
                                             asr: asr,
                                             llm: llm,
                                             injector: injector,
                                             modes: modes)
        controller.didPressShortcut(modeID: plain.id)
        controller.didReleaseShortcut(modeID: plain.id)

        await waitFor { injector.lastInjected != nil }

        #expect(injector.lastInjected == "raw text")
    }

    @Test func previewConfirmInjectsProcessedText() async throws {
        let (modes, everyday, _) = try twoModeStore()
        let buffer = AudioBuffer()
        buffer.append(Data(repeating: 0x10, count: 200))

        let asr = StubASR(canned: "raw text")
        let llm = StubLLM(canned: "polished")
        let injector = StubInjector()
        let preview = PreviewWindowController()

        let config = Configuration(shortcut: .default,
                                   asr: service(),
                                   llm: llmConfig(),
                                   showFloatingBubble: false,
                                   bubblePosition: .cursor,
                                   showPreviewBeforeInjection: true)
        let status = StubStatus()
        let controller = DictationController(config: config,
                                             status: status,
                                             buffer: buffer,
                                             recorder: StubRecorder(buffer: buffer),
                                             asr: asr,
                                             llm: llm,
                                             injector: injector,
                                             modes: modes,
                                             bubble: nil,
                                             preview: preview)
        controller.didPressShortcut(modeID: everyday.id)
        controller.didReleaseShortcut(modeID: everyday.id)

        // Wait for the preview to be populated with the processed text.
        await waitFor { preview.currentText == "polished" }
        preview.confirm()

        await waitFor { injector.lastInjected != nil }

        #expect(injector.lastInjected == "polished")
        #expect(preview.resolvedText == "polished")
    }
}
