import Foundation

/// A named, user-configurable polishing profile bound to a global shortcut.
///
/// Each mode carries its own polishing instruction (the LLM system message)
/// and an optional target output language. A mode with an empty instruction
/// acts as plain dictation (the raw transcript is used verbatim). See
/// `specs/003-modes-and-preview/contracts/polish-modes.md`.
struct PolishingMode: Codable, Identifiable {
    let id: UUID
    var name: String
    var shortcut: Configuration.Shortcut
    var instruction: String
    var outputLanguage: String?
    var isBuiltin: Bool
    var createdAt: Date

    init(id: UUID = UUID(),
         name: String,
         shortcut: Configuration.Shortcut,
         instruction: String,
         outputLanguage: String? = nil,
         isBuiltin: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.shortcut = shortcut
        self.instruction = instruction
        self.outputLanguage = outputLanguage
        self.isBuiltin = isBuiltin
        self.createdAt = createdAt
    }
}

extension PolishingMode {
    /// `true` when this mode performs no LLM polishing (raw transcript only).
    var isPlainDictation: Bool {
        instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension PolishingMode {
    /// Default instruction for the "Everyday polish" built-in. This is also the V2
    /// system prompt, so an upgrading user's polish output is byte-identical (SC-005).
    static let everydayInstruction =
        "Polish the following transcript for grammar, punctuation, and fluency. " +
        "Remove filler words and sounds (e.g. um, uh, er, 嗯, 呃, 那个, 就是, 然后). " +
        "Smooth out repetitions while preserving the original language and meaning. " +
        "Do not add explanations or commentary."

    /// Default instruction for the "Translate to English" built-in.
    static let translateInstruction =
        "Translate the following transcript into natural, fluent English. " +
        "Preserve the original meaning. Do not add commentary."

    /// Default instruction for the "Formal / email" built-in.
    static let formalInstruction =
        "Rewrite the following transcript in clear, formal, professional prose " +
        "suitable for an email or document. Fix grammar and tone. Preserve the " +
        "original meaning. Do not add commentary."

    /// Builds the three shipped default modes, assigning distinct shortcuts.
    /// `everydayShortcut` is the migrated V2 shortcut (falls back to the V2 default).
    static func defaults(everydayShortcut: Configuration.Shortcut = .default) -> [PolishingMode] {
        let everyday = PolishingMode(
            name: "Everyday polish",
            shortcut: everydayShortcut,
            instruction: everydayInstruction,
            isBuiltin: true
        )
        // Candidate shortcuts for the secondary modes, in preference order.
        let candidates: [Configuration.Shortcut] = [
            .init(key: ".", modifiers: ["command", "shift"]),
            .init(key: ".", modifiers: ["command", "option"]),
            .init(key: ".", modifiers: ["command", "control"])
        ]
        var used: Set<Configuration.Shortcut> = [everyday.shortcut]
        var pool = candidates.makeIterator()
        func nextFree() -> Configuration.Shortcut {
            while let candidate = pool.next() {
                if !used.contains(candidate) {
                    used.insert(candidate)
                    return candidate
                }
            }
            // Exhausted candidates (extremely unlikely with 3 modes); reuse the last.
            return candidates.last ?? everyday.shortcut
        }
        let translate = PolishingMode(
            name: "Translate to English",
            shortcut: nextFree(),
            instruction: translateInstruction,
            outputLanguage: "English",
            isBuiltin: true
        )
        let formal = PolishingMode(
            name: "Formal / email",
            shortcut: nextFree(),
            instruction: formalInstruction,
            isBuiltin: true
        )
        return [everyday, translate, formal]
    }
}
