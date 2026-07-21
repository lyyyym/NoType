import Foundation

/// Loads and validates `~/.config/notype/config.toml` into a `Configuration`.
///
/// NOTE (T002 adaptation): The plan called for the `TOMLKit` package. To keep the
/// build self-contained (no network dependency) and because the config schema is
/// small and fixed (see `contracts/config-toml.md`), a focused TOML reader is
/// implemented here. It supports the subset our schema uses: section headers,
/// string / integer / double values, and string arrays. It can be swapped for
/// `TOMLKit` later without touching `Configuration`.
enum ConfigLoader {

    /// Resolves the canonical config path: `~/.config/notype/config.toml`.
    static func defaultPath() throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("notype", isDirectory: true)
            .appendingPathComponent("config.toml", isDirectory: false)
    }

    /// Loads configuration from the given file URL.
    /// - Throws: `ConfigError` if the file is missing, unreadable, or invalid.
    static func load(from url: URL) throws -> Configuration {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ConfigError.fileNotFound(url.path)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ConfigError.unreadable(error.localizedDescription)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw ConfigError.unreadable("config file is not valid UTF-8")
        }
        return try parse(text, sourcePath: url.path)
    }

    /// Parses raw TOML text into a validated `Configuration`.
    static func parse(_ text: String, sourcePath: String = "<inline>") throws -> Configuration {
        var sections: [String: [String: String]] = [:]
        var current = ""
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            // Skip blank lines and comments.
            if line.isEmpty || line.hasPrefix("#") { continue }
            if let section = Self.sectionHeader(line) {
                current = section
                if sections[current] == nil { sections[current] = [:] }
                continue
            }
            guard let (key, value) = Self.keyValue(line) else {
                throw ConfigError.invalidSyntax("could not parse line: \(line)")
            }
            sections[current, default: [:]][key] = value
        }
        return try build(from: sections, sourcePath: sourcePath)
    }
}

// MARK: - Parsing helpers

extension ConfigLoader {

    static func sectionHeader(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else { return nil }
        let inner = String(trimmed.dropFirst().dropLast())
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        return inner
    }

    static func keyValue(_ line: String) -> (String, String)? {
        guard let eq = line.firstIndex(of: "=") else { return nil }
        let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces).lowercased()
        let value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !value.isEmpty else { return nil }
        return (key, value)
    }

    static func build(from sections: [String: [String: String]], sourcePath: String) throws -> Configuration {
        let shortcut = try buildShortcut(sections["shortcut"])
        let asr = try buildService(section: sections["asr"], name: "asr")
        let llm = try buildLLM(sections["llm"])
        let ui = try buildUI(sections["ui"])
        return Configuration(
            shortcut: shortcut,
            asr: asr,
            llm: llm,
            showFloatingBubble: ui.showFloatingBubble,
            bubblePosition: ui.bubblePosition,
            showPreviewBeforeInjection: ui.showPreviewBeforeInjection
        )
    }

    static func buildUI(_ fields: [String: String]?) throws -> (showFloatingBubble: Bool, bubblePosition: Configuration.BubblePosition, showPreviewBeforeInjection: Bool) {
        let fields = fields ?? [:]
        let showFloatingBubble: Bool
        if let raw = fields["show_floating_bubble"] {
            let value = unwrapString(raw).lowercased()
            showFloatingBubble = (value == "true")
        } else {
            showFloatingBubble = true
        }
        let bubblePosition: Configuration.BubblePosition
        if let raw = fields["bubble_position"] {
            let value = unwrapString(raw)
            bubblePosition = Configuration.BubblePosition(rawValue: value) ?? .cursor
        } else {
            bubblePosition = .cursor
        }
        let showPreviewBeforeInjection: Bool
        if let raw = fields["show_preview_before_injection"] {
            showPreviewBeforeInjection = (unwrapString(raw).lowercased() == "true")
        } else {
            showPreviewBeforeInjection = false
        }
        return (showFloatingBubble, bubblePosition, showPreviewBeforeInjection)
    }

    static func buildShortcut(_ fields: [String: String]?) throws -> Configuration.Shortcut {
        let fields = fields ?? [:]
        let key = Self.unwrapString(fields["key"] ?? ".")
        guard !key.isEmpty else { throw ConfigError.invalidValue("shortcut.key must not be empty") }

        let modifiers: [String]
        if let raw = fields["modifiers"] {
            modifiers = try Self.unwrapStringArray(raw)
        } else {
            modifiers = Configuration.Shortcut.default.modifiers
        }
        let lowered = modifiers.map { $0.lowercased() }
        for mod in lowered {
            guard Configuration.allowedModifiers.contains(mod) else {
                throw ConfigError.invalidValue("unknown modifier: \(mod)")
            }
        }
        guard !lowered.isEmpty else {
            throw ConfigError.invalidValue("shortcut.modifiers must list at least one modifier")
        }
        return .init(key: key, modifiers: lowered)
    }

    static func buildService(section: [String: String]?, name: String) throws -> Configuration.ServiceConfig {
        guard let fields = section else {
            throw ConfigError.missingSection("missing [\(name)] section")
        }
        let baseURL = Self.unwrapString(fields["base_url"] ?? "")
        let apiKey = Self.unwrapString(fields["api_key"] ?? "")
        let model = Self.unwrapString(fields["model"] ?? "")
        guard !baseURL.isEmpty else { throw ConfigError.invalidValue("\(name).base_url must not be empty") }
        guard baseURL.hasPrefix("https://") || baseURL.hasPrefix("http://") else {
            throw ConfigError.invalidValue("\(name).base_url must be a valid URL")
        }
        guard !apiKey.isEmpty else { throw ConfigError.invalidValue("\(name).api_key must not be empty") }
        guard !model.isEmpty else { throw ConfigError.invalidValue("\(name).model must not be empty") }
        return .init(baseURL: baseURL, apiKey: apiKey, model: model)
    }

    static func buildLLM(_ fields: [String: String]?) throws -> Configuration.LLMConfig {
        guard let fields = fields else {
            throw ConfigError.missingSection("missing [llm] section")
        }
        let baseURL = Self.unwrapString(fields["base_url"] ?? "")
        let apiKey = Self.unwrapString(fields["api_key"] ?? "")
        let model = Self.unwrapString(fields["model"] ?? "")
        guard !baseURL.isEmpty else { throw ConfigError.invalidValue("llm.base_url must not be empty") }
        guard baseURL.hasPrefix("https://") || baseURL.hasPrefix("http://") else {
            throw ConfigError.invalidValue("llm.base_url must be a valid URL")
        }
        guard !apiKey.isEmpty else { throw ConfigError.invalidValue("llm.api_key must not be empty") }
        guard !model.isEmpty else { throw ConfigError.invalidValue("llm.model must not be empty") }

        let temperature: Double
        if let raw = fields["temperature"] {
            guard let parsed = Double(Self.unwrapString(raw)) else {
                throw ConfigError.invalidValue("llm.temperature must be a number")
            }
            guard (0.0...2.0).contains(parsed) else {
                throw ConfigError.invalidValue("llm.temperature must be between 0.0 and 2.0")
            }
            temperature = parsed
        } else {
            temperature = Configuration.LLMConfig.defaultTemperature
        }

        let maxTokens: Int
        if let raw = fields["max_tokens"] {
            guard let parsed = Int(Self.unwrapString(raw)), parsed > 0 else {
                throw ConfigError.invalidValue("llm.max_tokens must be a positive integer")
            }
            maxTokens = parsed
        } else {
            maxTokens = Configuration.LLMConfig.defaultMaxTokens
        }

        return .init(baseURL: baseURL, apiKey: apiKey, model: model, temperature: temperature, maxTokens: maxTokens)
    }

    // MARK: Value coercion

    /// Returns the contents of a double-quoted string, or the input if unquoted.
    static func unwrapString(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.count >= 2 && s.hasPrefix("\"") && s.hasSuffix("\"") {
            s = String(s.dropFirst().dropLast())
        }
        return s
    }

    /// Parses `["a", "b"]` into `["a", "b"]`.
    static func unwrapStringArray(_ raw: String) throws -> [String] {
        var s = raw.trimmingCharacters(in: .whitespaces)
        guard s.hasPrefix("[") && s.hasSuffix("]") else {
            throw ConfigError.invalidValue("expected an array, got: \(raw)")
        }
        s = String(s.dropFirst().dropLast())
        if s.trimmingCharacters(in: .whitespaces).isEmpty { return [] }
        let parts = s.split(separator: ",")
        return parts.map { unwrapString(String($0)) }
    }
}
