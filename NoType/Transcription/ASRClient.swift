import Foundation

/// Calls an OpenAI-compatible ASR endpoint for Alibaba Cloud's Qwen ASR models.
///
/// These models (e.g. `qwen3-asr-flash`) expose ASR through the
/// `/v1/chat/completions` endpoint with an `audio_url` content part,
/// rather than the standard Whisper-style `/v1/audio/transcriptions` endpoint.
final class ASRClient {

    let config: Configuration.ServiceConfig
    let session: URLSession
    let timeout: TimeInterval

    init(config: Configuration.ServiceConfig, session: URLSession = .shared, timeout: TimeInterval = 30) {
        self.config = config
        self.session = session
        self.timeout = timeout
    }

    /// Builds the transcription endpoint URL: `{baseURL}/chat/completions`.
    /// Exposed for testability.
    func endpointURL() throws -> URL {
        return try Self.endpointURL(baseURL: config.baseURL)
    }

    static func endpointURL(baseURL: String) throws -> URL {
        let trimmed = baseURL.hasSuffix("/")
            ? String(baseURL.dropLast())
            : baseURL
        guard let url = URL(string: trimmed + "/chat/completions") else {
            throw TranscriptionError.decoding("invalid ASR base URL: \(baseURL)")
        }
        return url
    }

    /// Sends the WAV audio and returns the raw transcript.
    /// - Throws: `TranscriptionError` on network or HTTP failure.
    func transcribe(wavData: Data) async throws -> String {
        let url = try endpointURL()
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.requestBody(model: config.model, wav: wavData)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TranscriptionError.asrFailed(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            print("[ASR] non-HTTP response")
            throw TranscriptionError.asrFailed("non-HTTP response")
        }
        print("[ASR] status: \(http.statusCode)")
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[ASR] error body: \(body)")
            throw TranscriptionError.asrFailed("HTTP \(http.statusCode): \(body)")
        }
        let bodyPreview = String(data: data, encoding: .utf8) ?? "<binary>"
        print("[ASR] body: \(bodyPreview)")
        return try Self.decodeTranscription(data)
    }

    /// Builds the JSON request body for `chat.completions` with a base64 audio URL.
    static func requestBody(model: String, wav: Data) throws -> Data {
        let base64 = wav.base64EncodedString()
        let audioURL = "data:audio/wav;base64,\(base64)"
        let content: [[String: Any]] = [
            [
                "type": "audio",
                "audio": audioURL,
            ],
        ]
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": content],
            ],
        ]
        do {
            return try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            throw TranscriptionError.decoding("could not encode ASR request: \(error)")
        }
    }

    /// Decodes `choices[0].message.content` and extracts text from `<asr_text>` tags.
    static func decodeTranscription(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let preview = String(data: data, encoding: .utf8) ?? "<binary>"
            throw TranscriptionError.decoding("ASR response decode failed. Body: \(preview)")
        }
        let text = extractASRText(from: content)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranscriptionError.emptyTranscription(content)
        }
        return trimmed
    }

    /// Qwen ASR wraps the result in `<asr_text>...</asr_text>`.
    /// If the tags are absent, return the whole content.
    static func extractASRText(from content: String) -> String {
        guard let startRange = content.range(of: "<asr_text>"),
              let endRange = content.range(of: "</asr_text>") else {
            return content
        }
        return String(content[startRange.upperBound..<endRange.lowerBound])
    }
}
