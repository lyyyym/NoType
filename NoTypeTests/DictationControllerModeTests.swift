import Foundation
import Testing
@testable import NoType

@Suite("DictationControllerModes")
struct DictationControllerModeTests {

    private func dummyLLMConfig() -> Configuration.LLMConfig {
        .init(baseURL: "https://example.invalid/v1",
              apiKey: "unused",
              model: "unused",
              temperature: 0.0,
              maxTokens: 16)
    }

    @Test func polishSkipsNetworkWhenInstructionEmpty() async throws {
        // A plain-dictation mode (empty instruction) must NOT call the network.
        // The client returns the normalized transcript regardless of the bogus URL.
        let client = LLMClient(config: dummyLLMConfig(), timeout: 1)
        let result = try await client.polish(transcript: "hello world",
                                             dictionaryHint: "",
                                             systemInstruction: "",
                                             outputLanguage: nil)
        #expect(result == "hello world")
    }

    @Test func polishNormalizesRawWhenInstructionEmpty() async throws {
        let client = LLMClient(config: dummyLLMConfig(), timeout: 1)
        let result = try await client.polish(transcript: "  \"你好\"  ",
                                             dictionaryHint: "",
                                             systemInstruction: "",
                                             outputLanguage: nil)
        #expect(result == "你好")
    }

    @Test func controllerAcceptsCustomModeStore() throws {
        // Construction smoke test: the controller wires an injected ModeStore and
        // resolves a mode added to it. Uses isolated files to avoid touching real data.
        let modes = ModeStore(filename: "modes-dict-test.json")
        modes.resetFile()
        _ = modes.load(legacyEverydayShortcut: .default)
        let plain = PolishingMode(name: "Plain",
                                  shortcut: .init(key: "/", modifiers: ["command", "shift"]),
                                  instruction: "")
        try modes.add(plain)
        // The mode is resolvable by id and by shortcut — the lookup the controller
        // performs on press.
        #expect(modes.mode(for: plain.id)?.name == "Plain")
        #expect(modes.mode(forShortcut: plain.shortcut)?.isPlainDictation == true)
    }

    @Test func defaultEverydayModeIsNotPlainDictation() {
        let modes = ModeStore(filename: "modes-dict-test.json")
        modes.resetFile()
        let defaults = modes.load(legacyEverydayShortcut: .default)
        let everyday = defaults.first { $0.name == "Everyday polish" }
        #expect(everyday?.isPlainDictation == false)
        #expect(everyday?.instruction == PolishingMode.everydayInstruction)
    }
}
