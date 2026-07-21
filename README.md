# NoType

NoType V2: a configurable daily voice input tool for macOS.

Hold a global shortcut (default `Command + .`), speak, release, and the polished text is inserted at the current cursor position via simulated keyboard input.

## V2 Features

- **First-launch onboarding**: guided setup for microphone permission, accessibility permission, and basic ASR/LLM configuration.
- **Settings window**: edit shortcut, ASR/LLM endpoints, API keys, and UI preferences without touching the TOML file.
- **Recording history**: keep the last 50 successful voice inputs locally; copy or delete entries.
- **Word count statistics**: daily and cumulative word counts from injected text.
- **Personal dictionary**: manually manage custom terms; entries are used as hints during LLM polish.
- **Floating recording bubble**: visual indicator while recording.

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
model = "qwen3-asr-flash"

[llm]
base_url = "https://your-llm-provider.com/v1"
api_key = "sk-..."
model = "deepseek-chat"
temperature = 0.0
max_tokens = 4096

[ui]
show_floating_bubble = true
bubble_position = "cursor"
```

Settings changed in the Settings window are saved to the same file and take effect immediately.

> **Note on TOML parsing:** The plan called for the `TOMLKit` package. To keep the build self-contained, a focused TOML reader is included in `Config/ConfigLoader.swift`. It supports the fixed config schema and can be replaced with `TOMLKit` later without touching `Configuration`.

## Permissions

- **Microphone**: requested during onboarding and on first recording.
- **Accessibility**: required for keyboard injection. The app prompts during onboarding and via the menu bar.

## Validation

See [`specs/002-configurable-voice-tool/quickstart.md`](specs/002-configurable-voice-tool/quickstart.md) for end-to-end validation scenarios.

## Project Structure

```text
NoType/
├── Package.swift
├── README.md
└── NoType/
    ├── App/
    │   ├── NoTypeApp.swift
    │   ├── AppDelegate.swift
    │   ├── StatusBarController.swift
    │   ├── DictationController.swift
    │   └── OnboardingWindowController.swift
    ├── Config/
    │   ├── Config.swift
    │   └── ConfigLoader.swift
    ├── Audio/
    │   ├── AudioRecorder.swift
    │   └── AudioBuffer.swift
    ├── Input/
    │   ├── GlobalShortcut.swift
    │   └── KeyboardInjector.swift
    ├── Transcription/
    │   ├── ASRClient.swift
    │   ├── LLMClient.swift
    │   └── PolishPrompt.swift
    ├── UI/
    │   ├── SettingsWindowController.swift
    │   ├── HistoryWindowController.swift
    │   ├── StatsWindowController.swift
    │   ├── DictionaryWindowController.swift
    │   └── FloatingBubbleWindow.swift
    ├── Persistence/
    │   ├── PersistenceDirectory.swift
    │   ├── JSONFileStore.swift
    │   ├── ConfigStore.swift
    │   ├── OnboardingStore.swift
    │   ├── HistoryStore.swift
    │   ├── StatsStore.swift
    │   └── DictionaryStore.swift
    ├── Models/
    │   ├── AudioBuffer.swift
    │   ├── RecordingSession.swift
    │   ├── RecordingError.swift
    │   ├── RecordingEntry.swift
    │   ├── WordCountStats.swift
    │   ├── WordCounter.swift
    │   ├── OnboardingState.swift
    │   └── PersonalDictionaryEntry.swift
    └── Configuration.swift
```
