# Implementation Plan: NoType V2 - Configurable Voice Tool

**Branch**: `002-configurable-voice-tool` | **Date**: 2026-07-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-configurable-voice-tool/spec.md`

## Summary

NoType V2 evolves the macOS menu-bar voice input MVP into a configurable daily tool. The core voice pipeline (shortcut → record → ASR → LLM polish → inject) remains unchanged. V2 adds a first-launch onboarding wizard, a full settings window, local recording history (last 50 entries), daily/cumulative word-count statistics, a personal dictionary managed by the user, and a floating visual indicator during recording.

The implementation keeps the existing Swift Package Manager + AppKit architecture. New UI surfaces (onboarding, settings, history, dictionary, stats) are implemented as native AppKit windows and view controllers to match the current codebase. Local state is persisted in JSON files under the macOS Application Support directory, with configuration continuing to live in `~/.config/notype/config.toml` for backward compatibility.

## Technical Context

**Language/Version**: Swift 5 (SPM tools version 6.0, swiftLanguageMode .v5)

**Primary Dependencies**: AppKit, AVFoundation, Carbon, Foundation, swift-testing

**Storage**: Local JSON files in `~/Library/Application Support/NoType/` for history, statistics, dictionary, and onboarding state; TOML configuration file at `~/.config/notype/config.toml`.

**Testing**: swift-testing

**Target Platform**: macOS 14+ (Apple Silicon and Intel)

**Project Type**: Desktop menu-bar application

**Performance Goals**: Settings window opens within 500ms; history panel displays within 1s; floating bubble appears within 200ms of shortcut press; dictionary save/update is synchronous and sub-second.

**Constraints**: Requires Accessibility permission for global shortcut monitoring and keyboard injection; requires Microphone permission for recording; no cloud storage; no settings UI for V1 is replaced by the settings window.

**Scale/Scope**: Single-user, local-first; history capped at 50 entries; dictionary and stats unbounded but expected to remain small (<10k entries). UI is menu-bar driven with auxiliary windows.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

No `.specify/memory/constitution.md` exists. Default gates apply:

- **Simplicity**: Prefer native AppKit over introducing a second UI framework; no new runtime dependencies.
- **Local-first**: History, stats, and dictionary must not leave the device.
- **Backward compatibility**: Existing TOML config remains readable and writable.
- **Testability**: New business logic (word counting, history eviction, dictionary prompt formatting) must be unit-testable.

**Result**: Pass. Design choices below respect these gates.

## Project Structure

### Documentation (this feature)

```text
specs/002-configurable-voice-tool/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
NoType/
├── Package.swift
├── README.md
└── NoType/
    ├── App/
    │   ├── NoTypeApp.swift
    │   ├── AppDelegate.swift          # split from NoTypeApp.swift
    │   ├── DictationController.swift
    │   ├── StatusBarController.swift
    │   ├── OnboardingController.swift # NEW
    │   └── SettingsWindowController.swift # NEW
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
    ├── UI/                            # NEW
    │   ├── FloatingBubbleWindow.swift
    │   ├── HistoryWindowController.swift
    │   ├── DictionaryWindowController.swift
    │   └── StatsWindowController.swift
    ├── Persistence/                   # NEW
    │   ├── HistoryStore.swift
    │   ├── StatsStore.swift
    │   ├── DictionaryStore.swift
    │   └── ConfigStore.swift
    ├── Models/
    │   ├── RecordingError.swift
    │   ├── RecordingSession.swift
    │   └── Configuration.swift
    └── Config/
        ├── Config.swift
        └── ConfigLoader.swift
NoTypeTests/
├── AudioBufferTests.swift
├── ConfigLoaderTests.swift
├── KeyboardInjectorTests.swift
├── PolishPromptTests.swift
├── RecordingSessionTests.swift
└── TranscriptionClientTests.swift
# NEW test files added by implementation:
# HistoryStoreTests.swift, StatsStoreTests.swift, DictionaryStoreTests.swift, WordCountTests.swift
```

**Structure Decision**: Keep the existing SPM package layout. Add `App/`, `UI/`, and `Persistence/` groups for the new V2 concerns. Split `NoTypeApp.swift` into `AppDelegate.swift` to keep lifecycle code separate from the `@main` entry point. All new UI uses AppKit to avoid mixing SwiftUI and AppKit window management.

## Complexity Tracking

No complexity gate violations.
