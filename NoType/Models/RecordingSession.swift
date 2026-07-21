import Foundation

/// States for one press-hold-release dictation cycle. See `data-model.md`.
enum RecordingStatus: String {
    case idle
    case recording
    case processing
    case inserted
    case insertedRaw
    case failed
}

/// Represents one dictation session. Pure state-machine logic; no I/O.
final class RecordingSession {

    let id: UUID
    let startedAt: Date
    private(set) var stoppedAt: Date?
    private(set) var status: RecordingStatus
    private(set) var rawTranscription: String?
    private(set) var polishedText: String?
    private(set) var errorDescription: String?

    init(id: UUID = UUID(), startedAt: Date = Date(), status: RecordingStatus = .idle) {
        self.id = id
        self.startedAt = startedAt
        self.status = status
    }

    @discardableResult
    func transition(to next: RecordingStatus) -> Bool {
        guard RecordingSession.canTransition(from: status, to: next) else { return false }
        if next == .processing, stoppedAt == nil { stoppedAt = Date() }
        status = next
        return true
    }

    func setRawTranscription(_ text: String) {
        rawTranscription = text
    }

    func setPolishedText(_ text: String) {
        polishedText = text
    }

    func setError(_ description: String) {
        errorDescription = description
    }

    /// Allowed transitions per the state machine in `data-model.md`.
    static func canTransition(from current: RecordingStatus, to next: RecordingStatus) -> Bool {
        switch (current, next) {
        case (.idle, .recording): return true
        case (.recording, .processing): return true
        case (.processing, .inserted): return true
        case (.processing, .insertedRaw): return true
        case (.processing, .failed): return true
        default: return false
        }
    }
}
