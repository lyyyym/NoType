import Foundation
import Testing
@testable import NoType

@Suite("KeyboardInjector")
struct KeyboardInjectorTests {

    @Test func segmentsSplitAsciiAndUnicode() {
        let segments = KeyboardInjector.segments(for: "Hello, 世界!")
        // Expect: ascii("Hello, "), unicode("世界"), ascii("!")
        #expect(segments.count == 3)
        #expect(segments[0] == .ascii("Hello, "))
        #expect(segments[1] == .unicode("世界"))
        #expect(segments[2] == .ascii("!"))
    }

    @Test func segmentsPureAscii() {
        let segments = KeyboardInjector.segments(for: "abc 123")
        #expect(segments.count == 1)
        #expect(segments.first == .ascii("abc 123"))
    }

    @Test func segmentsPureUnicode() {
        let segments = KeyboardInjector.segments(for: "你好世界")
        #expect(segments.count == 1)
        #expect(segments.first == .unicode("你好世界"))
    }

    @Test func segmentsEmpty() {
        #expect(KeyboardInjector.segments(for: "").isEmpty)
    }

    @Test func utf16ChunksSplitsLongRuns() {
        let long = String(repeating: "字", count: 50)
        let chunks = KeyboardInjector.utf16Chunks(long, max: 20)
        #expect(chunks.count == 3)
        #expect(chunks[0].utf16.count == 20)
        #expect(chunks[1].utf16.count == 20)
        #expect(chunks[2].utf16.count == 10)
        #expect(chunks.joined() == long)
    }

    @Test func utf16ChunksShortString() {
        #expect(KeyboardInjector.utf16Chunks("短", max: 20) == ["短"])
    }
}
