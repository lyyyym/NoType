import Foundation
import Testing
@testable import NoType

@Suite("ConfigurationValidation")
struct ConfigurationValidationTests {

    private func validConfig() -> Configuration {
        Configuration(
            shortcut: .init(key: ".", modifiers: ["command"]),
            asr: .init(baseURL: "https://asr.test/v1", apiKey: "key", model: "model"),
            llm: .init(baseURL: "https://llm.test/v1", apiKey: "key", model: "model", temperature: 0.0, maxTokens: 4096)
        )
    }

    @Test func rejectsEmptyShortcutKey() {
        let config = validConfig()
        let text = """
        [shortcut]
        key = ""
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
        #expect(throws: (any Error).self) { try ConfigLoader.parse(text) }
    }

    @Test func rejectsNonHTTPBaseURL() {
        let text = """
        [shortcut]
        key = "."
        modifiers = ["command"]

        [asr]
        base_url = "ftp://asr.test/v1"
        api_key = "key"
        model = "model"

        [llm]
        base_url = "https://llm.test/v1"
        api_key = "key"
        model = "model"
        """
        #expect(throws: (any Error).self) { try ConfigLoader.parse(text) }
    }

    @Test func rejectsInvalidTemperature() {
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
        temperature = 5.0
        """
        #expect(throws: (any Error).self) { try ConfigLoader.parse(text) }
    }
}
