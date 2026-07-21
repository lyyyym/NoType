import Foundation

/// Resolves and creates the macOS Application Support directory for NoType.
enum PersistenceDirectory {

    /// Returns `~/Library/Application Support/NoType/`, creating it if needed.
    static func url() throws -> URL {
        let fileManager = FileManager.default
        guard let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw PersistenceError.cannotLocateApplicationSupport
        }
        let appDir = supportDir.appendingPathComponent("NoType", isDirectory: true)
        try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        return appDir
    }
}

enum PersistenceError: Error, LocalizedError {
    case cannotLocateApplicationSupport

    var errorDescription: String? {
        switch self {
        case .cannotLocateApplicationSupport:
            return "Could not locate the Application Support directory"
        }
    }
}
