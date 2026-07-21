# Research: NoType V3 - Polishing Modes & Preview Before Injection

**Date**: 2026-07-21
**Feature**: [spec.md](spec.md)

This document records the decisions made for V3 implementation unknowns, with rationale and alternatives considered. All spec clarifications were resolved during `/speckit-clarify` (see the `## Clarifications` section of [spec.md](spec.md)); this file resolves the remaining technical/design choices.

## 1. Where to store polishing modes: TOML config vs. local JSON

**Decision**: Store modes as JSON in `~/Library/Application Support/NoType/modes.json` (a new `ModeStore`), mirroring the V2 history/dictionary pattern. Store only the simple `show_preview_before_injection` toggle in the existing TOML `[ui]` section.

**Rationale**:
- A mode is an array of structured records, each with an id, name, shortcut, a potentially long multi-line instruction, an optional language, and a built-in flag. The hand-rolled TOML reader in `Config/ConfigLoader.swift` is a flat section/key=value parser; it has no support for arrays-of-tables (`[[modes]]`) or comfortable multi-line string values. Forcing modes into TOML would mean either a much larger parser or lossy encoding.
- V2 already established the convention that **user-data collections** (history, dictionary, stats, onboarding) live as JSON in Application Support via `JSONFileStore`, while **simple settings + credentials** live in TOML. Modes are user data edited primarily through the UI (like the dictionary), not by hand-editing a config file, so they fit the JSON pattern.
- `JSONFileStore<T>` is generic and already battle-tested by V2 (history, dictionary). A `ModeStore` is a near-copy of `DictionaryStore`, minimizing new surface area.
- The preview toggle is a single boolean that belongs with the other UI toggles (`show_floating_bubble`, `bubble_position`), so it extends `[ui]` in TOML with one line — well within the existing parser's capability.

**Alternatives considered**:
- Modes in TOML `[[modes]]`: rejected because the parser cannot represent it without significant rework, and multi-line prompt instructions are awkward in TOML.
- A single combined `state.json` for all user data: rejected because V2 deliberately keeps each domain in its own file for isolated, small reads/writes.
- `UserDefaults`: rejected (breaks manual inspection/backup and is inconsistent with V2's local-file approach).

## 2. Migrating the V2 single shortcut into a default mode

**Decision**: On first launch of V3, if `modes.json` does not exist, `ModeStore` seeds three built-in default modes. The default "Everyday polish" mode's shortcut is taken from the legacy `[shortcut]` section of `config.toml` (falling back to `Command + .`), and its instruction is the existing built-in `PolishPrompt.systemPrompt` text — so an upgrading V2 user's primary shortcut and polish style are preserved verbatim.

**Rationale**:
- Satisfies FR-004 and SC-005 (no behavior change for existing users).
- The other two defaults (translate-to-English, formal/email) get sensible secondary shortcuts that do not collide with the migrated primary (e.g. `Command + Shift + .` and `Command + Option + .`), chosen only if free.
- After seeding, the `[shortcut]` TOML section becomes legacy. `ConfigLoader` continues to read it (so a hand-edited config still bootstraps the default mode's shortcut on a fresh seed), but the source of truth for active shortcuts is `modes.json`. No data is destroyed; the TOML field is simply no longer authoritative once modes exist.

**Alternatives considered**:
- Drop `[shortcut]` entirely and hard-code `Command + .`: rejected because it would change behavior for users who customized their V2 shortcut.
- Keep `[shortcut]` as a live, always-synced mirror of "the primary mode": rejected as redundant and a source of sync bugs; one source of truth (modes.json) is cleaner.

## 3. Registering multiple global shortcuts

**Decision**: Generalize `GlobalShortcut` to monitor a collection of `(modeID, Configuration.Shortcut)` bindings behind a **single** `NSEvent.addGlobalMonitorForEvents` monitor. On a key event, it matches the event against all bindings and, on a hit, fires `onPress(modeID:)` / `onRelease(modeID:)` with the matched mode's id.

**Rationale**:
- `NSEvent.addGlobalMonitorForEvents` already receives every global keyDown/keyUp; the current implementation filters for one configuration. Matching against several configurations in the same callback is a small, localized change and avoids creating N monitors (each monitor is a system resource and would each receive all events anyway).
- Carbon hotkeys (`RegisterEventHotKey`) were considered for V1 and rejected in favor of the NSEvent monitor (see V1/V2 research). That tradeoff is unchanged for V3: the monitor approach is simpler and already works, and the number of modes is tiny.
- Re-registration on Settings change already exists (`reloadShortcut` in `AppDelegate`); it is extended to rebuild the monitor from the current `ModeStore` contents, so added/edited/deleted modes take effect immediately (SC-007).

**Alternatives considered**:
- One `GlobalShortcut` instance per mode (N monitors): rejected — more system resources, each receives all events, and coordinating press/release state across monitors is error-prone.
- Carbon `RegisterEventHotKey` per mode: rejected — heavier, requires Carbon event handlers, and offers no benefit at this scale.

## 4. Capture and restore the target app for preview injection

**Decision**: Introduce a small `FrontmostApp` helper (`Input/FrontmostApp.swift`) that snapshots `NSWorkspace.shared.frontmostApplication` (process identifier + bundle id) at the moment recording starts (`didPressShortcut`). On preview confirm, `PreviewWindowController` asks the helper to re-activate that app (`NSRunningApplication(processIdentifier:)?.activate(options:)`), waits for it to become frontmost (best-effort, short delay), then injects via the existing `KeyboardInjector.inject` (which types into the now-frontmost app). On cancel, nothing is injected and no history/stats are recorded.

**Rationale**:
- Directly implements the clarified requirement (spec Q1 / FR-017): the text must land where the user was originally typing, even though the preview panel took keyboard focus to allow editing.
- Reusing `KeyboardInjector` unchanged keeps the ASCII/Unicode segmentation and Accessibility-trust logic in one place.
- `NSRunningApplication.activate` is the supported, non-deprecated API on macOS 14+ for bringing another app forward.

**Edge handling** (from spec edge cases + graceful-degradation principle):
- If the captured app has exited by confirm time, NoType logs a warning and injects into whatever is currently frontmost (the user's last-chance target) rather than failing silently — the text is never lost, but the user is informed via the menu-bar status.
- If preview is disabled, the flow is exactly V2 (inject immediately into the frontmost app, which never changed).

**Alternatives considered**:
- Inject into whatever is frontmost at confirm time: rejected — the user would have to manually click back to their editor, a poor experience (this was the rejected option in clarify Q1).
- Clipboard-based paste: rejected — adds a manual step and clobbers the user's clipboard, breaking the seamless-injection value proposition.
- Keep the preview panel non-activating (`.nonactivatingPanel`) so it never steals focus: rejected because then the user could not edit the text in it without elaborate key-event forwarding; an editable field requires the panel to be key window.

## 5. Mode-aware polishing prompt

**Decision**: Make `PolishPrompt` mode-aware. Add `PolishPrompt.messages(for transcript:dictionaryHint:systemInstruction:)` that uses the mode's instruction as the system message (falling back to the built-in `systemPrompt` only if the instruction is empty **and** the caller did not request plain dictation). A mode with an empty instruction skips the LLM call entirely and uses the raw transcript verbatim (plain dictation, per FR-007). `LLMClient.polish` gains a `systemInstruction:` parameter threaded through. The dictionary hint is appended for every mode (FR-014).

**Rationale**:
- The built-in "Everyday polish" mode's instruction is the **existing** `systemPrompt` string, so V2 polish behavior is reproduced byte-for-byte (SC-005).
- Translate and formal modes are just different `systemInstruction` strings; no new LLM plumbing, no per-mode endpoint/model (modes affect only the post-recognition instruction, per the spec assumption).
- LLM failure still falls back to the raw transcript (`PolishPrompt.normalize`) regardless of mode, preserving V2's graceful degradation.

**Alternatives considered**:
- Per-mode LLM model/endpoint: explicitly out of scope (spec assumption); the same ASR/LLM service config serves all modes.
- Post-processing string rewriting for translation: rejected — brittle; letting the instruction steer the LLM is the robust choice (same rationale as V2's dictionary-hint decision).

## 6. Default preview state and the preview toggle

**Decision**: `show_preview_before_injection` defaults to `false` (clarify Q2), stored in `[ui]` of `config.toml`, toggleable in Settings and applied immediately (no restart). When false, the flow is identical to V2 (FR-011). When true, after polishing the `PreviewWindowController` is shown before injection (FR-009/FR-010).

**Rationale**: preserves the instant-injection experience existing users expect; review is opt-in.

**Alternatives considered**: default-on — rejected because it changes the default behavior V2 users rely on (violates SC-005's spirit for the common path).

## 7. UI: managing modes and the preview toggle

**Decision**: Extend `SettingsWindowController` with a "Polishing Modes" section (an `NSTableView` of modes with add/edit/delete via a reusable `ModeEditorView` form — name, shortcut capture, multi-line instruction, optional output language, built-in badge) and a "Preview before injection" checkbox in the existing "UI" group. Saving validates: non-empty name, non-empty shortcut, unique shortcut among modes (FR-006), and refuses deleting the last mode (spec edge case). On save, `ModeStore` persists and `AppDelegate.reloadShortcut` rebuilds the global monitor.

**Rationale**: follows the V2 settings pattern (sections in a scrollable stack, reusable form subviews like `ServiceConfigFields`/`LLMConfigFields`). Shortcut capture reuses `ShortcutEditorView`. Conflict detection is enforced in `ModeStore` so the rule is unit-testable independent of UI.

**Alternatives considered**: a separate "Modes" window from the menu bar (like History/Dictionary): rejected because modes are core configuration, not a data browser, and belong in Settings alongside the other preferences.

## 8. Mode identity and shortcut uniqueness

**Decision**: `PolishingMode.id` is a `UUID`. Shortcut uniqueness is enforced (two modes may not share the same key+modifiers combination). Mode **names** are not required to be unique (only the shortcut is the binding key), but the UI trims and requires non-empty names. At least one mode must always remain (deleting the last is refused).

**Rationale**: the shortcut is what selects a mode at press time, so it must be unique; names are display-only, so duplicate names are harmless and needlessly restrictive to forbid.

**Alternatives considered**: unique names: rejected as over-constraining with no functional benefit.
