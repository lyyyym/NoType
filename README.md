# NoType

NoType V1: macOS core voice input.

Hold a global shortcut (default `Command + .`), speak, release, and the polished text is inserted at the current cursor position via simulated keyboard input.

## Build

This project is built with **Swift Package Manager** instead of a hand-authored Xcode project, so it compiles and tests cleanly from the command line.

```bash
cd NoType
swift build
swift test
```

To run the app:

```bash
swift run NoType
```

> **Note:** The plan called for a `.xcodeproj`. SPM was chosen because it is text-based, reviewable, and fully buildable on a machine with only the Swift toolchain. If you prefer Xcode, create a new macOS App project and add the files under `NoType/NoType/` and `NoType/NoTypeTests/`.

## Configure

Create `~/.config/notype/config.toml`:

```toml
[shortcut]
key = "."
modifiers = ["command"]

[asr]
base_url = "https://your-asr-provider.com/v1"
api_key = "sk-..."
model = "qwen-asr-flash"

[llm]
base_url = "https://your-llm-provider.com/v1"
api_key = "sk-..."
model = "gpt-4o-mini"
temperature = 0.0
max_tokens = 4096
```

Changes require an app restart.

> **Note on TOML parsing:** The plan called for the `TOMLKit` package. To keep the build self-contained, a focused TOML reader is included in `Config/ConfigLoader.swift`. It supports the fixed config schema and can be replaced with `TOMLKit` later without touching `Configuration`.

## Permissions

- **Microphone**: requested automatically on first recording.
- **Accessibility**: required for keyboard injection. The app prompts once on launch.

## Validation

See [`specs/001-core-voice-input/quickstart.md`](../specs/001-core-voice-input/quickstart.md) for end-to-end validation scenarios.

## Project Structure

```text
NoType/
├── Package.swift
├── README.md
├── Info.plist           # For distribution as an .app bundle
└── NoType/
    ├── App/
    │   ├── NoTypeApp.swift
    │   ├── StatusBarController.swift
    │   └── DictationController.swift
    ├── Config/
    │   ├── Config.swift
    │   └── ConfigLoader.swift
    ├── Audio/
    │   └── AudioRecorder.swift
    ├── Input/
    │   ├── GlobalShortcut.swift
    │   └── KeyboardInjector.swift
    ├── Transcription/
    │   ├── ASRClient.swift
    │   ├── LLMClient.swift
    │   └── PolishPrompt.swift
    └── Models/
        ├── AudioBuffer.swift
        ├── RecordingSession.swift
        └── RecordingError.swift
```
