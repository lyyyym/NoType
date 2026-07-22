import AppKit

/// Shared building blocks for the settings UI: a theme-aware grouped card and a
/// labeled two-column form row.

/// A rounded, bordered, filled container used to group a settings section. Its
/// background and border are reapplied in `updateLayer` so they follow light/dark
/// appearance changes.
@MainActor
final class CardView: NSView {

    override var wantsUpdateLayer: Bool { true }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateLayer() {
        super.updateLayer()
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
        layer?.setNeedsDisplay()
    }
}

@MainActor
enum SettingsUI {

    /// Builds a titled card wrapping `content` with consistent padding. The returned
    /// view self-sizes to fit its content; pin its width to a parent for layout.
    static func card(title: String, content: NSView) -> NSView {
        let card = CardView()
        card.translatesAutoresizingMaskIntoConstraints = false

        let header = NSTextField(labelWithString: title)
        header.font = .systemFont(ofSize: 13, weight: .semibold)
        header.translatesAutoresizingMaskIntoConstraints = false

        content.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(header)
        card.addSubview(content)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            content.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }

    /// A horizontal row: a fixed-width, right-aligned label followed by an expanding
    /// field. The returned view self-sizes (height driven by the field).
    static func row(label text: String, field: NSView, labelWidth: CGFloat = 120, spacing: CGFloat = 10) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        label.lineBreakMode = .byTruncatingTail
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false

        field.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(field)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.widthAnchor.constraint(equalToConstant: labelWidth),
            label.centerYAnchor.constraint(equalTo: field.centerYAnchor),

            field.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: spacing),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            field.topAnchor.constraint(equalTo: container.topAnchor, constant: 3),
            field.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -3)
        ])
        return container
    }

    /// A vertical stack of rows with consistent spacing; arranged views are stretched
    /// to the stack's width so labels align in a tidy column.
    static func rowsStack(_ rows: [NSView], spacing: CGFloat = 10) -> NSStackView {
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        for row in rows {
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }
}
