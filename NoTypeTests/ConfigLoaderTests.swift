import Foundation
import Testing
@testable import NoType

@Suite("ConfigLoader")
struct ConfigLoaderTests {

    @Test func parsesValidConfig() throws {
        let toml = """
        [shortcut]
        key = "."
        modifiers = ["command"]

        [asr]
        base_url = "https://asr.example.com/v1"
        api_key = "sk-asr"
        model = "qwen-asr-flash"

        [llm]
        base_url = "https://llm.example.com/v1"
        api_key = "sk-llm"
        model = "gpt-4o-mini"
        temperature = 0.2
        max_tokens = 2048
        """
        let config = try ConfigLoader.parse(toml)
        #expect(config.shortcut.key == ".")
        #expect(config.shortcut.modifiers == ["command"])
        #expect(config.asr.baseURL == "https://asr.example.com/v1")
        #expect(config.asr.model == "qwen-asr-flash")
        #expect(config.llm.model == "gpt-4o-mini")
        #expect(config.llm.temperature == 0.2)
        #expect(config.llm.maxTokens == 2048)
    }

    @Test func usesDefaultsWhenOptionalFieldsAbsent() throws {
        let toml = """
        [shortcut]
        key = "f12"
        modifiers = ["control", "shift"]

        [asr]
        base_url = "https://a.test/v1"
        api_key = "k"
        model = "m"

        [llm]
        base_url = "https://b.test/v1"
        api_key = "k"
        model = "m"
        """
        let config = try ConfigLoader.parse(toml)
        #expect(config.shortcut.key == "f12")
        #expect(config.shortcut.modifiers == ["control", "shift"])
        #expect(config.llm.temperature == Configuration.LLMConfig.defaultTemperature)
        #expect(config.llm.maxTokens == Configuration.LLMConfig.defaultMaxTokens)
    }

    @Test func rejectsInvalidModifier() {
        let toml = """
        [shortcut]
        key = "."
        modifiers = ["banana"]
        """
        #expect(throws: (any Error).self) { try ConfigLoader.parse(toml) }
    }

    @Test func rejectsInvalidTemperatureRange() {
        let toml = """
        [asr]
        base_url = "https://a.test/v1"
        api_key = "k"
        model = "m"

        [llm]
        base_url = "https://b.test/v1"
        api_key = "k"
        model = "m"
        temperature = 5.0
        """
        #expect(throws: (any Error).self) { try ConfigLoader.parse(toml) }
    }

    @Test func rejectsNonHTTPBaseURL() {
        let toml = """
        [asr]
        base_url = "ftp://a.test"
        api_key = "k"
        model = "m"

        [llm]
        base_url = "https://b.test/v1"
        api_key = "k"
        model = "m"
        """
        #expect(throws: (any Error).self) { try ConfigLoader.parse(toml) }
    }

    @Test func rejectsMissingSection() {
        let toml = """
        [asr]
        base_url = "https://a.test/v1"
        api_key = "k"
        model = "m"
        """
        #expect(throws: (any Error).self) { try ConfigLoader.parse(toml) }
    }

    @Test func unwrapStringArrayParsesValues() throws {
        #expect(try ConfigLoader.unwrapStringArray(#"["command","shift"]"#) == ["command", "shift"])
        #expect(try ConfigLoader.unwrapStringArray("[]") == [])
    }
}
