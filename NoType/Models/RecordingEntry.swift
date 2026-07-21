import Foundation

/// A single successful voice input, stored in local history.
struct RecordingEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let rawText: String
    let polishedText: String
    let wordCount: Int

    init(id: UUID = UUID(), timestamp: Date = Date(), rawText: String, polishedText: String, wordCount: Int? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.rawText = rawText
        self.polishedText = polishedText
        self.wordCount = wordCount ?? WordCounter.count(polishedText)
    }
}
