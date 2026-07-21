import AppKit

/// A small floating indicator shown while recording is active.
@MainActor
final class FloatingBubbleWindow: NSPanel {

    private let indicator = NSView()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 16, height: 16),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = false
        backgroundColor = .clear
        hasShadow = false

        indicator.wantsLayer = true
        indicator.layer?.cornerRadius = 8
        indicator.layer?.backgroundColor = NSColor.systemRed.cgColor
        indicator.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(indicator)

        NSLayoutConstraint.activate([
            indicator.topAnchor.constraint(equalTo: contentView!.topAnchor),
            indicator.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            indicator.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            indicator.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor)
        ])
    }

    /// Shows the bubble near the current mouse cursor or at the menu bar.
    func show(position: Configuration.BubblePosition) {
        switch position {
        case .cursor:
            positionNearCursor()
        case .menuBar:
            positionNearMenuBar()
        }
        orderFrontRegardless()
    }

    /// Hides the bubble.
    func hide() {
        orderOut(nil)
    }

    private func positionNearCursor() {
        let mouseLocation = NSEvent.mouseLocation
        let offset: CGFloat = 24
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        var frame = self.frame
        frame.origin = CGPoint(x: mouseLocation.x + offset, y: mouseLocation.y - offset)

        // Keep inside screen bounds.
        if let screen = screen {
            let visibleFrame = screen.visibleFrame
            if frame.maxX > visibleFrame.maxX {
                frame.origin.x = mouseLocation.x - frame.width - offset
            }
            if frame.minY < visibleFrame.minY {
                frame.origin.y = mouseLocation.y + offset
            }
        }
        setFrame(frame, display: true)
    }

    private func positionNearMenuBar() {
        guard let screen = NSScreen.main else { return }
        let frame = self.frame
        let origin = CGPoint(x: screen.frame.maxX - frame.width - 16, y: screen.visibleFrame.maxY - frame.height - 8)
        setFrameOrigin(origin)
    }
}
