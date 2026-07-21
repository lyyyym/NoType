import Foundation

/// Counts words in a string, treating CJK characters as individual words and
/// Latin text as whitespace-separated words.
enum WordCounter {

    /// Returns the language-aware word count for `text`.
    static func count(_ text: String) -> Int {
        var count = 0
        var inLatinWord = false

        for scalar in text.unicodeScalars {
            if isCJK(scalar) {
                if inLatinWord {
                    inLatinWord = false
                }
                count += 1
            } else if scalar.properties.isWhitespace || scalar == "\n" || scalar == "\t" {
                inLatinWord = false
            } else {
                if !inLatinWord {
                    count += 1
                    inLatinWord = true
                }
            }
        }
        return count
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        // CJK Unified Ideographs
        if (0x4E00...0x9FFF).contains(scalar.value) { return true }
        // CJK Unified Ideographs Extension A
        if (0x3400...0x4DBF).contains(scalar.value) { return true }
        // Hangul Syllables
        if (0xAC00...0xD7AF).contains(scalar.value) { return true }
        // Hiragana and Katakana
        if (0x3040...0x309F).contains(scalar.value) { return true }
        if (0x30A0...0x30FF).contains(scalar.value) { return true }
        // CJK Symbols and Punctuation
        if (0x3000...0x303F).contains(scalar.value) { return true }
        return false
    }
}
