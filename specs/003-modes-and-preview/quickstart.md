# Quickstart Validation Guide: NoType V3 - Polishing Modes & Preview Before Injection

**Feature**: [spec.md](spec.md)
**Plan**: [plan.md](plan.md)
**Data Model**: [data-model.md](data-model.md)

This guide provides runnable validation scenarios for the V3 feature. It assumes the same environment as V1/V2 (macOS 14+, Swift 6.0 toolchain, a valid `~/.config/notype/config.toml`, Accessibility + Microphone permissions). See the V2 quickstart for baseline setup.

## Prerequisites

- macOS 14 or later with Xcode Command Line Tools
- A valid `~/.config/notype/config.toml` (ASR + LLM credentials). V3 adds `[ui] show_preview_before_injection`; its absence defaults to `false`.
- Accessibility permission (global shortcuts, injection, app activation) and Microphone permission granted
- Existing V2 local data in `~/Library/Application Support/NoType/` (optional; V3 migrates cleanly whether or not it exists)

## Build and Run

```bash
cd /Users/yiming/Documents/learn-speckit/NoType
swift build
swift test
swift run NoType
```

Keep the terminal visible to read logs (prefixed `[Module]`, e.g. `[ModeStore]`, `[GlobalShortcut]`, `[Preview]`).

## Validation Scenarios

### 1. First-Launch Migration (V2 → V3)

**Setup**: simulate a fresh V3 install while preserving V2 config.

```bash
rm ~/Library/Application\ Support/NoType/modes.json
```

**Steps**:
1. Ensure `~/.config/notype/config.toml` has a `[shortcut]` (e.g. `key="."`, `modifiers=["command"]`).
2. Run `swift run NoType`.
3. Open Settings → Polishing Modes.

**Expected**: Three default modes exist. The "Everyday polish" mode's shortcut equals the legacy `[shortcut]` (`Cmd + .`); its instruction is the built-in polish prompt. Holding `Cmd + .` produces the same polish output as V2 (SC-005). `modes.json` now exists.

### 2. Multiple Modes via Dedicated Shortcuts

**Steps**:
1. Focus a text editor.
2. Hold the "Everyday polish" shortcut, speak a casual sentence, release. Confirm a cleaned-up, natural result is injected.
3. Speak the **same** sentence while holding the "Translate to English" shortcut. Confirm an English translation is injected.
4. Repeat with the "Formal / email" shortcut. Confirm a formally-worded version is injected.

**Expected**: The three outputs differ according to each mode's style (SC-001), and all three shortcuts work independently within one session.

### 3. Preview Before Injection

**Setup**: enable preview.

```Steps**:
1. Settings → UI → enable "Preview before injection". Save.
2. Hold any mode shortcut, speak a sentence, release.

**Expected**: An editable preview window appears (within ~200ms of polish) showing the processed text; nothing is injected yet.

3. Edit a word in the preview, press **Enter** (or click Confirm).

**Expected**: The window closes, the originally-focused editor comes back to the front, and the **edited** text is injected there (FR-017). The entry appears in History and the word count in Stats reflects the edited text.

4. Trigger another recording; in the preview, press **Esc** (or Cancel).

**Expected**: The window closes, nothing is injected, and History/Stats are unchanged.

### 4. Preview Toggle Off → Immediate Injection

**Steps**:
1. Settings → disable "Preview before injection". Save.
2. Hold a shortcut, speak, release.

**Expected**: Text is injected immediately with no preview window — identical to V2 (FR-011, SC-006). The toggle takes effect on the next recording without restarting.

### 5. Manage Modes (Add / Edit / Delete)

**Add**:
1. Settings → Polishing Modes → Add.
2. Name "Code dictation", capture an unused shortcut (e.g. `Cmd + Control + .`), leave instruction empty (plain dictation), save.
3. Hold the new shortcut, speak, release.

**Expected**: The raw transcript is injected verbatim (no LLM polish), because the instruction is empty (FR-007).

**Edit**:
4. Edit "Code dictation", give it an instruction, save.
5. Use it again.

**Expected**: Output now reflects the new instruction (SC-007), effective immediately.

**Delete**:
6. Delete "Code dictation".

**Expected**: Its shortcut no longer triggers.

**Conflict**:
7. Add a mode and try to assign a shortcut already used by another mode.

**Expected**: Save is refused with a clear conflict message (FR-006).

**Last-mode guard**:
8. Try to delete every mode until one remains.

**Expected**: Deleting the final mode is refused.

### 6. V2 Regression

**Steps**:
1. Open History, Stats, Dictionary, and the floating-bubble flow.

**Expected**: All V2 features work unchanged (SC-004). History/Stats operate on the final injected text for every mode and for both preview-confirmed and direct-injection paths. The personal dictionary hint is applied in every mode's polish. The recording bubble still appears and the shortcut is reusable immediately after each result.

## Automated Test Commands

```bash
swift test
```

New V3 test files to look for:
- `ModeStoreTests` — add/update/delete, shortcut uniqueness, minimum-one guard, default seeding
- `GlobalShortcutMatchingTests` — pure matching helpers select the correct mode id from an event
- `PolishPromptModeTests` — mode instruction becomes the system message; empty instruction path; dictionary hint appended
- `PreviewWindowControllerTests` — confirm (with/without edit) and cancel state transitions; target-app capture/restore
- `ConfigStoreTests` — `show_preview_before_injection` TOML round-trip and default

## Troubleshooting

- **A mode's shortcut does not trigger**: confirm the shortcut is unique among modes (Settings → Polishing Modes) and that Accessibility permission is granted. Check logs for `[GlobalShortcut]`.
- **Preview window does not appear**: confirm `[ui] show_preview_before_injection = true` in `config.toml` (or the Settings checkbox). It only appears after a successful ASR; an empty transcription errors out as in V2 and never opens the preview.
- **Text injected into the wrong app after preview**: the preview re-activates the app focused when recording began. If that app was closed, NoType falls back to the current frontmost app and logs a warning — reopen the target and retry.
- **Migration did not preserve the old shortcut**: ensure the legacy `[shortcut]` section exists in `config.toml`; it is only consulted on first seed (when `modes.json` is absent).
- **Mode changes not taking effect**: mode add/edit/delete rebuilds the shortcut monitor immediately; if not, check `[ModeStore]` save logs and that Settings was saved.

## Notes

- Modes live in `~/Library/Application Support/NoType/modes.json`; the preview toggle lives in `~/.config/notype/config.toml` `[ui]`.
- No cloud services are involved in V3. Modes and the preview setting are local-only.
- Implementation details (model/service/controller bodies, full test suites) live in `tasks.md` and the implementation phase, not in this guide.
