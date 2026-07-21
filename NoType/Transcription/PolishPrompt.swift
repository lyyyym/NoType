import Foundation

/// Builds the LLM prompt used to polish a raw transcript. See `contracts/llm-api.md`
/// and `specs/003-modes-and-preview/contracts/polish-modes.md`.
enum PolishPrompt {

    /// System instruction for the default "Everyday polish" mode. Anchored to the
    /// shared constant so an upgrading V2 user gets byte-identical output (SC-005).
    static let systemPrompt = PolishingMode.everydayInstruction

    /// Builds the message array for an OpenAI-compatible `/chat/completions` request
    /// using the default everyday instruction, optionally with dictionary hints.
    static func messages(for transcript: String, dictionaryHint: String = "") -> [[String: String]] {
        messages(for: transcript, dictionaryHint: dictionaryHint, systemInstruction: systemPrompt, outputLanguage: nil)
    }

    /// Builds the message array for a specific polishing mode.
    ///
    /// - When `systemInstruction` is empty, no system message is produced (the caller
    ///   should skip the LLM and use the raw transcript — plain dictation).
    /// - `outputLanguage` and `dictionaryHint`, when present, are appended to the
    ///   system message so every mode still benefits from the personal dictionary.
    static func messages(for transcript: String,
                         dictionaryHint: String = "",
                         systemInstruction: String,
                         outputLanguage: String?) -> [[String: String]] {
        var messages: [[String: String]] = []
        let systemContent = composeSystemMessage(instruction: systemInstruction,
                                                 outputLanguage: outputLanguage,
                                                 dictionaryHint: dictionaryHint)
        if !systemContent.isEmpty {
            messages.append(["role": "system", "content": systemContent])
        }
        messages.append(["role": "user", "content": transcript])
        return messages
    }

    /// Composes the system message text from a mode's instruction, optional output
    /// language, and dictionary hint. Exposed for unit testing.
    static func composeSystemMessage(instruction: String, outputLanguage: String?, dictionaryHint: String) -> String {
        let trimmedInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInstruction.isEmpty else { return "" }
        var content = trimmedInstruction
        if let language = outputLanguage?.trimmingCharacters(in: .whitespacesAndNewlines), !language.isEmpty {
            content += "\nOutput language: " + language
        }
        if !dictionaryHint.isEmpty {
            content += "\n\n" + dictionaryHint
        }
        return content
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
