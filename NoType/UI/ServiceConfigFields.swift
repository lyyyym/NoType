import AppKit

/// Reusable form for editing an ASR/LLM-style service configuration.
@MainActor
final class ServiceConfigFields {
    let baseURLField = NSTextField(string: "")
    let apiKeyField = NSTextField(string: "")
    let modelField = NSTextField(string: "")
    let view: NSView

    var serviceConfig: Configuration.ServiceConfig? {
        let baseURL = baseURLField.stringValue.trimmingCharacters(in: .whitespaces)
        let apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespaces)
        let model = modelField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !baseURL.isEmpty, !apiKey.isEmpty, !model.isEmpty else { return nil }
        guard baseURL.hasPrefix("https://") || baseURL.hasPrefix("http://") else { return nil }
        return Configuration.ServiceConfig(baseURL: baseURL, apiKey: apiKey, model: model)
    }

    init(title: String, config: Configuration.ServiceConfig) {
        baseURLField.stringValue = config.baseURL
        apiKeyField.stringValue = config.apiKey
        modelField.stringValue = config.model
        view = SettingsUI.rowsStack([
            SettingsUI.row(label: "Base URL", field: baseURLField),
            SettingsUI.row(label: "API key", field: apiKeyField),
            SettingsUI.row(label: "Model", field: modelField)
        ])
    }
}
