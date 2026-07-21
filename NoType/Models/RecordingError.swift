import Foundation

/// Typed errors used across config, audio, transcription, and injection.
enum ConfigError: Error, LocalizedError, CustomStringConvertible {
    case fileNotFound(String)
    case unreadable(String)
    case invalidSyntax(String)
    case missingSection(String)
    case invalidValue(String)

    var description: String {
        switch self {
        case .fileNotFound(let path): return "config file not found: \(path)"
        case .unreadable(let detail): return "config file unreadable: \(detail)"
        case .invalidSyntax(let detail): return "config syntax error: \(detail)"
        case .missingSection(let section): return "missing config section: \(section)"
        case .invalidValue(let detail): return "invalid config value: \(detail)"
        }
    }

    var errorDescription: String? { description }
}

enum AudioError: Error, LocalizedError, CustomStringConvertible {
    case permissionDenied
    case engineStartFailed(String)
    case noInputDevice

    var description: String {
        switch self {
        case .permissionDenied: return "microphone permission denied"
        case .engineStartFailed(let detail): return "audio engine failed to start: \(detail)"
        case .noInputDevice: return "no microphone input device available"
        }
    }

    var errorDescription: String? { description }
}

enum TranscriptionError: Error, LocalizedError, CustomStringConvertible {
    case asrFailed(String)
    case llmFailed(String)
    case emptyTranscription(String)
    case decoding(String)

    var description: String {
        switch self {
        case .asrFailed(let detail): return "ASR request failed: \(detail)"
        case .llmFailed(let detail): return "LLM request failed: \(detail)"
        case .emptyTranscription(let preview): return "ASR returned an empty transcription. Response: \(preview)"
        case .decoding(let detail): return "could not decode response: \(detail)"
        }
    }

    var errorDescription: String? { description }
}

enum InjectionError: Error, LocalizedError, CustomStringConvertible {
    case accessibilityDenied
    case failed(String)

    var description: String {
        switch self {
        case .accessibilityDenied: return "accessibility permission denied; cannot inject keystrokes"
        case .failed(let detail): return "keyboard injection failed: \(detail)"
        }
    }

    var errorDescription: String? { description }
}
