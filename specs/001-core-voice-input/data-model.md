# Data Model: NoType V1 Core Voice Input

**Feature**: [spec.md](spec.md)

## Entity: Configuration

Represents the contents of `~/.config/notype/config.toml`.

| Field | Type | Required | Default | Validation |
|-------|------|----------|---------|------------|
| `shortcut_key` | String | Yes | `"."` | Single character or named key |
| `shortcut_modifiers` | [String] | Yes | `["command"]` | Each value ∈ {"command", "option", "control", "shift"} |
| `asr.base_url` | String (URL) | Yes | — | Must be a valid HTTPS URL |
| `asr.api_key` | String | Yes | — | Non-empty |
| `asr.model` | String | Yes | `"qwen-asr-flash"` | Non-empty |
| `llm.base_url` | String (URL) | Yes | — | Must be a valid HTTPS URL |
| `llm.api_key` | String | Yes | — | Non-empty |
| `llm.model` | String | Yes | — | Non-empty |
| `llm.temperature` | Double | No | `0.0` | 0.0–2.0 |
| `llm.max_tokens` | Int | No | `4096` | > 0 |

**Relationships**: None (singleton read at startup).

---

## Entity: RecordingSession

Represents one press-hold-release dictation cycle.

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique session identifier |
| `startedAt` | Date | When shortcut was pressed |
| `stoppedAt` | Date? | When shortcut was released or 60s cap hit |
| `status` | RecordingStatus | State of the session |
| `audioBuffer` | AudioBuffer | In-memory PCM/WAV data |
| `rawTranscription` | String? | ASR output, once available |
| `polishedText` | String? | LLM output or raw fallback |
| `error` | RecordingError? | Terminal error, if any |

### RecordingStatus State Machine

```
Idle ──[shortcut pressed]──> Recording
Recording ──[shortcut released | 60s timeout]──> Processing
Processing ──[success]──> Inserted
Processing ──[ASR success, LLM failure]──> InsertedRaw
Processing ──[ASR failure | no audio]──> Failed
```

| State | Description |
|-------|-------------|
| `Idle` | Waiting for user input |
| `Recording` | Capturing microphone audio |
| `Processing` | Sending audio to ASR, then text to LLM |
| `Inserted` | Polished text injected at cursor |
| `InsertedRaw` | Raw ASR text injected because LLM failed |
| `Failed` | No text injected due to unrecoverable error |

---

## Entity: AudioBuffer

In-memory container for captured audio.

| Field | Type | Description |
|-------|------|-------------|
| `sampleRate` | Int | Fixed at 16000 |
| `channels` | Int | Fixed at 1 (mono) |
| `bitsPerSample` | Int | Fixed at 16 |
| `pcmBytes` | Data | Raw PCM samples |

**Behavior**:
- Appends samples while `RecordingSession.status == .recording`.
- Generates WAV-formatted `Data` on demand for ASR upload.
- Discarded after transcription (no disk persistence).

---

## Entity: CursorContext

Represents the target location for text insertion.

| Field | Type | Description |
|-------|------|-------------|
| `frontmostAppBundleId` | String? | Bundle ID of the active application |
| `hasKeyboardFocus` | Bool | Best-effort indicator of an editable field |

**Behavior**:
- The system does not verify an editable text field; it injects keystrokes into the frontmost app.
- If no field has focus, injected keys are silently dropped by the target app.

---

## Validation Rules

1. Configuration file must exist at startup; missing file is a fatal error with a clear message.
2. ASR and LLM URLs must be valid HTTPS URLs.
3. RecordingSession cannot transition from `Recording` to any state other than `Processing`.
4. AudioBuffer cannot be read for transcription while `RecordingSession.status != .recording` has not been reached.

## Notes

- No persistent database is used. All runtime entities live in memory.
- The Configuration singleton is immutable after startup (restart required for changes).
