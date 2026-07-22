# Data Model: NoType V3 - Polishing Modes & Preview Before Injection

**Feature**: [spec.md](spec.md)
**Plan**: [plan.md](plan.md)

This document describes the entities, attributes, relationships, validation rules, and state transitions introduced by V3. It extends the V2 data model; V2 entities (RecordingEntry, HistoryStore, WordCountStats, PersonalDictionaryEntry, DictionaryStore, OnboardingState) are unchanged unless noted.

## Entities

### PolishingMode

A named, user-configurable processing profile bound to a global shortcut.

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Unique identifier. |
| `name` | String | Non-empty, trimmed display name (e.g. "Everyday polish", "Translate to English"). Not required to be unique. |
| `shortcut` | Shortcut | The global shortcut (key + modifiers) that selects this mode. Reuses the V2 `Configuration.Shortcut` shape. Must be unique across modes. |
| `instruction` | String | Free-form polishing instruction used as the LLM system message. May be empty → plain dictation (raw transcript used verbatim, no LLM call). |
| `outputLanguage` | String? | Optional target output language/style hint (e.g. "English"). Folded into the instruction at polish time. |
| `isBuiltin` | Bool | True for the three shipped defaults. Built-ins may still be edited or deleted (subject to the minimum-one rule); the flag only marks origin. |
| `createdAt` | ISO-8601 string | When the mode was created. |

**Validation rules**:
- `name` must be non-empty after trimming.
- `shortcut.key` must be non-empty; `shortcut.modifiers` must list at least one valid modifier (V2 validation reused).
- `shortcut` (key+modifiers combination) must be unique within the mode collection.
- At least one mode must always exist in the collection.

**Relationships**:
- Belongs to `ModeStore`.
- Bound to a `GlobalShortcut` registration by its `shortcut`.
- Drives the `systemInstruction` of a `PolishPrompt` message at polish time.

---

### ModeStore

The ordered collection of polishing modes; the source of truth for active shortcuts.

| Field | Type | Description |
|-------|------|-------------|
| `entries` | [PolishingMode] | All modes. Order is stable for UI display (built-ins first, then user-created by creation time). |

**Operations**:
- `load()`: read `modes.json`; if missing or corrupt, seed default modes (see Migration below) and persist.
- `add(mode)`: append if the mode's shortcut does not collide with an existing one; else throw a conflict error.
- `update(id, name, shortcut, instruction, outputLanguage)`: modify an existing mode; re-enforce shortcut uniqueness against the *other* modes.
- `delete(id)`: remove a mode; refuse if it is the last remaining mode.
- `mode(forShortcut:)` / `mode(for:)`: lookup by shortcut combination or by id.
- `allModes()`: snapshot for UI and shortcut registration.

**Validation rules**:
- Shortcut uniqueness across `entries`.
- `entries.count >= 1` always.

**State transitions**:
- `seedDefaults()`: populate the three built-ins on first launch, migrating the legacy `[shortcut]` into the "Everyday polish" mode.
- `add` / `update` / `delete`: mutate `entries` and persist atomically.

---

### PreviewSession (transient — not persisted)

Represents processed text awaiting the user's decision while the preview window is open.

| Field | Type | Description |
|-------|------|-------------|
| `modeID` | UUID | The mode that produced this text. |
| `rawText` | String | The raw ASR transcript. |
| `processedText` | String | The text after polishing (or raw, if plain-dictation / fallback). Initial contents of the editable field. |
| `targetApp` | FrontmostApp? | Snapshot of the app that was frontmost when recording started; re-activated on confirm (FR-017). |

**State transitions**:
- `confirm(editedText)`: re-activate `targetApp`, inject `editedText`, append to history, update stats, close window.
- `cancel()`: close window; no injection, no history, no stats.

---

### Configuration (extension of V2)

| Field | Type | Description |
|-------|------|-------------|
| `showPreviewBeforeInjection` | Bool | New. Default `false`. When true, the preview window is shown after polishing and before injection. |

The V2 `shortcut` field remains on the struct for backward-compatible bootstrap/migration but is **no longer authoritative** once `modes.json` exists; active shortcuts come from `ModeStore`.

**Validation rules** (additions):
- `showPreviewBeforeInjection` is a boolean (no further constraints).

## Relationships Summary

```text
ModeStore ──1:*── PolishingMode
PolishingMode ──bound to── GlobalShortcut (by shortcut)
PolishingMode ──drives── PolishPrompt.systemInstruction
DictationController ──uses── ModeStore (resolve mode on press)
DictationController ──uses── PreviewWindowController (when preview enabled)
PreviewSession ──references── FrontmostApp (capture/restore target)
Configuration.showPreviewBeforeInjection ──gates── preview window
# Unchanged V2 relationships:
HistoryStore / WordCountStats / DictionaryStore ── operate on final injected text
```

## State Transitions

### Recording lifecycle with modes + preview

```text
[Mode shortcut pressed]
    │  (capture frontmost app snapshot)
    ▼
[Start recording] ──► [Floating bubble shown]   (mode-aware: status reflects mode name)
    │
    ▼
[Shortcut released]
    │
    ▼
[ASR] ──► resolve mode ──► [LLM polish with mode.instruction + dictionary hint]
    │                            (empty instruction → skip LLM, raw transcript;
    │                             LLM failure → raw transcript fallback)
    ▼
[showPreviewBeforeInjection?]
    │
    ├── No  ──► [Inject into frontmost] ──► [History + Stats] ──► [reset session]
    │
    └── Yes ──► [Show editable PreviewSession]
                    │
                    ├── confirm(edited) ──► [Re-activate targetApp] ──► [Inject]
                    │                         ──► [History + Stats] ──► [reset session]
                    └── cancel ──► [discard, no inject, no history/stats] ──► [reset session]
```

### Mode management lifecycle

```text
[Settings → Modes section]
    │
    ├── add    ──► [validate name + unique shortcut] ──► [ModeStore.add] ──► [persist]
    │                                                            ──► [rebuild GlobalShortcut]
    ├── edit   ──► [validate] ──► [ModeStore.update] ──► [persist] ──► [rebuild GlobalShortcut]
    └── delete ──► [refuse if last mode] ──► [ModeStore.delete] ──► [persist] ──► [rebuild GlobalShortcut]
```

### First-launch migration

```text
[modes.json missing on launch]
    │
    ▼
[ModeStore.seedDefaults]
    │  - Everyday polish: shortcut = legacy [shortcut] (or Cmd+.), instruction = built-in systemPrompt
    │  - Translate to English: shortcut = first free of {Cmd+Shift+., Cmd+Option+.}
    │  - Formal / email: shortcut = next free
    ▼
[persist modes.json] ──► [register all mode shortcuts]
```

## Validation Rules Summary

- `PolishingMode.name` non-empty (trimmed).
- `PolishingMode.shortcut` non-empty key + ≥1 valid modifier.
- Shortcut combination unique within `ModeStore`.
- `ModeStore.entries.count >= 1`.
- `showPreviewBeforeInjection` is boolean; default `false`.
- (Unchanged V2 rules for history/stats/dictionary/config service URLs and keys.)

## Persistence Mapping

| Entity | File | Format |
|--------|------|--------|
| ModeStore + PolishingMode | `~/Library/Application Support/NoType/modes.json` | JSON (new) |
| `showPreviewBeforeInjection` | `~/.config/notype/config.toml` `[ui]` | TOML (new field) |
| HistoryStore + RecordingEntry | `~/Library/Application Support/NoType/history.json` | JSON (unchanged) |
| WordCountStats | `~/Library/Application Support/NoType/stats.json` | JSON (unchanged) |
| DictionaryStore | `~/Library/Application Support/NoType/dictionary.json` | JSON (unchanged) |
| OnboardingState | `~/Library/Application Support/NoType/onboarding.json` | JSON (unchanged) |
| Service config + UI toggles | `~/.config/notype/config.toml` | TOML (extended) |

## Notes

- All JSON files use `Codable` via `JSONFileStore`. Corrupt JSON is treated as empty and re-seeded (for modes) or reset (for history/stats/dictionary), with a logged warning — consistent with V2.
- `modes.json` is the single source of truth for active shortcuts once it exists; the TOML `[shortcut]` section is read only to bootstrap the default mode on first seed and is otherwise legacy.
- `PreviewSession` is never written to disk; it lives only for the duration the preview window is open.
