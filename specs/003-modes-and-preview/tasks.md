---

description: "Task list for NoType V3 implementation"

---

# Tasks: NoType V3 - Polishing Modes & Preview Before Injection

**Input**: Design documents from `/specs/003-modes-and-preview/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/config-toml.md](contracts/config-toml.md), [contracts/polish-modes.md](contracts/polish-modes.md), [quickstart.md](quickstart.md)

**Tests**: Included. The project constitution (`.specify/memory/constitution.md` Principle IV) requires test coverage for new logic, and V2 established a one-test-file-per-store/logic convention with swift-testing. Each new logic unit gets a test file.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions (paths are relative to the `NoType/` repo root, i.e. `NoType/<path>`)

---

## Phase 1: Setup (Shared Data Layer)

**Purpose**: Add the base mode entity and extend the existing configuration with the preview toggle. All touch different files and are parallelizable.

- [ ] T001 [P] Create `NoType/Models/PolishingMode.swift` with the `PolishingMode` struct: `id: UUID`, `name: String`, `shortcut: Configuration.Shortcut`, `instruction: String`, `outputLanguage: String?`, `isBuiltin: Bool`, `createdAt: Date`; `Codable` + `Identifiable`; default memberwise init with `id = UUID()`, `createdAt = Date()`
- [ ] T002 [P] Extend `NoType/Config/Config.swift` (the `Configuration` struct) with `var showPreviewBeforeInjection: Bool` (default `false`) added to the init with a default value
- [ ] T003 [P] Extend `NoType/Config/ConfigLoader.swift` `buildUI` to parse `[ui].show_preview_before_injection` (default `false`, same pattern as `show_floating_bubble`) and thread it through `build`
- [ ] T004 [P] Extend `NoType/Persistence/ConfigStore.swift` `serialize` to write `show_preview_before_injection` under the `[ui]` section

---

## Phase 2: Foundational (Core Mode Logic — Blocking Prerequisites)

**Purpose**: The mode data store, mode-aware polishing, and multi-shortcut matching that US1 and US3 both depend on. Pure logic, fully unit-testable, completed before any user story integration.

**⚠️ CRITICAL**: No user story integration can begin until this phase is complete.

- [ ] T005 [P] Create `NoType/Persistence/ModeStore.swift` backed by `JSONFileStore<[PolishingMode]>` (`modes.json`): `load()` (seeds defaults if missing/corrupt), `allModes()`, `mode(forShortcut:)`, `mode(for:)`, `add(_:)` (uniqueness check), `update(id:name:shortcut:instruction:outputLanguage:)` (uniqueness vs others), `delete(id:)` (refuse last mode). Seed logic takes an optional legacy `Configuration.Shortcut` for the "Everyday polish" default (see [data-model.md](data-model.md) migration + [contracts/polish-modes.md](contracts/polish-modes.md) §2)
- [ ] T006 [P] Add `NoTypeTests/ModeStoreTests.swift` (swift-testing): add/update/delete, shortcut-uniqueness conflict throws, delete-last refused, default seeding produces 3 modes with unique shortcuts, migration uses the supplied legacy shortcut for the everyday mode
- [ ] T007 [P] Extend the existing `NoTypeTests/ConfigStoreTests.swift` with a `show_preview_before_injection` round-trip test and default-`false` when absent
- [ ] T008 [P] Refactor `NoType/Input/GlobalShortcut.swift` to monitor a collection of `(modeID, Configuration.Shortcut)` bindings behind a single global monitor and fire `onPress(modeID:)` / `onRelease(modeID:)`; extract the modifier+key matching into pure `static` helpers so they are testable without events
- [ ] T009 [P] Add `NoTypeTests/GlobalShortcutMatchingTests.swift` exercising the pure matching helpers: given a set of bindings and modifier flags + key, the correct mode id (or none) is selected; duplicate-shortcut bindings are rejected at registration
- [ ] T010 [P] Extend `NoType/Transcription/PolishPrompt.swift` with `messages(for transcript:dictionaryHint:systemInstruction:outputLanguage:)` that uses the mode `systemInstruction` as the system message (folding `outputLanguage` and the dictionary hint); keep the existing `systemPrompt` constant as the built-in everyday instruction; an empty `systemInstruction` returns a user-only message (caller skips the LLM)
- [ ] T011 [P] Extend `NoType/Transcription/LLMClient.swift` `polish` to accept `systemInstruction:` and `outputLanguage:` parameters threaded into `PolishPrompt.messages`; when `systemInstruction` is empty, short-circuit and return `PolishPrompt.normalize(transcript)` without a network call
- [ ] T012 [P] Add `NoTypeTests/PolishPromptModeTests.swift`: mode instruction becomes the system message; `outputLanguage` is folded; dictionary hint is appended; empty instruction yields a user-only message; the everyday built-in instruction equals the V2 `systemPrompt`

**Checkpoint**: Foundation ready — modes persist and round-trip, multi-shortcut matching is correct, and mode-aware prompts compose. No UI or controller integration yet.

---

## Phase 3: User Story 1 - Multiple Polishing Modes via Dedicated Shortcuts (Priority: P1) 🎯 MVP

**Goal**: Holding a mode's shortcut records, polishes with that mode's instruction, and injects. Ships with 3 seeded defaults; V2 users keep their shortcut and polish style.

**Independent Test**: Delete `~/Library/Application Support/NoType/modes.json`, launch, hold the everyday shortcut and speak, then hold the translate shortcut and speak the same words; confirm two appropriately different outputs (SC-001, SC-005).

### Implementation for User Story 1

- [ ] T013 [US1] Integrate mode resolution + mode-aware polish into `NoType/App/DictationController.swift`: capture the selected `modeID` on press, resolve the mode from `ModeStore`, pass `mode.instruction`/`mode.outputLanguage` to `LLMClient.polish`; empty instruction uses raw transcript; LLM failure falls back to raw (V2 behavior); keep `session = nil` reset on success/failure (FR-016)
- [ ] T014 [US1] Wire `ModeStore` + the multi-shortcut `GlobalShortcut` into `NoType/App/AppDelegate.swift` `startNormalFlow`: load/seed modes, register all mode shortcuts, forward `onPress(modeID:)`/`onRelease(modeID:)` to the controller
- [ ] T015 [US1] Ensure `ModeStore.load()` seeding is invoked at launch in `NoType/App/AppDelegate.swift` and the legacy `Configuration.shortcut` is passed so the "Everyday polish" default reuses the V2 shortcut (FR-004, SC-005)
- [ ] T016 [US1] Show the active mode name in the status bar while recording in `NoType/App/StatusBarController.swift` (extend `update(_:)` or add a mode-label API) so the independent test is visible
- [ ] T017 [US1] Add `NoTypeTests/DictationControllerModeTests.swift`: with injectable ASR/LLM clients, the selected mode's instruction is forwarded; an empty-instruction mode yields the raw transcript with no LLM call; an LLM failure falls back to raw regardless of mode

**Checkpoint**: US1 fully functional — multiple shortcuts produce mode-appropriate output, V2 behavior preserved.

---

## Phase 4: User Story 2 - Preview Before Injection (Priority: P1)

**Goal**: When the preview toggle is on, show an editable preview after polishing; confirm (inject, possibly edited), edit-then-inject, or cancel (discard). Text lands in the app that was frontmost when recording began.

**Independent Test**: Enable "Preview before injection" in Settings, hold a shortcut and speak; edit the preview and confirm — the edited text is injected into the originally-focused editor; trigger again and cancel — nothing is injected (SC-003, FR-017).

> **Shared-file note**: US2 also edits `DictationController.swift` and `AppDelegate.swift` (like US1). Develop US2 after US1 to avoid merge conflicts in the processing flow; US2's independent test still passes against a single mode.

### Implementation for User Story 2

- [ ] T018 [P] [US2] Create `NoType/Input/FrontmostApp.swift`: a value type capturing `NSWorkspace.shared.frontmostApplication` (processIdentifier + bundleIdentifier) and a `reactivate()` that brings it back via `NSRunningApplication.activate(options:)` with a best-effort short wait; returns whether reactivation succeeded
- [ ] T019 [P] [US2] Create `NoType/UI/PreviewWindowController.swift` (`NSWindowController`, `@MainActor`): an editable multi-line `NSTextView` prefilled with the processed text, **Enter**/Confirm and **Esc**/Cancel handling, exposing `onConfirm: (String) -> Void` (edited text) and `onCancel: () -> Void`; only one instance live at a time
- [ ] T020 [P] [US2] Add `NoTypeTests/PreviewWindowControllerTests.swift`: confirm without editing returns the processed text; confirm after editing returns the edited text; cancel invokes the cancel callback and injects nothing
- [ ] T021 [US2] Integrate the preview gate into `NoType/App/DictationController.swift`: capture `FrontmostApp` at press; after polishing, if `Configuration.showPreviewBeforeInjection` show `PreviewWindowController`; on confirm, `reactivate()` the target app then inject the (edited) text and record history/stats; on cancel, discard and record nothing; keep the immediate-injection path when the toggle is off (FR-011)
- [ ] T022 [US2] Add a "Preview before injection" checkbox to the UI group in `NoType/UI/SettingsWindowController.swift`, bound to `Configuration.showPreviewBeforeInjection` and persisted through the existing `onSave` (FR-012); ensure `AppDelegate` reloads the toggle into the active controller on save

**Checkpoint**: US2 fully functional — preview appears, edits flow to the original target app, cancel discards, toggle off restores V2 instant injection.

---

## Phase 5: User Story 3 - Manage Modes in Settings (Priority: P2)

**Goal**: Create, edit, and delete modes and assign shortcuts from Settings, with conflict and last-mode guards; changes take effect immediately.

**Independent Test**: Open Settings → Polishing Modes, add a mode with an unused shortcut and an empty instruction, save, and confirm plain-dictation output; edit its instruction and confirm changed output; delete it and confirm the shortcut stops triggering; attempt a duplicate shortcut and confirm it is refused.

### Implementation for User Story 3

- [ ] T023 [P] [US3] Create `NoType/UI/ModeEditorView.swift` (`NSView`, `@MainActor`): reusable add/edit form with a name field, a shortcut capture (reuse `ShortcutEditorView`), a multi-line instruction `NSTextView`, an optional output-language field, and a built-in badge; exposes a `PolishingMode`-shaped result
- [ ] T024 [US3] Add a "Polishing Modes" section (mode `NSTableView` + Add/Edit/Delete buttons) to `NoType/UI/SettingsWindowController.swift`, wired to `ModeStore`: validate non-empty name and unique shortcut (surfacing a clear conflict message, FR-006), refuse deleting the last mode
- [ ] T025 [US3] Extend the Settings save path in `NoType/App/AppDelegate.swift` so that after mode add/edit/delete the `GlobalShortcut` monitor is rebuilt from the current `ModeStore` (extend `reloadShortcut` / the `onSave` callback to pass the updated store); changes are effective immediately (SC-007)
- [ ] T026 [US3] Add `NoTypeTests/ModeEditorValidationTests.swift` (and/or extend `ModeStoreTests`): empty name rejected, duplicate shortcut rejected with a clear error, delete-last refused — covered at the logic layer the UI calls into

**Checkpoint**: US3 fully functional — modes are manageable, conflicts/guards enforced, edits live instantly.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final integration, documentation, and validation across all stories.

- [ ] T027 [P] Update `NoType/README.md` with V3 features (polishing modes + shortcuts, preview before injection) and the new `[ui].show_preview_before_injection` config key
- [ ] T028 Run every validation scenario in [quickstart.md](quickstart.md): migration, multi-mode, preview (edit/cancel), toggle off, mode management (add/edit/delete/conflict/last-guard), V2 regression
- [ ] T029 [P] Add an end-to-end smoke test for the V3 flow in `NoTypeTests/` (mode selection drives the instruction; preview-confirm path injects the edited text into the captured target)
- [ ] T030 [P] Review shared-file changes for cross-story consistency (`DictationController.swift`, `AppDelegate.swift`, `SettingsWindowController.swift`) and remove the now-dead V2 single-shortcut code path where it is safe to do so
- [ ] T031 Run `swift build` and `swift test` to green; verify no `.build` artifacts are committed

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately; all four tasks parallel.
- **Phase 2 (Foundational)**: Depends on Phase 1 (uses `PolishingMode`); blocks all user-story integration. All Phase 2 tasks are parallel (distinct files).
- **Phase 3 (US1)**: Depends on Phase 2. Touches `DictationController.swift` + `AppDelegate.swift`.
- **Phase 4 (US2)**: Depends on Phase 2; **recommended after US1** because both edit `DictationController.swift` + `AppDelegate.swift` (the preview gate inserts into the processing flow US1 restructures). Independently testable against a single mode.
- **Phase 5 (US3)**: Depends on Phase 2 (uses `ModeStore`). Adds Settings UI; safe to run in parallel with US1/US2 except for the shared `AppDelegate` save-path change (T025).
- **Phase 6 (Polish)**: Depends on all desired stories being complete.

### User Story Dependencies

- **US1 (Multi-mode, P1)**: After Phase 2. No dependency on other stories.
- **US2 (Preview, P1)**: After Phase 2; integrates cleanly after US1 (shared files). No functional dependency on US1 — preview works with a single mode.
- **US3 (Mode management, P2)**: After Phase 2 (reuses `ModeStore` CRUD built there). No functional dependency on US1/US2.

### Within Each User Story

- Models / pure logic before controller integration.
- Controller integration before AppDelegate wiring.
- Tests alongside the logic they cover.
- Story complete and independently validated before moving on.

### Parallel Opportunities

- All Phase 1 tasks (different files).
- All Phase 2 tasks (different files).
- Within US2: `FrontmostApp.swift` (T018), `PreviewWindowController.swift` (T019), and its test (T020) are parallel; the `DictationController` integration (T021) depends on them.
- Within US3: `ModeEditorView.swift` (T023) is parallel with nothing else blocking; the Settings section (T024) depends on it.
- US1 and US3 can largely proceed in parallel (different files) except for the shared `AppDelegate` and `DictationController`.

---

## Parallel Example: User Story 2

```bash
# Launch the US2 building blocks together (different files, no dependencies):
Task: "Create FrontmostApp helper in NoType/Input/FrontmostApp.swift"
Task: "Create PreviewWindowController in NoType/UI/PreviewWindowController.swift"
Task: "Add PreviewWindowControllerTests in NoTypeTests/PreviewWindowControllerTests.swift"

# Then integrate (depends on the above):
Task: "Integrate the preview gate into NoType/App/DictationController.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Complete Phase 1: Setup (shared data layer).
2. Complete Phase 2: Foundational (mode store + mode-aware polish + multi-shortcut matching).
3. Complete Phase 3: User Story 1 (multi-mode input with seeded defaults).
4. **STOP and VALIDATE**: Two shortcuts → two different outputs; V2 shortcut/style preserved.

### Incremental Delivery

1. Setup + Foundational → core logic ready and tested.
2. Add US1 → test multi-mode input independently.
3. Add US2 → test preview independently.
4. Add US3 → test mode management independently.
5. Polish → README, quickstart validation, smoke test, cleanup.

### Parallel Team Strategy

With multiple developers:

1. Team completes Phase 1 and Phase 2 together.
2. Once Phase 2 is done:
   - Developer A: US1 (DictationController + AppDelegate)
   - Developer B: US2 (FrontmostApp + PreviewWindowController), merging into DictationController after A
   - Developer C: US3 (ModeEditorView + Settings section)
3. Coordinate on the shared `DictationController.swift`, `AppDelegate.swift`, and `SettingsWindowController.swift`.

---

## Notes

- [P] tasks = different files, no dependencies.
- [Story] label maps each task to its user story for traceability.
- Each user story is independently completable and testable; stop at any checkpoint to validate.
- Run `swift test` after each story to catch regressions early (constitution Principle IV).
- Shared files to coordinate on: `DictationController.swift`, `AppDelegate.swift`, `SettingsWindowController.swift`.
- Configuration lives at `NoType/Config/Config.swift` and `NoType/Config/ConfigLoader.swift` (not `Models/`) — tasks use these correct paths.
