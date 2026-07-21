import Foundation
import Testing
@testable import NoType

@Suite("WordCounter")
struct WordCounterTests {

    @Test func countsLatinWords() {
        #expect(WordCounter.count("hello world") == 2)
        #expect(WordCounter.count("  one   two  three  ") == 3)
    }

    @Test func countsCJKCharacters() {
        #expect(WordCounter.count("你好世界") == 4)
        #expect(WordCounter.count("こんにちは") == 5)
    }

    @Test func countsMixedContent() {
        #expect(WordCounter.count("hello 你好 world 世界") == 6)
    }

    @Test func emptyStringHasZeroWords() {
        #expect(WordCounter.count("") == 0)
    }

    @Test func countsNewlineSeparatedWords() {
        #expect(WordCounter.count("line one\nline two") == 4)
    }
}
