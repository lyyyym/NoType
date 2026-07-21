import Foundation

/// Generic JSON file persistence for a single `Codable` value.
///
/// Loads from and saves to a named file inside the Application Support directory.
/// Corrupt or missing files are treated as `nil` on load.
final class JSONFileStore<T: Codable> {

    private let filename: String

    init(filename: String) {
        self.filename = filename
    }

    /// Loads the value from disk. Returns `nil` if the file is missing or corrupt.
    func load() throws -> T? {
        let url = try fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Saves the value to disk, overwriting any existing file.
    func save(_ value: T) throws {
        let url = try fileURL()
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: [.atomic])
    }

    /// Deletes the persisted file.
    func delete() throws {
        let url = try fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func fileURL() throws -> URL {
        try PersistenceDirectory.url().appendingPathComponent(filename, isDirectory: false)
    }
}
