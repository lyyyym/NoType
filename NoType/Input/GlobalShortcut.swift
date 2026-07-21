import AppKit
import Carbon.HIToolbox

/// Monitors global key events to implement press-and-hold recording.
///
/// Uses `NSEvent.addGlobalMonitorForEvents` so it observes the configured
/// shortcut even when another application is frontmost. See `research.md` §2.
final class GlobalShortcut {

    /// Called when the configured shortcut is pressed (key goes down).
    var onPress: (() -> Void)?
    /// Called when the configured shortcut is released (key goes up).
    var onRelease: (() -> Void)?

    private var monitor: Any?
    private let configuration: Configuration.Shortcut
    private var isDown = false
    private var activeKeyCode: UInt16?

    init(configuration: Configuration.Shortcut) {
        self.configuration = configuration
    }

    deinit {
        stop()
    }

    /// Begins monitoring. Must be called on the main thread.
    /// Returns `false` if Accessibility permission is missing (required on macOS for global key monitoring).
    @discardableResult
    func start() -> Bool {
        assert(Thread.isMainThread, "GlobalShortcut.start must run on the main thread")
        guard KeyboardInjector.isTrusted(prompt: false) else {
            print("[GlobalShortcut] Accessibility permission not granted; cannot monitor global keys")
            return false
        }
        guard monitor == nil else { return true }

        let mask: NSEvent.EventTypeMask = [.keyDown, .keyUp]
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event: event)
        }
        print("[GlobalShortcut] started monitoring for \(configuration.modifiers)+\(configuration.key)")
        return true
    }

    /// Stops monitoring.
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isDown = false
        activeKeyCode = nil
    }

    // MARK: - Matching

    private func handle(event: NSEvent) {
        if event.type == .keyDown {
            handleKeyDown(event)
        } else if event.type == .keyUp {
            handleKeyUp(event)
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard !isDown else { return }
        guard modifiersMatch(event.modifierFlags) else { return }
        guard let code = keyCodeForEvent(event), codeMatchesConfiguration(code) else { return }

        isDown = true
        activeKeyCode = code
        print("[GlobalShortcut] pressed \(configuration.modifiers)+\(configuration.key)")
        onPress?()
    }

    private func handleKeyUp(_ event: NSEvent) {
        guard isDown else { return }
        // Release is detected when the same physical key goes up, regardless of
        // whether the modifier is still held. This handles users who release
        // Command before releasing the trigger key.
        if let active = activeKeyCode, event.keyCode == active {
            isDown = false
            activeKeyCode = nil
            print("[GlobalShortcut] released")
            onRelease?()
        }
    }

    /// Returns the hardware key code for a matching event, if any.
    private func keyCodeForEvent(_ event: NSEvent) -> UInt16? {
        // Named-key configurations always map to a key code.
        if configuration.key.count != 1, let code = GlobalShortcut.keyCode(forNamed: configuration.key.lowercased()) {
            return code
        }
        // Single-character configurations: use the event's own key code if the
        // character matches, falling back to a hard-coded mapping for common keys.
        if configuration.key == "." {
            if event.charactersIgnoringModifiers == "." {
                return event.keyCode
            }
            return UInt16(kVK_ANSI_Period)
        }
        if event.charactersIgnoringModifiers == configuration.key {
            return event.keyCode
        }
        return nil
    }

    private func codeMatchesConfiguration(_ code: UInt16) -> Bool {
        if configuration.key.count != 1 {
            return GlobalShortcut.keyCode(forNamed: configuration.key.lowercased()) == code
        }
        if configuration.key == "." {
            return code == UInt16(kVK_ANSI_Period) || eventCharacterIsPeriod
        }
        return true
    }

    private var eventCharacterIsPeriod: Bool {
        // This property is never used standalone; retained for symmetry.
        return false
    }

    private func modifiersMatch(_ flags: NSEvent.ModifierFlags) -> Bool {
        let required = GlobalShortcut.modifierFlags(for: configuration.modifiers)
        let active = flags.intersection(.deviceIndependentFlagsMask)
        return active == required
    }

    /// Maps modifier names to `NSEvent.ModifierFlags`.
    static func modifierFlags(for names: [String]) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        for name in names {
            switch name.lowercased() {
            case "command", "cmd", "super": flags.insert(.command)
            case "option", "alt": flags.insert(.option)
            case "control", "ctrl": flags.insert(.control)
            case "shift": flags.insert(.shift)
            default: break
            }
        }
        return flags
    }

    /// Maps a small set of named keys to hardware key codes.
    static func keyCode(forNamed name: String) -> UInt16? {
        switch name {
        case "period", ".": return UInt16(kVK_ANSI_Period)
        case "space": return UInt16(kVK_Space)
        case "f1": return UInt16(kVK_F1)
        case "f2": return UInt16(kVK_F2)
        case "f3": return UInt16(kVK_F3)
        case "f4": return UInt16(kVK_F4)
        case "f5": return UInt16(kVK_F5)
        case "f6": return UInt16(kVK_F6)
        case "f7": return UInt16(kVK_F7)
        case "f8": return UInt16(kVK_F8)
        case "f9": return UInt16(kVK_F9)
        case "f10": return UInt16(kVK_F10)
        case "f11": return UInt16(kVK_F11)
        case "f12": return UInt16(kVK_F12)
        case "return", "enter": return UInt16(kVK_Return)
        case "tab": return UInt16(kVK_Tab)
        case "escape", "esc": return UInt16(kVK_Escape)
        default: return nil
        }
    }
}
