import Foundation

/// Persists and manages the user's polishing modes (`modes.json`).
///
/// On first launch (missing or corrupt file) it seeds the three built-in default
/// modes, migrating the supplied legacy shortcut into the "Everyday polish" mode
/// so V2 users keep their shortcut and polish style. See
/// `specs/003-modes-and-preview/data-model.md` and `contracts/polish-modes.md`.
final class ModeStore {

    enum ModeError: Error, Equatable {
        /// Two modes share the same shortcut combination.
        case duplicateShortcut(Configuration.Shortcut)
        /// A name was empty after trimming.
        case emptyName
        /// Attempted to delete the last remaining mode.
        case lastMode
        /// No mode matched the given id.
        case notFound(UUID)
    }

    private let store: JSONFileStore<[PolishingMode]>
    private var entries: [PolishingMode] = []

    /// Creates a store backed by the given file inside the Application Support directory.
    /// Production code uses the default `modes.json`; tests pass a separate name to isolate.
    init(filename: String = "modes.json") {
        self.store = JSONFileStore<[PolishingMode]>(filename: filename)
    }

    /// Removes the backing file. Used by tests to guarantee a clean slate.
    func resetFile() {
        entries = []
        try? store.delete()
    }

    /// Loads modes from disk, seeding defaults if the file is missing or corrupt.
    /// `legacyEverydayShortcut` becomes the "Everyday polish" default's shortcut.
    @discardableResult
    func load(legacyEverydayShortcut: Configuration.Shortcut = .default) -> [PolishingMode] {
        do {
            if let loaded = try store.load(), !loaded.isEmpty {
                entries = deduplicatedShortcuts(loaded)
                if entries.isEmpty {
                    entries = PolishingMode.defaults(everydayShortcut: legacyEverydayShortcut)
                    save()
                }
            } else {
                entries = PolishingMode.defaults(everydayShortcut: legacyEverydayShortcut)
                save()
            }
        } catch {
            print("[ModeStore] failed to load: \(error.localizedDescription); seeding defaults")
            entries = PolishingMode.defaults(everydayShortcut: legacyEverydayShortcut)
            save()
        }
        return entries
    }

    /// All modes, in stored order (built-ins first, then user-created).
    func allModes() -> [PolishingMode] {
        entries
    }

    /// Returns the mode bound to the given shortcut, if any.
    func mode(forShortcut shortcut: Configuration.Shortcut) -> PolishingMode? {
        entries.first { $0.shortcut == shortcut }
    }

    /// Returns the mode with the given id, if any.
    func mode(for id: UUID) -> PolishingMode? {
        entries.first { $0.id == id }
    }

    /// Adds a new mode. Throws if the name is empty or the shortcut is already used.
    @discardableResult
    func add(_ mode: PolishingMode) throws -> PolishingMode {
        guard !mode.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ModeError.emptyName
        }
        guard !entries.contains(where: { $0.shortcut == mode.shortcut }) else {
            throw ModeError.duplicateShortcut(mode.shortcut)
        }
        entries.append(mode)
        save()
        return mode
    }

    /// Updates an existing mode. Re-enforces shortcut uniqueness against the others.
    func update(id: UUID,
                name: String,
                shortcut: Configuration.Shortcut,
                instruction: String,
                outputLanguage: String?) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ModeError.emptyName }
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw ModeError.notFound(id)
        }
        let collision = entries.firstIndex { $0.shortcut == shortcut && $0.id != id }
        guard collision == nil else { throw ModeError.duplicateShortcut(shortcut) }

        var updated = entries[index]
        updated.name = trimmed
        updated.shortcut = shortcut
        updated.instruction = instruction
        updated.outputLanguage = outputLanguage
        entries[index] = updated
        save()
    }

    /// Deletes the mode with the given id. Refuses to delete the last mode.
    @discardableResult
    func delete(id: UUID) throws -> PolishingMode {
        guard entries.count > 1 else { throw ModeError.lastMode }
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            throw ModeError.notFound(id)
        }
        let removed = entries.remove(at: index)
        save()
        return removed
    }

    /// Replaces the stored modes wholesale (used after bulk edits). Enforces the
    /// minimum-one and shortcut-uniqueness invariants.
    func replaceAll(_ modes: [PolishingMode]) throws {
        guard !modes.isEmpty else { throw ModeError.lastMode }
        let shortcuts = modes.map { $0.shortcut }
        guard Set(shortcuts).count == shortcuts.count else {
            throw ModeError.duplicateShortcut(shortcuts.last ?? .default)
        }
        entries = modes
        save()
    }

    // MARK: - Private

    /// Drops any modes whose shortcut collides with an earlier mode's, keeping the
    /// first occurrence. Guards against hand-edited or stale files with duplicates.
    private func deduplicatedShortcuts(_ modes: [PolishingMode]) -> [PolishingMode] {
        var seen: Set<Configuration.Shortcut> = []
        var result: [PolishingMode] = []
        for mode in modes {
            if seen.insert(mode.shortcut).inserted {
                result.append(mode)
            }
        }
        return result
    }

    private func save() {
        do {
            try store.save(entries)
        } catch {
            print("[ModeStore] failed to save: \(error.localizedDescription)")
        }
    }
}
