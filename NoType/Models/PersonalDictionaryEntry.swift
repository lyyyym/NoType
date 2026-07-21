import Foundation

/// A user-managed term or phrase used as a hint during LLM polish.
struct PersonalDictionaryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let term: String
    let hint: String?
    let createdAt: Date

    init(id: UUID = UUID(), term: String, hint: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hint = hint?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }
}
