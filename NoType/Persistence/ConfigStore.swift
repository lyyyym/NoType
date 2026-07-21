import Foundation

/// Reads and writes the user's TOML configuration file.
///
/// Uses `ConfigLoader` for parsing and provides a symmetric `save` method
/// so the settings window can persist changes back to disk.
enum ConfigStore {

    /// Loads configuration from the default TOML path.
    static func load() throws -> Configuration {
        let path = try ConfigLoader.defaultPath()
        return try ConfigLoader.load(from: path)
    }

    /// Writes `configuration` to the default TOML path, creating parent directories if needed.
    static func save(_ configuration: Configuration) throws {
        let path = try ConfigLoader.defaultPath()
        let dir = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let text = serialize(configuration)
        guard let data = text.data(using: .utf8) else {
            throw ConfigError.unreadable("could not encode config as UTF-8")
        }
        try data.write(to: path, options: [.atomic])
    }

    /// Serializes a configuration into TOML text matching the V1 schema.
    static func serialize(_ config: Configuration) -> String {
        var lines: [String] = []
        lines.append("[shortcut]")
        lines.append("key = \"\(config.shortcut.key)\"")
        lines.append("modifiers = \(serializeArray(config.shortcut.modifiers))")
        lines.append("")
        lines.append("[asr]")
        lines.append("base_url = \"\(config.asr.baseURL)\"")
        lines.append("api_key = \"\(config.asr.apiKey)\"")
        lines.append("model = \"\(config.asr.model)\"")
        lines.append("")
        lines.append("[llm]")
        lines.append("base_url = \"\(config.llm.baseURL)\"")
        lines.append("api_key = \"\(config.llm.apiKey)\"")
        lines.append("model = \"\(config.llm.model)\"")
        lines.append("temperature = \(config.llm.temperature)")
        lines.append("max_tokens = \(config.llm.maxTokens)")
        lines.append("")
        lines.append("[ui]")
        lines.append("show_floating_bubble = \(config.showFloatingBubble)")
        lines.append("bubble_position = \"\(config.bubblePosition.rawValue)\"")
        lines.append("show_preview_before_injection = \(config.showPreviewBeforeInjection)")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func serializeArray(_ values: [String]) -> String {
        let quoted = values.map { "\"\($0)\"" }
        return "[" + quoted.joined(separator: ", ") + "]"
    }
}
