import Foundation
import Testing
@testable import NoType

@MainActor
@Suite("FloatingBubble")
struct FloatingBubbleTests {

    @Test func bubblePositionDefaultsToCursor() {
        #expect(Configuration.BubblePosition.cursor.rawValue == "cursor")
        #expect(Configuration.BubblePosition.menuBar.rawValue == "menuBar")
    }

    @Test func bubbleWindowCanBeCreated() {
        let bubble = FloatingBubbleWindow()
        #expect(bubble.styleMask.contains(.borderless))
    }
}
