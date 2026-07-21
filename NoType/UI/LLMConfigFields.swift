import AppKit

/// Reusable form for editing the LLM service configuration.
@MainActor
final class LLMConfigFields {
    let baseURLField = NSTextField(string: "")
    let apiKeyField = NSTextField(string: "")
    let modelField = NSTextField(string: "")
    let temperatureField = NSTextField(string: "")
    let maxTokensField = NSTextField(string: "")
    let view: NSView

    var llmConfig: Configuration.LLMConfig? {
        let baseURL = baseURLField.stringValue.trimmingCharacters(in: .whitespaces)
        let apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespaces)
        let model = modelField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !baseURL.isEmpty, !apiKey.isEmpty, !model.isEmpty else { return nil }
        guard baseURL.hasPrefix("https://") || baseURL.hasPrefix("http://") else { return nil }
        guard let temperature = Double(temperatureField.stringValue),
              (0.0...2.0).contains(temperature) else { return nil }
        guard let maxTokens = Int(maxTokensField.stringValue), maxTokens > 0 else { return nil }
        return Configuration.LLMConfig(baseURL: baseURL, apiKey: apiKey, model: model, temperature: temperature, maxTokens: maxTokens)
    }

    init(configuration: Configuration.LLMConfig) {
        baseURLField.stringValue = configuration.baseURL
        apiKeyField.stringValue = configuration.apiKey
        modelField.stringValue = configuration.model
        temperatureField.stringValue = String(configuration.temperature)
        maxTokensField.stringValue = String(configuration.maxTokens)
        let stack = NSStackView(views: [
            NSTextField(labelWithString: "LLM base URL:"),
            baseURLField,
            NSTextField(labelWithString: "LLM API key:"),
            apiKeyField,
            NSTextField(labelWithString: "LLM model:"),
            modelField,
            NSTextField(labelWithString: "Temperature (0.0–2.0):"),
            temperatureField,
            NSTextField(labelWithString: "Max tokens:"),
            maxTokensField
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        view = stack
    }
}
