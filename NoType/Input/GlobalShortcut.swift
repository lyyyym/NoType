import AppKit
import Carbon.HIToolbox

/// Monitors global key events to implement press-and-hold recording for one or more
/// polishing modes.
///
/// Uses `NSEvent.addGlobalMonitorForEvents` so it observes the configured shortcuts
/// even when another application is frontmost. A single monitor matches every
/// binding; the matched mode id is reported via `onPress` / `onRelease`. See
/// `specs/003-modes-and-preview/contracts/polish-modes.md` §3.
final class GlobalShortcut {

    /// A (mode id → shortcut) binding registered for monitoring.
    struct Binding: Equatable {
        let modeID: UUID
        let shortcut: Configuration.Shortcut
    }

    /// Called with the matched mode id when a binding's shortcut is pressed (key down).
    var onPress: ((UUID) -> Void)?
    /// Called with the matched mode id when the held key is released (key up).
    var onRelease: ((UUID) -> Void)?

    private var monitor: Any?
    private var bindings: [Binding]
    /// The currently held (mode id, physical key code), if any.
    private var active: (modeID: UUID, keyCode: UInt16)?

    init(bindings: [Binding]) {
        self.bindings = Self.deduplicated(bindings)
    }

    deinit {
        stop()
    }

    /// Replaces the active bindings and restarts the monitor. Used after settings
    /// changes so added/edited/deleted modes take effect immediately.
    func update(_ bindings: [Binding]) {
        stop()
        self.bindings = Self.deduplicated(bindings)
        _ = start()
    }

    /// All currently registered bindings.
    func currentBindings() -> [Binding] {
        bindings
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
        guard !bindings.isEmpty else {
            print("[GlobalShortcut] no bindings to monitor")
            return true
        }

        let mask: NSEvent.EventTypeMask = [.keyDown, .keyUp]
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event: event)
        }
        print("[GlobalShortcut] started monitoring \(bindings.count) mode shortcut(s)")
        return true
    }

    /// Stops monitoring.
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        active = nil
    }

    // MARK: - Event handling

    private func handle(event: NSEvent) {
        if event.type == .keyDown {
            handleKeyDown(event)
        } else if event.type == .keyUp {
            handleKeyUp(event)
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard active == nil else { return }
        guard let binding = Self.match(bindings: bindings,
                                       eventModifiers: event.modifierFlags,
                                       characters: event.charactersIgnoringModifiers,
                                       keyCode: event.keyCode) else { return }
        active = (binding.modeID, event.keyCode)
        print("[GlobalShortcut] pressed mode \(binding.modeID)")
        onPress?(binding.modeID)
    }

    private func handleKeyUp(_ event: NSEvent) {
        guard let active = active else { return }
        // Release is detected when the same physical key goes up, regardless of
        // whether the modifier is still held. This handles users who release
        // Command before releasing the trigger key.
        if event.keyCode == active.keyCode {
            let modeID = active.modeID
            self.active = nil
            print("[GlobalShortcut] released mode \(modeID)")
            onRelease?(modeID)
        }
    }

    // MARK: - Matching (pure, testable without NSEvent)

    /// Returns the first binding whose shortcut matches the given event signals, or nil.
    static func match(bindings: [Binding],
                      eventModifiers: NSEvent.ModifierFlags,
                      characters: String?,
                      keyCode: UInt16) -> Binding? {
        for binding in bindings {
            if shortcutMatches(binding.shortcut,
                               eventModifiers: eventModifiers,
                               characters: characters,
                               keyCode: keyCode) {
                return binding
            }
        }
        return nil
    }

    /// `true` when a shortcut matches the event's modifier flags and key.
    static func shortcutMatches(_ shortcut: Configuration.Shortcut,
                                eventModifiers: NSEvent.ModifierFlags,
                                characters: String?,
                                keyCode: UInt16) -> Bool {
        guard modifiersMatch(eventModifiers, shortcut.modifiers) else { return false }
        return keyMatches(shortcut.key, characters: characters, keyCode: keyCode)
    }

    /// `true` when the active modifier flags exactly equal the required set.
    static func modifiersMatch(_ flags: NSEvent.ModifierFlags, _ modifiers: [String]) -> Bool {
        let required = modifierFlags(for: modifiers)
        let activeFlags = flags.intersection(.deviceIndependentFlagsMask)
        return activeFlags == required
    }

    /// `true` when the configured key matches the event's character or key code.
    static func keyMatches(_ key: String, characters: String?, keyCode: UInt16) -> Bool {
        // Named keys (length != 1) map to a hardware key code.
        if key.count != 1 {
            return Self.keyCode(forNamed: key.lowercased()) == keyCode
        }
        // The period is matched by key code OR by character (layout-independent).
        if key == "." {
            return keyCode == UInt16(kVK_ANSI_Period) || characters == "."
        }
        // Other single-character keys match by produced character.
        return characters == key
    }

    /// Drops bindings whose shortcut duplicates an earlier binding's, keeping the first.
    private static func deduplicated(_ bindings: [Binding]) -> [Binding] {
        var seen: Set<Configuration.Shortcut> = []
        var result: [Binding] = []
        for binding in bindings {
            if seen.insert(binding.shortcut).inserted {
                result.append(binding)
            } else {
                print("[GlobalShortcut] ignoring duplicate shortcut binding for mode \(binding.modeID)")
            }
        }
        return result
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
