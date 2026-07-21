import Foundation
import Testing
@testable import NoType

@Suite("RecordingSession")
struct RecordingSessionTests {

    @Test func happyPathTransitions() {
        let session = RecordingSession()
        #expect(session.transition(to: .recording))
        #expect(session.transition(to: .processing))
        #expect(session.stoppedAt != nil)
        #expect(session.transition(to: .inserted))
        #expect(session.status == .inserted)
    }

    @Test func fallbackTransitionsToInsertedRaw() {
        let session = RecordingSession()
        #expect(session.transition(to: .recording))
        #expect(session.transition(to: .processing))
        #expect(session.transition(to: .insertedRaw))
    }

    @Test func processingCanFail() {
        let session = RecordingSession()
        #expect(session.transition(to: .recording))
        #expect(session.transition(to: .processing))
        session.setError("microphone unavailable")
        #expect(session.transition(to: .failed))
        #expect(session.errorDescription != nil)
    }

    @Test func illegalTransitionIsRejected() {
        let session = RecordingSession()
        // Cannot skip straight from idle to processing.
        #expect(!session.transition(to: .processing))
        // Cannot go from recording straight to inserted.
        #expect(session.transition(to: .recording))
        #expect(!session.transition(to: .inserted))
    }
}
