# Research Notes: NoType V1 Core Voice Input

**Date**: 2026-07-21
**Feature**: [specs/001-core-voice-input/spec.md](spec.md)

## 1. Language & Platform

**Decision**: Build the MVP as a native macOS app using Swift 5.9+ and AppKit/SwiftUI.

**Rationale**:
- The feature explicitly targets macOS only.
- Native AppKit provides reliable `NSStatusBar` menu-bar icons, `NSEvent` global monitors, `AVAudioEngine` audio capture, and `CGEventPost` keyboard injection.
- A single Xcode project keeps deployment, code signing, and permission requests (microphone, accessibility) straightforward.

**Alternatives considered**:
- Python + rumps/pynput/openai SDK: faster initial prototyping, but global hotkeys and keyboard injection on macOS are less reliable and require packaging as a `.app` for proper permissions.
- Electron/Tauri: heavier runtime and overkill for a background menu-bar app.

## 2. Global Shortcut

**Decision**: Use `NSEvent.addGlobalMonitorForEvents(matching: .keyDown/.keyUp)` plus a local modifier-state check for `Command + .` (period). Provide TOML override.

**Rationale**:
- Pure Cocoa event monitoring avoids deprecated Carbon `RegisterEventHotKey` and is supported on macOS 14+.
- Press-and-hold semantics require both key-down (start recording) and key-up (stop recording) handling.
- The shortcut must be a "hold" interaction, not a toggle, so simple hotkey registration is insufficient.

**Open concern**: If `Command + .` is consumed by another app or macOS, the event monitor may not fire. The implementation should log a warning and let the user override via config.

## 3. Audio Capture & Format

**Decision**: Capture microphone audio using `AVAudioEngine` and encode to 16-bit PCM, 16 kHz, mono, WAV container in memory.

**Rationale**:
- `qwen-asr-flash` and most OpenAI-compatible ASR endpoints accept WAV/PCM audio.
- 16 kHz mono is the de-facto standard for speech recognition and minimizes buffer size.
- WAV header can be prepended to raw PCM bytes without file I/O, keeping audio in memory for privacy (FR-012).

**Constraints**:
- Maximum recording duration: 60 seconds (FR-014) → max buffer size ~1.9 MB (16k * 2 bytes * 60s + WAV header), well within memory budget.
- Request microphone permission via `AVAudioSession`/`AVAudioEngine` permission flow on first use.

## 4. Keyboard Injection

**Decision**: Use `CGEvent(keyboardEventSource: nil, virtualKey: ...)` with `CGEventPost(.cgHIDEventTap, event)` to inject keystrokes as Unicode text.

**Rationale**:
- `CGEventPost` is the standard macOS API for injecting keyboard events at the system level.
- For non-ASCII text (Chinese, etc.), use `CGEvent.keyboardSetUnicodeString` to inject full characters instead of emulating individual key codes.
- Requires Accessibility permission; the app should detect absence of permission and show a menu-bar prompt.

## 5. TOML Configuration Parsing

**Decision**: Use the `TOMLKit` Swift package (or equivalent actively-maintained decoder) to map `~/.config/notype/config.toml` to Swift `Codable` structs.

**Rationale**:
- Native Swift TOML support is not built into Foundation.
- `TOMLKit` provides a `Decoder` interface familiar to Swift developers and supports nested tables (ASR/LLM sections).
- If `TOMLKit` proves incompatible, fallback is `YAMS` with YAML config or manual parsing; TOML remains the user-facing format per spec.

## 6. ASR & LLM Client

**Decision**: Use `URLSession` with custom `URLRequest`s to OpenAI-compatible endpoints.

**Rationale**:
- Avoids vendoring the full OpenAI Swift SDK; keeps binary small and allows arbitrary endpoint URLs.
- Request bodies follow OpenAI `/audio/transcriptions` (ASR) and `/chat/completions` (LLM) schemas.
- API key read from TOML and sent as `Authorization: Bearer <key>`.

**LLM polishing strategy**:
- Send a simple system prompt: "Polish the following transcript for grammar and punctuation. Preserve the original language. Do not add explanations."
- If LLM fails or times out, fall back to raw ASR text (FR-013).

## 7. Testing Strategy

**Decision**:
- XCTest unit tests for pure logic (config parsing, buffer assembly, prompt building, keyboard event sequence).
- Manual end-to-end validation in real apps (Notes, Safari, Terminal) due to the system-level nature of audio, shortcuts, and keyboard injection.
- Local HTTP stub servers for ASR/LLM contract tests.

**Rationale**:
- System-level audio and input injection are difficult to automate reliably in CI without macOS hardware and accessibility permissions.
- Contract tests against stubs verify JSON/TOML schemas and request construction.

## 8. Permissions & Packaging

**Required entitlements/permissions**:
- **Microphone**: `NSMicrophoneUsageDescription` in `Info.plist`.
- **Accessibility**: prompt at runtime when keyboard injection is first attempted; menu-bar item guides user to System Settings.
- **Outgoing network**: standard macOS app capability.

**Distribution**: Build a signed `.app` bundle. MVP does not require App Store sandboxing; notarization is recommended for Gatekeeper but optional for local testing.
