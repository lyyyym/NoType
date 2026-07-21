import Foundation

/// Domain representation of the contents of `~/.config/notype/config.toml`.
///
/// See `contracts/config-toml.md` for the on-disk schema.
struct Configuration {
    struct Shortcut: Codable {
        /// Single character or named key, e.g. `"."` or `"f12"`.
        var key: String
        /// Modifier names, each one of `command`, `option`, `control`, `shift`.
        var modifiers: [String]

        static let `default` = Shortcut(key: ".", modifiers: ["command"])
    }

    struct ServiceConfig: Codable {
        var baseURL: String
        var apiKey: String
        var model: String
    }

    struct LLMConfig: Codable {
        var baseURL: String
        var apiKey: String
        var model: String
        var temperature: Double
        var maxTokens: Int

        static let defaultTemperature: Double = 0.0
        static let defaultMaxTokens: Int = 4096
    }

    /// Where the floating recording bubble should appear.
    enum BubblePosition: String, Codable {
        case cursor
        case menuBar
    }

    var shortcut: Shortcut
    var asr: ServiceConfig
    var llm: LLMConfig
    var showFloatingBubble: Bool
    var bubblePosition: BubblePosition
    /// When true, an editable preview window is shown after polishing and before
    /// injection. Defaults to false (instant injection, V2 behavior).
    var showPreviewBeforeInjection: Bool

    init(shortcut: Shortcut = .default,
         asr: ServiceConfig,
         llm: LLMConfig,
         showFloatingBubble: Bool = true,
         bubblePosition: BubblePosition = .cursor,
         showPreviewBeforeInjection: Bool = false) {
        self.shortcut = shortcut
        self.asr = asr
        self.llm = llm
        self.showFloatingBubble = showFloatingBubble
        self.bubblePosition = bubblePosition
        self.showPreviewBeforeInjection = showPreviewBeforeInjection
    }
}

extension Configuration {
    /// Allowed modifier names (lowercased).
    static let allowedModifiers: Set<String> = ["command", "option", "control", "shift"]
}
