import Foundation
import Testing
@testable import NoType

@Suite("ConfigStore")
struct ConfigStoreTests {

    @Test func serializeAndParseRoundTrip() throws {
        let original = Configuration(
            shortcut: .init(key: "/", modifiers: ["command", "shift"]),
            asr: .init(baseURL: "https://asr.test/v1", apiKey: "asr-key", model: "asr-model"),
            llm: .init(baseURL: "https://llm.test/v1", apiKey: "llm-key", model: "llm-model", temperature: 0.5, maxTokens: 1024),
            showFloatingBubble: false,
            bubblePosition: .menuBar
        )
        let text = ConfigStore.serialize(original)
        let parsed = try ConfigLoader.parse(text)

        #expect(parsed.shortcut.key == "/")
        #expect(parsed.shortcut.modifiers == ["command", "shift"])
        #expect(parsed.asr.baseURL == "https://asr.test/v1")
        #expect(parsed.llm.maxTokens == 1024)
        #expect(parsed.llm.temperature == 0.5)
        #expect(parsed.showFloatingBubble == false)
        #expect(parsed.bubblePosition == .menuBar)
    }

    @Test func defaultUIValuesWhenSectionMissing() throws {
        let text = """
        [shortcut]
        key = "."
        modifiers = ["command"]

        [asr]
        base_url = "https://asr.test/v1"
        api_key = "key"
        model = "model"

        [llm]
        base_url = "https://llm.test/v1"
        api_key = "key"
        model = "model"
        """
        let config = try ConfigLoader.parse(text)
        #expect(config.showFloatingBubble == true)
        #expect(config.bubblePosition == .cursor)
    }
}
