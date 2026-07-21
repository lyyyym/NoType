import Foundation

/// Calls an OpenAI-compatible LLM endpoint to polish a transcript.
/// See `contracts/llm-api.md`.
final class LLMClient {

    let config: Configuration.LLMConfig
    let session: URLSession
    let timeout: TimeInterval

    init(config: Configuration.LLMConfig, session: URLSession = .shared, timeout: TimeInterval = 10) {
        self.config = config
        self.session = session
        self.timeout = timeout
    }

    /// Builds the chat endpoint URL: `{baseURL}/chat/completions`.
    func endpointURL() throws -> URL {
        return try Self.endpointURL(baseURL: config.baseURL)
    }

    static func endpointURL(baseURL: String) throws -> URL {
        let trimmed = baseURL.hasSuffix("/")
            ? String(baseURL.dropLast())
            : baseURL
        guard let url = URL(string: trimmed + "/chat/completions") else {
            throw TranscriptionError.decoding("invalid LLM base URL: \(baseURL)")
        }
        return url
    }

    /// Sends the transcript for polishing and returns the polished text.
    /// - Throws: `TranscriptionError.llmFailed` on network or HTTP failure.
    func polish(transcript: String) async throws -> String {
        let url = try endpointURL()
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = try Self.requestBody(
            model: config.model,
            messages: PolishPrompt.messages(for: transcript),
            temperature: config.temperature,
            maxTokens: config.maxTokens
        )
        request.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TranscriptionError.llmFailed(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            print("[LLM] non-HTTP response")
            throw TranscriptionError.llmFailed("non-HTTP response")
        }
        print("[LLM] status: \(http.statusCode)")
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[LLM] error body: \(body)")
            throw TranscriptionError.llmFailed("HTTP \(http.statusCode): \(body)")
        }
        let bodyPreview = String(data: data, encoding: .utf8) ?? "<binary>"
        print("[LLM] body: \(bodyPreview)")
        return try Self.decodeCompletion(data)
    }

    /// Builds the JSON request body for `/chat/completions`.
    static func requestBody(model: String, messages: [[String: String]], temperature: Double, maxTokens: Int) throws -> Data {
        let payload: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens,
        ]
        do {
            return try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            throw TranscriptionError.decoding("could not encode LLM request: \(error)")
        }
    }

    /// Decodes `choices[0].message.content` and normalizes it.
    static func decodeCompletion(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let preview = String(data: data, encoding: .utf8) ?? "<binary>"
            throw TranscriptionError.decoding("LLM response decode failed. Body: \(preview)")
        }
        let normalized = PolishPrompt.normalize(content)
        guard !normalized.isEmpty else {
            let preview = String(data: data, encoding: .utf8) ?? "<binary>"
            throw TranscriptionError.llmFailed("LLM returned empty content. Response: \(preview)")
        }
        return normalized
    }
}
