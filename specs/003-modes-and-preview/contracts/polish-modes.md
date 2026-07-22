# Contract: Polishing Modes & Per-Mode Shortcuts (V3)

**Feature**: [spec.md](../spec.md)

This contract defines the user-facing concept of a **polishing mode**, how a mode's global shortcut selects it, and how a mode's instruction composes the LLM polishing request. It is the core new contract introduced by V3.

## 1. Mode entity (on-disk: `modes.json`)

A mode is a JSON object stored in the `entries` array of `~/Library/Application Support/NoType/modes.json`:

```json
{
  "id": "8E1F…-…-…",
  "name": "Translate to English",
  "shortcut": { "key": ".", "modifiers": ["command", "shift"] },
  "instruction": "Translate the following transcript into natural, fluent English. Preserve the original meaning. Do not add commentary.",
  "outputLanguage": "English",
  "isBuiltin": true,
  "createdAt": "2026-07-21T10:30:00Z"
}
```

| Field | Type | Rules |
|-------|------|-------|
| `id` | string (UUID) | Unique. Assigned at creation. |
| `name` | string | Non-empty, trimmed. Not required to be unique. |
| `shortcut` | object `{key, modifiers}` | Same shape as V2 `Configuration.Shortcut`. `key` non-empty; `modifiers` ≥1 of `command`/`option`/`control`/`shift`. **Unique across modes.** |
| `instruction` | string | May be empty → plain dictation (raw transcript, no LLM call). |
| `outputLanguage` | string \| null | Optional hint folded into the instruction at polish time. |
| `isBuiltin` | boolean | `true` for the three shipped defaults; marks origin only. |
| `createdAt` | string (ISO-8601) | Creation timestamp. |

The collection invariant: **at least one mode always exists**.

## 2. Shipped default modes (seeded on first launch)

| # | name | shortcut (if free) | instruction | outputLanguage |
|---|------|--------------------|-------------|----------------|
| 1 | Everyday polish | legacy `[shortcut]` (else `Cmd + .`) | the existing built-in `PolishPrompt.systemPrompt` | null |
| 2 | Translate to English | `Cmd + Shift + .` | "Translate the following transcript into natural, fluent English. Preserve the original meaning. Do not add commentary." | "English" |
| 3 | Formal / email | `Cmd + Option + .` | "Rewrite the following transcript in clear, formal, professional prose suitable for an email or document. Fix grammar and tone. Preserve the original meaning. Do not add commentary." | null |

Seeding chooses the listed shortcut only if it does not collide with an already-assigned one; otherwise it advances to the next candidate so the seed never violates uniqueness.

## 3. Shortcut → mode binding (selection contract)

- Exactly **one** global event monitor observes all key events.
- On `keyDown`, the monitor matches the event's modifiers + key against every mode's `shortcut`. The **unique** matching mode (uniqueness is enforced, so there is at most one) is selected.
- Selection fires `onPress(modeID:)`; the matching key's release fires `onRelease(modeID:)` (release matched by physical key code, same release-semantics as V2 — modifier may be released first).
- Adding, editing, or deleting a mode rebuilds the monitor from the current `modes.json`, so changes are effective immediately within the session.

## 4. Mode-aware polish request (LLM contract extension)

For a selected mode, the polishing request is the existing OpenAI-compatible `/chat/completions` call (see the V1 `llm-api` contract), with the **system message** sourced from the mode:

```text
system message = mode.instruction
                + (mode.outputLanguage != null ? ("\nOutput language: " + mode.outputLanguage) : "")
                + (dictionaryHint not empty ? ("\n\n" + dictionaryHint) : "")
user message   = raw ASR transcript
```

Rules:
- If `mode.instruction` is empty, the LLM is **not called**; the raw transcript is used verbatim (plain dictation). `PolishPrompt.normalize` is still applied (trim + strip surrounding quotes) before injection.
- If the LLM call fails for a non-empty instruction, the app falls back to the raw transcript (V2 graceful degradation), regardless of mode.
- The "Everyday polish" built-in instruction is the exact V2 `systemPrompt`, so its request body is byte-identical to V2 (SC-005).

All other request fields (`model`, `temperature`, `max_tokens`, endpoint URL, auth header) come from the shared `[llm]` config and are **not** affected by the mode (per the spec assumption: modes change only the instruction).

## 5. Preview contract (interaction, when enabled)

When `show_preview_before_injection` is `true`, after polishing the app shows a single editable preview panel:

- **Contents**: an editable multi-line text field initialized with the processed text.
- **Confirm** (Enter, or the Confirm button): close panel → re-activate the app captured at recording start → inject the (possibly edited) text → record history + stats → reset session.
- **Cancel** (Esc, or the Cancel button): close panel → no injection, no history, no stats → reset session.
- Only one preview session exists at a time; triggering a new recording while a preview is open finalizes/discards the in-flight preview first.
- The injected text (edited or not) is what gets stored in history and counted in stats, regardless of mode.
