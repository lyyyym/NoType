# Implementation Plan: NoType V1 Core Voice Input

**Branch**: `[001-core-voice-input]` | **Date**: 2026-07-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-core-voice-input/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Build a lightweight macOS menu-bar application that lets the user hold a global shortcut (`Command + .` by default) to record speech, send the audio to an OpenAI-compatible ASR endpoint (default model `qwen-asr-flash`), optionally polish the transcript through an OpenAI-compatible LLM endpoint, and finally inject the resulting text into the current cursor position via simulated keyboard input. All configuration lives in `~/.config/notype/config.toml`; no settings window UI is provided in the MVP.

## Technical Context

**Language/Version**: Swift 5.9+ with SwiftUI/AppKit — native macOS development gives reliable global hotkeys, menu-bar status icons, audio capture, and keyboard injection through CoreGraphics.

**Primary Dependencies**:
- **AppKit / SwiftUI**: menu-bar status item, global event monitoring, app lifecycle.
- **AVFoundation**: audio capture from the default microphone to PCM/WAV.
- **CoreGraphics**: keyboard event injection via `CGEventPost`.
- **Foundation `URLSession`**: HTTP/HTTPS calls to ASR and LLM endpoints.
- **TOML parser package** (`TOMLKit` or equivalent): decode `~/.config/notype/config.toml` into Swift structs.

**Storage**: N/A for runtime data; audio buffers live only in memory and are discarded after transcription. Configuration is a single TOML file on disk.

**Testing**:
- **Unit tests** (XCTest): configuration parsing, audio buffer assembly, LLM prompt building, keyboard event sequence generation.
- **Manual integration tests**: end-to-end dictation in Safari, Notes, and Terminal.
- **Contract tests** (automated where feasible): mock ASR/LLM endpoints to verify request/response handling.

**Target Platform**: macOS 14+ (Sonoma). `Command + .` global shortcut and modern `AVAudioEngine` APIs are stable on this baseline.

**Project Type**: desktop-app (menu-bar background application).

**Performance Goals**:
- End-to-end latency: polished text appears within 8 seconds for a 10-second dictation (from spec SC-001).
- Recording latency from shortcut press to first audio sample capture: < 100 ms.
- Memory footprint: < 200 MB during a 60-second recording.

**Constraints**:
- No audio persisted to disk by default (privacy, FR-012).
- Maximum recording duration: 60 seconds (FR-014).
- Application must not require Accessibility permission for the global shortcut itself; Accessibility permission is acceptable/expected for keyboard injection.
- No graphical settings window UI (FR-010).

**Scale/Scope**: Single-user, single-machine desktop MVP. No multi-user, no server-side component, no cross-platform support.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is currently a placeholder template with no active principles or governance constraints. Therefore no constitution gates are enforced for this feature.

**Pre-design check**: ✅ No violations.
**Post-design check**: ✅ No violations. Single app target, no external storage, file-based config; all align with the minimal MVP scope.

## Project Structure

### Documentation (this feature)

```text
specs/001-core-voice-input/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
NoType/
├── NoType.xcodeproj          # Xcode project for the macOS app
├── NoType/
│   ├── App/
│   │   ├── NoTypeApp.swift           # App entry point, menu-bar lifecycle
│   │   └── StatusBarController.swift # NSStatusItem + menu
│   ├── Config/
│   │   ├── Config.swift              # Domain model
│   │   └── ConfigLoader.swift        # TOML file reading
│   ├── Audio/
│   │   ├── AudioRecorder.swift       # AVAudioEngine recording
│   │   └── AudioBuffer.swift         # In-memory PCM/WAV buffer
│   ├── Input/
│   │   ├── GlobalShortcut.swift      # Register/unregister hotkey
│   │   └── KeyboardInjector.swift    # CGEvent text injection
│   ├── Transcription/
│   │   ├── ASRClient.swift           # OpenAI-compatible ASR request
│   │   ├── LLMClient.swift           # OpenAI-compatible LLM request
│   │   └── PolishPrompt.swift        # Prompt builder
│   └── Models/
│       ├── RecordingSession.swift    # Session state machine
│       └── TextInsertionResult.swift
├── NoTypeTests/
│   ├── ConfigLoaderTests.swift
│   ├── AudioBufferTests.swift
│   ├── KeyboardInjectorTests.swift
│   └── TranscriptionClientTests.swift
└── README.md
```

**Structure Decision**: Single macOS Xcode project. A single app target is sufficient for this MVP because all functionality (shortcut, audio, network, keyboard injection, menu-bar UI) is delivered as one background process. No separate packages or services are needed.

## Complexity Tracking

> No complexity violations identified; single app target aligns with the minimal MVP scope.
