import AppKit

/// Snapshot of the frontmost application, used to restore focus after the preview
/// window takes keyboard focus. Captured at recording start so the text lands where
/// the user was originally typing (spec FR-017).
struct FrontmostApp {

    let processIdentifier: pid_t
    let bundleIdentifier: String?

    /// Captures the currently frontmost application, if any.
    static var current: FrontmostApp? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return FrontmostApp(processIdentifier: app.processIdentifier,
                            bundleIdentifier: app.bundleIdentifier)
    }

    /// `true` if a process with the captured pid is still running.
    var isRunning: Bool {
        guard let running = NSRunningApplication(processIdentifier: processIdentifier) else {
            return false
        }
        return !running.isTerminated
    }

    /// Brings the captured application back to the foreground. Returns `true` if the
    /// app is still running (or was found by bundle id) and activation was requested.
    /// Performs a best-effort wait for it to actually become frontmost.
    @discardableResult
    func reactivate() -> Bool {
        guard let target = resolveRunningApplication() else {
            print("[FrontmostApp] target app no longer running")
            return false
        }
        target.activate(options: .activateAllWindows)
        waitForFrontmost(target: target)
        return true
    }

    /// Resolves the live `NSRunningApplication` by pid, falling back to bundle id.
    private func resolveRunningApplication() -> NSRunningApplication? {
        if let running = NSRunningApplication(processIdentifier: processIdentifier), !running.isTerminated {
            return running
        }
        if let bundleIdentifier = bundleIdentifier {
            return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        }
        return nil
    }

    /// Polls briefly (up to ~300ms) until the target is frontmost, so the subsequent
    /// keyboard injection lands in the right app.
    private func waitForFrontmost(target: NSRunningApplication) {
        let deadline = Date().addingTimeInterval(0.3)
        while Date() < deadline {
            if let front = NSWorkspace.shared.frontmostApplication,
               front.processIdentifier == target.processIdentifier {
                return
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        // Timed out waiting; proceed regardless (injection still attempts the current app).
    }
}
