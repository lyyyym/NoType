# Quickstart Guide: NoType V1 Core Voice Input

**Feature**: [spec.md](spec.md)

## Prerequisites

- macOS 14+ (Sonoma)
- Xcode 15+ with Swift 5.9+ toolchain
- A valid OpenAI-compatible ASR endpoint and API key (default model: `qwen-asr-flash`)
- A valid OpenAI-compatible LLM endpoint and API key

## Build

1. Open `NoType/NoType.xcodeproj` in Xcode.
2. Select the `NoType` scheme and a local target (e.g., My Mac).
3. Build with `Cmd + B`.
4. Run with `Cmd + R`.

## Configure

Create the configuration file:

```bash
mkdir -p ~/.config/notype
cat > ~/.config/notype/config.toml <<'EOF'
[shortcut]
key = "."
modifiers = ["command"]

[asr]
base_url = "https://your-asr-provider.com/v1"
api_key = "sk-your-asr-key"
model = "qwen-asr-flash"

[llm]
base_url = "https://your-llm-provider.com/v1"
api_key = "sk-your-llm-key"
model = "gpt-4o-mini"
temperature = 0.0
max_tokens = 4096
EOF
```

## First Run

1. Launch the app. It appears as an icon in the macOS menu bar.
2. Grant Accessibility permission when prompted (required for keyboard injection).
3. Open Notes or any text field.
4. Hold `Command + .` and speak a sentence.
5. Release the shortcut. The polished text should appear at the cursor within 8 seconds.

## Validate End-to-End

### Scenario 1: Basic dictation

- **Action**: Open Notes, hold `Command + .`, say "Hello world", release.
- **Expected**: "Hello world." appears in Notes.

### Scenario 2: LLM fallback

- **Action**: Temporarily set an invalid LLM endpoint in `config.toml`, restart the app, and dictate.
- **Expected**: The raw ASR transcript still appears in Notes.

### Scenario 3: 60-second cap

- **Action**: Hold `Command + .` and speak continuously for more than 60 seconds.
- **Expected**: Recording stops automatically at 60 seconds, and the processed text appears.

### Scenario 4: No focused field

- **Action**: Click on the desktop (no text field), hold `Command + .`, speak, release.
- **Expected**: Menu bar shows processing, but no text is injected anywhere.

### Scenario 5: Missing microphone permission

- **Action**: Revoke microphone permission in System Settings, then dictate.
- **Expected**: Menu bar shows an error indicator; no crash.

## Run Tests

In Xcode:

- Select the `NoTypeTests` scheme.
- Press `Cmd + U` to run unit tests.

For contract tests, use the provided mock servers:

```bash
# ASR mock
python3 -m http.server 8000 --directory specs/001-core-voice-input/contracts/mocks
```

Point `asr.base_url` and `llm.base_url` to `http://localhost:8000` and restart the app.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Menu bar icon does not appear | App not running | Check Xcode console for fatal config errors |
| Shortcut does nothing | Conflict with macOS or another app | Override `shortcut.key`/`shortcut.modifiers` in TOML |
| Audio processes but no text appears | Missing Accessibility permission | Grant permission in System Settings → Privacy & Security → Accessibility |
| Recording never stops | Key-up event missed | Press and release the shortcut cleanly; cap is 60s |
| Polished text appears slowly | Network latency | Check ASR/LLM endpoint response times |
