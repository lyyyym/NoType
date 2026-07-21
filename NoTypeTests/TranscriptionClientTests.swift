import Foundation
import Testing
@testable import NoType

@Suite("TranscriptionClient")
struct TranscriptionClientTests {

    // MARK: - URL building

    @Test func asrEndpointURLStripsTrailingSlash() throws {
        let url = try ASRClient.endpointURL(baseURL: "https://a.test/v1/")
        #expect(url.absoluteString == "https://a.test/v1/chat/completions")
    }

    @Test func asrEndpointURLWithoutTrailingSlash() throws {
        let url = try ASRClient.endpointURL(baseURL: "https://a.test/v1")
        #expect(url.absoluteString == "https://a.test/v1/chat/completions")
    }

    @Test func llmEndpointURL() throws {
        let url = try LLMClient.endpointURL(baseURL: "https://b.test/v1")
        #expect(url.absoluteString == "https://b.test/v1/chat/completions")
    }

    // MARK: - ASR decoding

    @Test func asrDecodeTranscription() throws {
        let data = Data(#"{"choices":[{"message":{"content":"hello world"}}]}"#.utf8)
        #expect(try ASRClient.decodeTranscription(data) == "hello world")
    }

    @Test func asrDecodeExtractsFromTags() throws {
        let data = Data(#"{"choices":[{"message":{"content":"<asr_text>你好</asr_text>"}}]}"#.utf8)
        #expect(try ASRClient.decodeTranscription(data) == "你好")
    }

    @Test func asrDecodeRejectsEmptyText() {
        let data = Data(#"{"choices":[{"message":{"content":"   "}}]}"#.utf8)
        #expect(throws: (any Error).self) { try ASRClient.decodeTranscription(data) }
    }

    @Test func asrDecodeRejectsMissingField() {
        let data = Data(#"{"other":"x"}"#.utf8)
        #expect(throws: (any Error).self) { try ASRClient.decodeTranscription(data) }
    }

    // MARK: - LLM decoding

    @Test func llmDecodeCompletion() throws {
        let payload = #"{"choices":[{"message":{"role":"assistant","content":"Hello!"}}]}"#
        let data = Data(payload.utf8)
        #expect(try LLMClient.decodeCompletion(data) == "Hello!")
    }

    @Test func llmDecodeStripsQuotes() throws {
        let payload = #"{"choices":[{"message":{"role":"assistant","content":"  \"你好\"  "}}]}"#
        let data = Data(payload.utf8)
        #expect(try LLMClient.decodeCompletion(data) == "你好")
    }

    @Test func llmDecodeRejectsEmptyContent() {
        let payload = #"{"choices":[{"message":{"role":"assistant","content":""}}]}"#
        let data = Data(payload.utf8)
        #expect(throws: (any Error).self) { try LLMClient.decodeCompletion(data) }
    }

    // MARK: - Request building

    @Test func llmRequestBodyContainsModelAndMessages() throws {
        let body = try LLMClient.requestBody(
            model: "gpt-4o-mini",
            messages: PolishPrompt.messages(for: "hi"),
            temperature: 0.0,
            maxTokens: 512
        )
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(json != nil)
        #expect(json?["model"] as? String == "gpt-4o-mini")
        #expect(json?["max_tokens"] as? Int == 512)
        #expect(json?["temperature"] as? Double == 0.0)
        let messages = json?["messages"] as? [[String: String]]
        #expect(messages?.count == 2)
    }

    @Test func asrRequestBodyContainsModelAndAudioURL() throws {
        let wav = Data("RIFF".utf8)
        let body = try ASRClient.requestBody(model: "qwen3-asr-flash", wav: wav)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(json?["model"] as? String == "qwen3-asr-flash")
        let messages = json?["messages"] as? [[String: Any]]
        #expect(messages?.count == 1)
        let content = messages?.first?["content"] as? [[String: Any]]
        #expect(content?.count == 1)
        #expect(content?.first?["type"] as? String == "audio")
        #expect((content?.first?["audio"] as? String)?.hasPrefix("data:audio/wav;base64,") == true)
    }
}
