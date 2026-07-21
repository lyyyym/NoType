import Foundation

/// Persists and manages the user's personal dictionary.
final class DictionaryStore {

    private let store = JSONFileStore<[PersonalDictionaryEntry]>(filename: "dictionary.json")
    private var entries: [PersonalDictionaryEntry] = []

    /// Loads entries from disk.
    @discardableResult
    func load() -> [PersonalDictionaryEntry] {
        do {
            entries = (try store.load()) ?? []
        } catch {
            print("[DictionaryStore] failed to load: \(error.localizedDescription)")
            entries = []
        }
        return entries
    }

    /// All dictionary entries.
    func allEntries() -> [PersonalDictionaryEntry] {
        entries
    }

    /// Adds a new entry if its term is unique.
    @discardableResult
    func add(_ entry: PersonalDictionaryEntry) -> Bool {
        guard !entry.term.isEmpty else { return false }
        guard !entries.contains(where: { $0.term == entry.term }) else { return false }
        entries.append(entry)
        save()
        return true
    }

    /// Updates an existing entry. Returns true if the update succeeded.
    @discardableResult
    func update(id: UUID, term: String, hint: String?) -> Bool {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        // Disallow changing the term to one that already exists on another entry.
        let duplicate = entries.firstIndex { $0.term == trimmed && $0.id != id }
        guard duplicate == nil else { return false }
        entries[index] = PersonalDictionaryEntry(id: id, term: trimmed, hint: hint, createdAt: entries[index].createdAt)
        save()
        return true
    }

    /// Deletes the entry with the given id.
    @discardableResult
    func delete(id: UUID) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        entries.remove(at: index)
        save()
        return true
    }

    /// Formats entries as a hint block for the LLM polish prompt.
    func promptHint() -> String {
        guard !entries.isEmpty else { return "" }
        let lines = entries.map { entry in
            if let hint = entry.hint, !hint.isEmpty {
                return "- \"\(entry.term)\" -> \(hint)"
            } else {
                return "- \"\(entry.term)\""
            }
        }
        return "Preferred terms (use when contextually appropriate):\n" + lines.joined(separator: "\n")
    }

    private func save() {
        do {
            try store.save(entries)
        } catch {
            print("[DictionaryStore] failed to save: \(error.localizedDescription)")
        }
    }
}
