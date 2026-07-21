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
