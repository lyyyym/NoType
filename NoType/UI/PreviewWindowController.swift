import AppKit

/// Editable preview window shown after polishing when "preview before injection" is on.
///
/// Displays the processed text in an editable field. The user confirms (inject as-is
/// or after edits) or cancels (discard). Confirm triggers `onConfirm` with the final
/// text; cancel triggers `onCancel`. See spec FR-009/FR-010.
@MainActor
final class PreviewWindowController: NSWindowController {

    var onConfirm: ((String) -> Void)?
    var onCancel: (() -> Void)?

    /// The text confirmed on the last `confirm()`, or `nil` if cancelled/not yet resolved.
    private(set) var resolvedText: String?
    /// `true` once the user has confirmed or cancelled this preview session.
    private(set) var hasResolved: Bool = false

    private let textView: NSTextView

    init() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 440, height: 160))
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.font = .systemFont(ofSize: 14)
        textView.isRichText = false
        // Required for a text view hosted in a scroll view: wrap to the visible width,
        // grow vertically, and let the scroll view manage its frame.
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.minSize = NSSize(width: 0, height: 160)
        self.textView = textView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 260),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preview"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Presentation

    /// Shows the window prefilled with `text`. Resets the resolved state so the
    /// controller is reusable across recordings.
    func present(text: String, modeName: String?) {
        hasResolved = false
        resolvedText = nil
        textView.string = text
        window?.title = modeName.map { "Preview — \($0)" } ?? "Preview"
        if let window = window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.center()
            // Focus the text and select all so editing is immediate.
            window.makeFirstResponder(textView)
            textView.selectAll(nil)
        }
    }

    /// The current text in the editable field.
    var currentText: String {
        textView.string
    }

    /// Sets the editable text (used by tests and to restore edits).
    func setText(_ text: String) {
        textView.string = text
    }

    // MARK: - Actions

    /// Confirms the preview, delivering the (possibly edited) text via `onConfirm`.
    @objc func confirm() {
        guard !hasResolved else { return }
        let text = textView.string
        hasResolved = true
        resolvedText = text
        closeWindow()
        onConfirm?(text)
    }

    /// Cancels the preview, delivering nothing via `onCancel`.
    @objc func cancel() {
        guard !hasResolved else { return }
        hasResolved = true
        resolvedText = nil
        closeWindow()
        onCancel?()
    }

    private func closeWindow() {
        window?.orderOut(nil)
    }

    // MARK: - UI

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .bezelBorder
        contentView.addSubview(scrollView)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1B}" // Escape
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let confirmButton = NSButton(title: "Confirm", target: self, action: #selector(confirm))
        confirmButton.keyEquivalent = "\r" // Return
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.bezelStyle = .rounded
        if #available(macOS 10.14.2, *) {
            confirmButton.controlSize = .large
        }

        let buttonRow = NSStackView(views: [cancelButton, confirmButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -12),

            buttonRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            buttonRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
}
