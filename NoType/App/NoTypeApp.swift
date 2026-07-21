import AppKit

/// Entry point for the NoType menu-bar application.
@main
struct NoTypeApp {

    static func main() {
        let app = NSApplication.shared
        // Menu-bar-only app: do not appear in the Dock (equivalent to LSUIElement).
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
