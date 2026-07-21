import Foundation
import Testing
@testable import NoType

@Suite("PolishPrompt")
struct PolishPromptTests {

    @Test func messagesContainSystemAndUser() {
        let messages = PolishPrompt.messages(for: "hello")
        #expect(messages.count == 2)
        #expect(messages[0]["role"] == "system")
        #expect(messages[0]["content"] == PolishPrompt.systemPrompt)
        #expect(messages[1]["role"] == "user")
        #expect(messages[1]["content"] == "hello")
    }

    @Test func normalizeTrimsWhitespace() {
        #expect(PolishPrompt.normalize("  hello world  ") == "hello world")
        #expect(PolishPrompt.normalize("\nhi\n") == "hi")
    }

    @Test func normalizeStripsSurroundingQuotes() {
        #expect(PolishPrompt.normalize(#""hello world""#) == "hello world")
    }

    @Test func normalizePreservesCJK() {
        #expect(PolishPrompt.normalize(" 你好，世界 ") == "你好，世界")
    }

    @Test func messagesIncludeDictionaryHint() {
        let hint = "Preferred terms:\n- \"SwiftUI\""
        let messages = PolishPrompt.messages(for: "hello", dictionaryHint: hint)
        #expect(messages.count == 2)
        #expect(messages[0]["content"]?.contains("SwiftUI") == true)
    }
}
