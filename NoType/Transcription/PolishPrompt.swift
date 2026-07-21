import Foundation

/// Builds the LLM prompt used to polish a raw transcript. See `contracts/llm-api.md`.
enum PolishPrompt {

    /// System instruction for the polishing request.
    static let systemPrompt =
        "Polish the following transcript for grammar and punctuation. " +
        "Preserve the original language. Do not add explanations."

    /// Builds the message array for an OpenAI-compatible `/chat/completions` request,
    /// optionally including personal dictionary hints.
    static func messages(for transcript: String, dictionaryHint: String = "") -> [[String: String]] {
        var content = systemPrompt
        if !dictionaryHint.isEmpty {
            content += "\n\n" + dictionaryHint
        }
        return [
            ["role": "system", "content": content],
            ["role": "user", "content": transcript],
        ]
    }

    /// Normalizes the LLM output before injection: trims surrounding whitespace
    /// and strips a single pair of surrounding quotes that some models add.
    static func normalize(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 2, trimmed.hasPrefix("\""), trimmed.hasSuffix("\"") {
            trimmed = String(trimmed.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}
