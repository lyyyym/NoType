---

description: "Task list for NoType V2 implementation"

---

# Tasks: NoType V2 - Configurable Voice Tool

**Input**: Design documents from `/specs/002-configurable-voice-tool/`

**Prerequisites**: [plan.md](../plan.md), [spec.md](../spec.md), [research.md](../research.md), [data-model.md](../data-model.md), [quickstart.md](../quickstart.md)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the new module directories and prepare the existing project for V2 features.

- [ ] T001 [P] Create `NoType/Persistence/` directory and add `PersistenceDirectory.swift` to resolve the Application Support folder
- [ ] T002 [P] Create `NoType/UI/` directory for window controllers and floating bubble
- [ ] T003 [P] Split `NoType/App/NoTypeApp.swift` into `NoType/App/AppDelegate.swift` and `NoType/App/NoTypeApp.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before any user story can be fully implemented.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T004 [P] Create `NoType/Persistence/JSONFileStore.swift` as a generic `Codable` read/write wrapper
- [ ] T005 [P] Create `NoType/Models/WordCounter.swift` with CJK character and Latin word counting
- [ ] T006 [P] Extend `NoType/Models/Configuration.swift` with `showFloatingBubble` and `bubblePosition` fields
- [ ] T007 [P] Create `NoType/Persistence/ConfigStore.swift` to read/write `~/.config/notype/config.toml` with validation
- [ ] T008 [P] Add Settings, History, Dictionary, and Stats menu items to `NoType/App/StatusBarController.swift`
- [ ] T009 [P] Add `NoTypeTests/WordCounterTests.swift` for mixed CJK/Latin counting
- [ ] T010 [P] Add `NoTypeTests/ConfigStoreTests.swift` for TOML round-trip and validation

**Checkpoint**: Foundation ready — persistence, config, word counting, and menu structure are in place.

---

## Phase 3: User Story 1 - Onboarding & Permissions (Priority: P1) 🎯 MVP

**Goal**: Guide first-time users through microphone permission, accessibility permission, and basic configuration so the app is usable immediately.

**Independent Test**: Delete `~/Library/Application Support/NoType/onboarding.json`, launch the app, complete the wizard, and confirm voice input works.

### Tests for User Story 1

- [ ] T011 [P] [US1] Add `NoTypeTests/OnboardingStateTests.swift` covering initial state, completion, and persistence

### Implementation for User Story 1

- [ ] T012 [P] [US1] Create `NoType/Models/OnboardingState.swift` and `NoType/Persistence/OnboardingStore.swift`
- [ ] T013 [P] [US1] Create `NoType/App/OnboardingWindowController.swift` with multi-page wizard layout
- [ ] T014 [US1] Implement microphone permission page in `NoType/App/OnboardingWindowController.swift`
- [ ] T015 [US1] Implement accessibility permission page in `NoType/App/OnboardingWindowController.swift`
- [ ] T016 [US1] Implement basic configuration page in `NoType/App/OnboardingWindowController.swift`
- [ ] T017 [US1] Wire onboarding launch logic in `NoType/App/AppDelegate.swift`

**Checkpoint**: User Story 1 fully functional — fresh install can complete onboarding and inject text.

---

## Phase 4: User Story 2 - Settings Window (Priority: P1)

**Goal**: Provide a GUI for editing all configuration values without touching the TOML file.

**Independent Test**: Open Settings, change the shortcut, save, and verify the new shortcut starts recording.

### Tests for User Story 2

- [ ] T018 [P] [US2] Add `NoTypeTests/ConfigurationValidationTests.swift` for invalid shortcut, URLs, and empty keys

### Implementation for User Story 2

- [ ] T019 [P] [US2] Create `NoType/UI/SettingsWindowController.swift` with tabbed layout
- [ ] T020 [US2] Implement shortcut editor in `NoType/UI/SettingsWindowController.swift`
- [ ] T021 [US2] Implement ASR/LLM service fields in `NoType/UI/SettingsWindowController.swift`
- [ ] T022 [US2] Implement floating bubble toggles in `NoType/UI/SettingsWindowController.swift`
- [ ] T023 [US2] Add validation and save logic in `NoType/UI/SettingsWindowController.swift`
- [ ] T024 [US2] Reload `GlobalShortcut` and `DictationController` on settings save in `NoType/App/AppDelegate.swift`

**Checkpoint**: User Story 2 fully functional — settings changes are persisted and active immediately.

---

## Phase 5: User Story 3 - Recording History (Priority: P2)

**Goal**: Keep the last 50 successful voice inputs locally and let the user view, copy, and delete them.

**Independent Test**: Record 3 phrases, open History, verify order, copy one entry, delete another.

### Tests for User Story 3

- [ ] T025 [P] [US3] Add `NoTypeTests/HistoryStoreTests.swift` covering append, 50-entry eviction, and deletion

### Implementation for User Story 3

- [ ] T026 [P] [US3] Create `NoType/Models/RecordingEntry.swift` and `NoType/Persistence/HistoryStore.swift`
- [ ] T027 [US3] Integrate history recording into `NoType/App/DictationController.swift` after successful injection
- [ ] T028 [US3] Create `NoType/UI/HistoryWindowController.swift` with table view and detail display
- [ ] T029 [US3] Implement copy-to-clipboard and delete actions in `NoType/UI/HistoryWindowController.swift`

**Checkpoint**: User Story 3 fully functional — history is recorded, displayed, and manageable.

---

## Phase 6: User Story 4 - Word Count Statistics (Priority: P2)

**Goal**: Track and display daily and cumulative word counts from injected text.

**Independent Test**: Record a known phrase, open Stats, verify daily and cumulative counts match.

### Tests for User Story 4

- [ ] T030 [P] [US4] Add `NoTypeTests/StatsStoreTests.swift` covering daily reset, cumulative total, and deletion adjustment

### Implementation for User Story 4

- [ ] T031 [P] [US4] Create `NoType/Models/WordCountStats.swift` and `NoType/Persistence/StatsStore.swift`
- [ ] T032 [US4] Integrate stats update into `NoType/App/DictationController.swift` after successful injection
- [ ] T033 [US4] Create `NoType/UI/StatsWindowController.swift` with daily and cumulative display
- [ ] T034 [US4] Wire stats recalculation on history deletion in `NoType/App/DictationController.swift` or `HistoryStore.swift`

**Checkpoint**: User Story 4 fully functional — stats update on record and delete, and reset daily.

---

## Phase 7: User Story 5 - Personal Dictionary (Priority: P2)

**Goal**: Let users manage custom terms and apply them as hints during LLM polish.

**Independent Test**: Add a term, record a phrase containing it, verify the injected text respects the dictionary hint.

### Tests for User Story 5

- [ ] T035 [P] [US5] Add `NoTypeTests/DictionaryStoreTests.swift` covering add, edit, delete, and uniqueness
- [ ] T036 [P] [US5] Update `NoTypeTests/PolishPromptTests.swift` to verify dictionary hint formatting

### Implementation for User Story 5

- [ ] T037 [P] [US5] Create `NoType/Models/PersonalDictionaryEntry.swift` and `NoType/Persistence/DictionaryStore.swift`
- [ ] T038 [US5] Create `NoType/UI/DictionaryWindowController.swift` with add/edit/delete table
- [ ] T039 [US5] Format dictionary hints in `NoType/Transcription/PolishPrompt.swift`
- [ ] T040 [US5] Inject dictionary hints into `NoType/Transcription/LLMClient.swift` before sending the polish request
- [ ] T041 [US5] Add dictionary prompt integration tests in `NoTypeTests/TranscriptionClientTests.swift`

**Checkpoint**: User Story 5 fully functional — dictionary entries persist and improve polish output.

---

## Phase 8: User Story 6 - Floating Recording Bubble (Priority: P3)

**Goal**: Show a small visual indicator while recording is active.

**Independent Test**: Hold the shortcut, confirm bubble appears; release, confirm bubble disappears.

### Tests for User Story 6

- [ ] T042 [P] [US6] Add `NoTypeTests/FloatingBubbleTests.swift` for bubble visibility state and position helpers

### Implementation for User Story 6

- [ ] T043 [P] [US6] Create `NoType/UI/FloatingBubbleWindow.swift` as a borderless `NSPanel`
- [ ] T044 [US6] Wire bubble show/hide in `NoType/App/DictationController.swift` on recording start/stop
- [ ] T045 [US6] Implement cursor-position tracking for bubble placement in `NoType/UI/FloatingBubbleWindow.swift`
- [ ] T046 [US6] Implement menu-bar fallback positioning in `NoType/UI/FloatingBubbleWindow.swift`

**Checkpoint**: User Story 6 fully functional — bubble responds to shortcut and respects the settings toggle.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final integration, documentation, and validation.

- [ ] T047 [P] Update `README.md` with V2 features and onboarding instructions
- [ ] T048 [P] Run all validation scenarios from `specs/002-configurable-voice-tool/quickstart.md`
- [ ] T049 [P] Add end-to-end smoke test for the full V2 flow in `NoTypeTests/`
- [ ] T050 [P] Review and clean up any duplicated code between onboarding and settings forms
- [ ] T051 [P] Verify no `.build` artifacts are committed and run `swift test` one final time

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — can start immediately.
- **Phase 2 (Foundational)**: Depends on Phase 1 completion — blocks all user stories.
- **Phase 3–8 (User Stories)**: All depend on Phase 2 completion. They can proceed in priority order (P1 → P2 → P3) or in parallel if staffed.
- **Phase 9 (Polish)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **User Story 1 (Onboarding, P1)**: Can start after Phase 2. No dependencies on other stories.
- **User Story 2 (Settings, P1)**: Can start after Phase 2. No dependencies on other stories.
- **User Story 3 (History, P2)**: Can start after Phase 2. Can proceed in parallel with US4 and US5.
- **User Story 4 (Stats, P2)**: Can start after Phase 2 and depends on `WordCounter` and `RecordingEntry` (also created in US3). Best to start after T025/T026 or in parallel with them.
- **User Story 5 (Dictionary, P2)**: Can start after Phase 2. No dependencies on other stories except the polish prompt infrastructure.
- **User Story 6 (Bubble, P3)**: Can start after Phase 2. No dependencies on other stories.

### Within Each User Story

- Tests are written alongside models.
- Models before services/UI.
- Core logic before window integration.
- Story complete before moving to the next priority.

### Parallel Opportunities

- All Phase 1 tasks can run in parallel.
- All Phase 2 tasks can run in parallel.
- Once Phase 2 is complete, US3, US4, US5, and US6 can largely run in parallel (US4 needs `RecordingEntry` from US3, but can start once T026 is done).
- Tests within each story can run in parallel with implementation.
- UI window controllers for different stories can be developed in parallel.

---

## Parallel Example: User Story 1

```bash
# Launch models and tests together:
Task: "Create NoType/Models/OnboardingState.swift and NoType/Persistence/OnboardingStore.swift"
Task: "Add NoTypeTests/OnboardingStateTests.swift"

# Then integrate the UI:
Task: "Create NoType/App/OnboardingWindowController.swift"
Task: "Wire onboarding launch logic in NoType/App/AppDelegate.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 + User Story 2)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational.
3. Complete Phase 3: User Story 1 (Onboarding).
4. Complete Phase 4: User Story 2 (Settings).
5. **STOP and VALIDATE**: Fresh install can onboard, change settings, and inject text.

### Incremental Delivery

1. Setup + Foundational → Foundation ready.
2. Add User Story 1 → Test onboarding independently.
3. Add User Story 2 → Test settings independently.
4. Add User Story 3 → Test history independently.
5. Add User Story 4 → Test stats independently.
6. Add User Story 5 → Test dictionary independently.
7. Add User Story 6 → Test bubble independently.
8. Each story adds value without breaking previous stories.

### Parallel Team Strategy

With multiple developers:

1. Team completes Phase 1 and Phase 2 together.
2. Once Phase 2 is done:
   - Developer A: User Story 1 + User Story 2
   - Developer B: User Story 3 + User Story 4
   - Developer C: User Story 5 + User Story 6
3. Stories complete and integrate independently.

---

## Notes

- [P] tasks = different files, no dependencies.
- [Story] label maps each task to its user story for traceability.
- Each user story should be independently completable and testable.
- Run `swift test` after each story to catch regressions early.
- Stop at any checkpoint to validate a story independently.
- Avoid cross-story file conflicts; coordinate on shared files like `DictationController.swift`.
