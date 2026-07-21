import Foundation

/// Local rolling history of the most recent successful voice inputs.
final class HistoryStore {

    static let maxEntries = 50

    private let store = JSONFileStore<[RecordingEntry]>(filename: "history.json")
    private var entries: [RecordingEntry] = []

    /// Loads history from disk. Returns the loaded entries.
    @discardableResult
    func load() -> [RecordingEntry] {
        do {
            entries = (try store.load()) ?? []
        } catch {
            print("[HistoryStore] failed to load: \(error.localizedDescription)")
            entries = []
        }
        return entries
    }

    /// All history entries, newest first.
    func allEntries() -> [RecordingEntry] {
        entries
    }

    /// Appends a new entry to the front and evicts the oldest if the cap is exceeded.
    func append(_ entry: RecordingEntry) {
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries.removeLast()
        }
        save()
    }

    /// Deletes the entry with the given id. Returns the removed entry, if any.
    @discardableResult
    func delete(id: UUID) -> RecordingEntry? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = entries.remove(at: index)
        save()
        return removed
    }

    /// Clears all history.
    func reset() {
        entries.removeAll()
        save()
    }

    private func save() {
        do {
            try store.save(entries)
        } catch {
            print("[HistoryStore] failed to save: \(error.localizedDescription)")
        }
    }
}
