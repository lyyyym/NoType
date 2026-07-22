import AppKit
import CoreGraphics

/// Injects text into the frontmost application via simulated keyboard events.
///
/// See `contracts/keyboard-injection.md`. ASCII characters are typed as
/// virtual key events; non-ASCII characters (e.g. Chinese) are injected as a
/// Unicode string via `CGEvent.keyboardSetUnicodeString`.
class KeyboardInjector {

    enum Segment: Equatable {
        /// A run of ASCII characters, typed via key events.
        case ascii(String)
        /// A run of non-ASCII characters, injected as a Unicode string.
        case unicode(String)
    }

    /// Splits text into maximal ASCII and non-ASCII runs. Pure function; tested
    /// in `KeyboardInjectorTests`.
    static func segments(for text: String) -> [Segment] {
        var segments: [Segment] = []
        var asciiBuffer = ""
        var unicodeBuffer = ""

        func flushASCII() {
            if !asciiBuffer.isEmpty {
                segments.append(.ascii(asciiBuffer))
                asciiBuffer.removeAll(keepingCapacity: true)
            }
        }
        func flushUnicode() {
            if !unicodeBuffer.isEmpty {
                segments.append(.unicode(unicodeBuffer))
                unicodeBuffer.removeAll(keepingCapacity: true)
            }
        }

        for char in text {
            // ASCII printable range (space .. tilde).
            if char.isASCII, let scalar = char.asciiValue, scalar >= 0x20, scalar <= 0x7E {
                flushUnicode()
                asciiBuffer.append(char)
            } else {
                flushASCII()
                unicodeBuffer.append(char)
            }
        }
        flushASCII()
        flushUnicode()
        return segments
    }

    /// Returns `true` if the process is trusted for Accessibility, optionally
    /// prompting the user to grant permission.
    static func isTrusted(prompt: Bool) -> Bool {
        let options: CFDictionary? = prompt
            ? [kAXTrustedCheckOptionPrompt.takeRetainedValue(): kCFBooleanTrue] as CFDictionary
            : nil
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Splits a string into chunks of at most `max` UTF-16 code units each.
    static func utf16Chunks(_ string: String, max: Int) -> [String] {
        let units = Array(string.utf16)
        guard units.count > max else { return [string] }
        var chunks: [String] = []
        var index = units.startIndex
        while index < units.endIndex {
            let end = min(index + max, units.endIndex)
            let slice = units[index..<end]
            let s = String(utf16CodeUnits: Array(slice), count: slice.count)
            chunks.append(s)
            index = end
        }
        return chunks
    }

    /// Injects `text` into the frontmost application.
    /// Must be called on the main thread.
    /// - Throws: `InjectionError` if Accessibility permission is missing or posting fails.
    ///
    /// Both ASCII and non-ASCII characters are injected as a Unicode string via
    /// `keyboardSetUnicodeString`, which types the literal character regardless of the
    /// active keyboard layout and held modifiers. (The previous ASCII path posted each
    /// character's ASCII value as the CGEvent `virtualKey`, which is a hardware keycode —
    /// not ASCII — and produced garbled output for Latin text.)
    func inject(text: String) throws {
        assert(Thread.isMainThread, "KeyboardInjector.inject must run on the main thread")
        guard Self.isTrusted(prompt: false) else {
            throw InjectionError.accessibilityDenied
        }
        let source = CGEventSource(stateID: .hidSystemState)
        for segment in Self.segments(for: text) {
            let run: String
            switch segment {
            case .ascii(let value): run = value
            case .unicode(let value): run = value
            }
            // `keyboardSetUnicodeString` historically accepts at most ~20 UTF-16
            // units per event; chunk long runs (e.g. CJK paragraphs) to be safe.
            for chunk in Self.utf16Chunks(run, max: 20) {
                var codes = Array(chunk.utf16)
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
                keyDown?.keyboardSetUnicodeString(stringLength: codes.count, unicodeString: &codes)
                keyDown?.post(tap: .cghidEventTap)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
                keyUp?.post(tap: .cghidEventTap)
            }
        }
    }
}
