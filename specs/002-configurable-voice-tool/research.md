# Research: NoType V2 - Configurable Voice Tool

**Date**: 2026-07-21
**Feature**: [spec.md](../spec.md)

This document records the decisions made for V2 implementation unknowns, with rationale and alternatives considered.

## UI Framework: AppKit vs. SwiftUI for new windows

**Decision**: Use AppKit (`NSWindow` + `NSViewController`) for the onboarding wizard, settings window, history/dictionary/stats panels, and floating bubble.

**Rationale**:
- The existing V1 codebase is entirely AppKit. Introducing SwiftUI would add a second UI framework, increase binary size, and complicate window management (hosting SwiftUI in `NSWindow` adds boilerplate).
- AppKit gives precise control over window level, style mask, and keyboard shortcuts, which is important for a global-floating bubble and settings panes.
- Native AppKit forms (`NSTextField`, `NSComboBox`, `NSButton`, `NSTableView`) are sufficient for the settings, history, and dictionary interfaces.

**Alternatives considered**:
- SwiftUI for settings and onboarding: rejected because it adds a framework boundary and does not materially reduce code for these simple forms.
- SwiftUI hosted in `NSWindowController`: rejected to keep the codebase uniform and avoid SwiftUI lifecycle edge cases.

## Settings storage: migrate away from TOML or keep it

**Decision**: Keep `~/.config/notype/config.toml` as the source of truth; the settings window reads from and writes to the same file.

**Rationale**:
- Backward compatibility: existing V1 users already have this file with their API keys.
- The user specifically requested "完整设置窗口" but did not ask to change the underlying storage format.
- A single source of truth avoids sync issues between GUI and file edits.

**Alternatives considered**:
- Migrate to `UserDefaults`: rejected because it would break manual editing and version-controllable configuration.
- Migrate to `~/Library/Preferences`: rejected for the same backward-compatibility reason.

## Local data persistence format

**Decision**: Store history, statistics, dictionary, and onboarding state as JSON files under `~/Library/Application Support/NoType/`.

**Rationale**:
- JSON is human-readable for debugging, easy to back up, and natively supported by Swift `Codable`.
- `~/Library/Application Support/` is the correct macOS location for app-specific user data.
- Each domain gets its own file (`history.json`, `stats.json`, `dictionary.json`, `onboarding.json`) to keep reads/writes small and isolated.

**Alternatives considered**:
- Single SQLite database: rejected because relationships are minimal and a database adds complexity without benefit.
- Core Data: rejected because it is overkill for small, unstructured local data.
- Property list (plist): rejected because JSON is easier to inspect and diff.

## Floating recording bubble implementation

**Decision**: Implement as a small, borderless `NSPanel` with `level = .floating` and `styleMask = [.borderless, .nonactivatingPanel]`.

**Rationale**:
- `NSPanel` is the correct AppKit class for auxiliary floating windows.
- `.floating` level keeps the bubble above normal windows without requiring `popUpMenu` semantics.
- The bubble positions itself near the current cursor or menu bar based on user preference.
- It is purely visual: it does not intercept mouse or keyboard events.

**Alternatives considered**:
- Custom `NSWindow` with `canBecomeKey = false`: functionally similar, but `NSPanel` is the idiomatic choice.
- SwiftUI `.overlay`/`.popover`: rejected because it requires a host view and cannot float globally.

## Word counting for mixed CJK and Latin text

**Decision**: Use a language-aware counter: CJK characters count individually; Latin text counts whitespace-separated words.

**Rationale**:
- The success criterion requires CJK handling. Counting CJK characters individually is the standard convention for Chinese/Japanese/Korean text.
- The injected (polished) text is the source of truth for statistics.
- The same counter is used for both daily and cumulative stats.

**Alternatives considered**:
- Always split by whitespace: rejected because it would under-count CJK text.
- Use ICU `wordBreakIterator`: rejected to avoid adding the `icucore` dependency and extra complexity; a regex-based heuristic satisfies the requirement.

## Personal dictionary application

**Decision**: Include dictionary entries as contextual hints in the LLM polish prompt (confirmed during `/speckit-clarify`).

**Rationale**:
- The ASR endpoint is remote and cannot be fine-tuned or hinted at the model level.
- Post-processing replacement is brittle and can damage correct output.
- Adding a system/user message with the dictionary terms lets the LLM choose the correct form based on context.

**Format in prompt**:

```text
The user has provided the following preferred terms. Use them when contextually appropriate:
- "term1" -> preferred spelling/capitalization
- "term2" -> ...
```

**Alternatives considered**:
- Post-processing string replacement: rejected because it can introduce false positives.
- ASR model-level adaptation: not possible with the current OpenAI-compatible ASR provider.

## Onboarding flow

**Decision**: A single setup wizard window shown on first launch with three pages: microphone permission, accessibility permission, basic configuration.

**Rationale**:
- Bundling the two permissions and config into one flow reduces context switching.
- Each page has a clear call to action and a "skip" option where safe (config can be edited later; permissions cannot).
- Completion is persisted so the wizard does not reappear.

**Alternatives considered**:
- Separate permission prompts triggered lazily: rejected because it leads to a poor first-run experience and repeated interruptions.
- No wizard, just menu-bar error messages: rejected because it matches the V1 behavior the user explicitly wants to improve.

## History eviction policy

**Decision**: Retain the most recent 50 successful recordings. On each new insertion, append to the front and drop the oldest entry if the count exceeds 50.

**Rationale**:
- Matches FR-005 exactly.
- Simple and predictable for users.
- Deleting an entry updates stats; removed entries are gone permanently.

## Stats reset behavior

**Decision**: Daily count resets at local midnight. Cumulative count never resets.

**Rationale**:
- "Today" is defined by the user's local calendar date.
- The app checks the date on launch and whenever a new recording is saved; if the stored "current day" differs from today, daily count resets to 0.
- Cumulative is the running total since first use.

## Menu-bar integration of new features

**Decision**: Add menu items to the existing status bar menu for Settings, History, Dictionary, Stats, and Quit. The settings window is also reachable via a keyboard shortcut.

**Rationale**:
- Menu-bar apps expose functionality through the status item menu; this is consistent with V1.
- Separate windows for history/dictionary/stats keep the UI simple and focused.
- A settings shortcut improves power-user workflow.
