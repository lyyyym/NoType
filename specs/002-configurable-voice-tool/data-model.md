# Data Model: NoType V2 - Configurable Voice Tool

**Feature**: [spec.md](../spec.md)
**Plan**: [plan.md](../plan.md)

This document describes the entities, attributes, relationships, validation rules, and state transitions introduced by V2.

## Entities

### RecordingEntry

Represents a single successful voice input.

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique identifier for the entry. |
| `timestamp` | ISO-8601 string | When the recording finished and text was injected. |
| `rawText` | String | Transcript returned by the ASR service. |
| `polishedText` | String | Final text after LLM polish and dictionary hints. |
| `wordCount` | Int | Number of words/characters in `polishedText`. |

**Validation rules**:
- `polishedText` must be non-empty.
- `wordCount` must equal the language-aware word count of `polishedText`.

**Relationships**:
- Belongs to `HistoryStore`.
- Contributes to `WordCountStats`.

---

### HistoryStore

The rolling window of recent recordings.

| Field | Type | Description |
|-------|------|-------------|
| `entries` | [RecordingEntry] | Ordered newest-first. Max length 50. |

**Validation rules**:
- `entries.count` must never exceed 50.
- New entries are inserted at index 0.
- Removal updates `WordCountStats`.

**State transitions**:
- `append(entry)`: insert at front, evict oldest if count > 50.
- `delete(id)`: remove entry by id, recalculate stats.
- `reset()`: clear all entries and stats.

---

### WordCountStats

Daily and cumulative word counts.

| Field | Type | Description |
|-------|------|-------------|
| `currentDay` | ISO-8601 date string | The calendar day for which `dailyCount` is valid. |
| `dailyCount` | Int | Words injected today. |
| `cumulativeCount` | Int | Words injected since first use. |

**Validation rules**:
- Both counts are non-negative.
- `dailyCount` <= `cumulativeCount` for the same day.

**State transitions**:
- `record(words: Int)`: increment both counts; if `currentDay` != today, reset `dailyCount` to `words` and update `currentDay`.
- `delete(words: Int)`: decrement both counts, clamping at 0.
- `resetDaily()`: set `dailyCount` to 0.

---

### PersonalDictionaryEntry

A user-managed term or phrase.

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique identifier. |
| `term` | String | The word or phrase the user wants recognized. |
| `hint` | String? | Optional note on preferred spelling, capitalization, or usage. |
| `createdAt` | ISO-8601 string | When the entry was added. |

**Validation rules**:
- `term` must be non-empty and trimmed.
- Duplicate `term` values are not allowed (case-sensitive by default).

**Relationships**:
- Belongs to `DictionaryStore`.
- Serialized into the LLM polish prompt as a hint list.

---

### DictionaryStore

Container for personal dictionary entries.

| Field | Type | Description |
|-------|------|-------------|
| `entries` | [PersonalDictionaryEntry] | Unordered list of dictionary entries. |

**Operations**:
- `add(term, hint?)`: append new entry if term is unique.
- `update(id, term, hint?)`: modify existing entry; enforce uniqueness.
- `delete(id)`: remove entry.
- `promptHint() -> String`: format entries for injection into the LLM prompt.

---

### Configuration

Extension of the existing V1 configuration.

| Field | Type | Description |
|-------|------|-------------|
| `shortcut` | Shortcut | Global hotkey (modifier keys + key). |
| `asr` | ServiceConfig | ASR base URL, model, API key. |
| `llm` | ServiceConfig | LLM base URL, model, API key, temperature, max tokens. |
| `showFloatingBubble` | Bool | Whether the recording bubble is visible. |
| `bubblePosition` | Enum | `cursor` or `menuBar`. |

**Validation rules**:
- `shortcut.modifiers` must contain at least one modifier.
- `asr.baseURL` and `llm.baseURL` must be valid URLs.
- API keys must be non-empty.

**Relationships**:
- Stored in `~/.config/notype/config.toml`.
- Read/written by `ConfigStore` and the settings window.

---

### OnboardingState

Tracks first-launch setup progress.

| Field | Type | Description |
|-------|------|-------------|
| `hasCompletedOnboarding` | Bool | True once the user finishes or skips the wizard. |
| `microphonePermissionRequested` | Bool | True once the app has requested mic permission. |
| `accessibilityPermissionRequested` | Bool | True once the app has checked/prompted for accessibility. |
| `basicConfigSaved` | Bool | True once the user saves settings during onboarding. |

**State transitions**:
- Initial state: all false.
- On completion: `hasCompletedOnboarding` becomes true.
- Individual flags update as the user progresses through wizard pages.

## Relationships Summary

```text
OnboardingState ──1:1── App launch
Configuration ──1:1── Settings window / ConfigStore
HistoryStore ──1:*── RecordingEntry
WordCountStats ──1:1── HistoryStore (derived)
DictionaryStore ──1:*── PersonalDictionaryEntry
DictationController ──uses── DictionaryStore (prompt hints)
DictationController ──uses── HistoryStore / WordCountStats (on successful injection)
```

## State Transitions

### Recording lifecycle with V2 persistence

```text
[Shortcut pressed]
    │
    ▼
[Start recording] ──► [Floating bubble shown]
    │
    ▼
[Shortcut released]
    │
    ▼
[ASR] ──► [LLM polish with dictionary hints]
    │
    ▼
[Inject text]
    │
    ├──► [Append RecordingEntry to HistoryStore]
    ├──► [Update WordCountStats]
    └──► [Hide floating bubble]
```

### Onboarding lifecycle

```text
[App launch]
    │
    ▼
[hasCompletedOnboarding?]
    │
    ├── No ──► [Show onboarding wizard]
    │              │
    │              ▼
    │         [Microphone page] ──► [Accessibility page] ──► [Basic config page]
    │              │
    │              ▼
    │         [Save onboarding state]
    │
    └── Yes ──► [Normal menu-bar operation]
```

## Validation Rules Summary

- `RecordingEntry.polishedText` must not be empty.
- `HistoryStore.entries.count` <= 50.
- `WordCountStats` counts must be non-negative and `dailyCount` <= `cumulativeCount`.
- `PersonalDictionaryEntry.term` must be unique and non-empty.
- `Configuration` shortcut must include at least one modifier and a valid key.
- `Configuration` service URLs must be valid HTTP/HTTPS URLs.

## Persistence Mapping

| Entity | File |
|--------|------|
| HistoryStore + RecordingEntry | `~/Library/Application Support/NoType/history.json` |
| WordCountStats | `~/Library/Application Support/NoType/stats.json` |
| DictionaryStore + PersonalDictionaryEntry | `~/Library/Application Support/NoType/dictionary.json` |
| OnboardingState | `~/Library/Application Support/NoType/onboarding.json` |
| Configuration | `~/.config/notype/config.toml` |

## Notes

- All JSON files use `Codable` for serialization.
- Corrupted JSON files are treated as empty defaults; the app logs a warning.
- The `Configuration` entity is an extension of the existing V1 `Configuration` struct; V2 adds UI-related fields (`showFloatingBubble`, `bubblePosition`).
