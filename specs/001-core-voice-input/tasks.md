# Tasks: NoType V1 Core Voice Input

**Input**: Design documents from `/specs/001-core-voice-input/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize the macOS Xcode project and shared dependencies.

- [x] T001 Create Xcode project `NoType/NoType.xcodeproj` with a single macOS App target named `NoType`
- [x] T002 Add `TOMLKit` (or equivalent) Swift package dependency to the Xcode project
- [x] T003 Configure `NoType/NoType/Info.plist` with `NSMicrophoneUsageDescription` and required background modes for menu-bar app
- [x] T004 Add `NoType/README.md` with build instructions and a link to [quickstart.md](quickstart.md)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T005 [P] Create `NoType/NoType/Config/Config.swift` defining the `Configuration` struct matching the TOML schema in [contracts/config-toml.md](contracts/config-toml.md)
- [x] T006 [P] Create `NoType/NoType/Config/ConfigLoader.swift` to load and validate `~/.config/notype/config.toml`
- [x] T007 [P] Create `NoType/NoType/Models/AudioBuffer.swift` with PCM append and WAV generation
- [x] T008 [P] Create `NoType/NoType/Models/RecordingSession.swift` with the state machine defined in [data-model.md](data-model.md)
- [x] T009 [P] Create `NoType/NoType/Transcription/ASRClient.swift` to POST WAV audio to `{asr.base_url}/audio/transcriptions`
- [x] T010 [P] Create `NoType/NoType/Transcription/LLMClient.swift` to POST the raw transcript to `{llm.base_url}/chat/completions`
- [x] T011 [P] Create `NoType/NoType/Transcription/PolishPrompt.swift` to build the system prompt for text polishing
- [x] T012 [P] Create `NoType/NoType/Input/KeyboardInjector.swift` with a `inject(text:)` method using `CGEventPost`
- [x] T013 Create `NoType/NoType/Models/RecordingError.swift` defining typed errors for config, audio, ASR, LLM, and injection failures

**Checkpoint**: Foundation ready — user story implementation can now begin.

---

## Phase 3: User Story 1 - Dictate Anywhere with a Global Shortcut (Priority: P1) 🎯 MVP

**Goal**: A user can hold `Command + .`, speak, release, and see polished text inserted at the cursor in any macOS app.

**Independent Test**: Open Notes, hold the shortcut, speak a sentence, release, and verify the text appears within 8 seconds.

### Implementation for User Story 1

- [x] T014 [US1] Implement `NoType/NoType/Input/GlobalShortcut.swift` using `NSEvent.addGlobalMonitorForEvents` for press-and-hold semantics
- [x] T015 [US1] Implement `NoType/NoType/Audio/AudioRecorder.swift` using `AVAudioEngine` to stream PCM into `AudioBuffer`
- [x] T016 [US1] Implement `NoType/NoType/Audio/AudioRecorder.swift` 60-second auto-stop behavior (FR-014)
- [x] T017 [US1] Create `NoType/NoType/App/DictationController.swift` to orchestrate shortcut → record → ASR → LLM → inject
- [x] T018 [US1] Add LLM fallback logic in `DictationController` so raw ASR text is injected when LLM fails or times out (FR-013)
- [x] T019 [US1] Handle empty audio and ASR errors in `DictationController` without crashing (FR-009)
- [x] T020 [US1] Ensure audio buffer is discarded after transcription/injection (FR-012)

**Checkpoint**: User Story 1 is fully functional and testable independently.

---

## Phase 4: User Story 2 - Configure Services via a Local File (Priority: P2)

**Goal**: Users can override the global shortcut, ASR endpoint, and LLM endpoint through `~/.config/notype/config.toml`.

**Independent Test**: Edit `config.toml` with custom shortcut and endpoints, restart the app, and verify the new shortcut and endpoints are used.

### Implementation for User Story 2

- [x] T021 [US2] Validate `Configuration` parsing against the schema in [contracts/config-toml.md](contracts/config-toml.md)
- [x] T022 [US2] Wire `GlobalShortcut` to read `shortcut.key` and `shortcut.modifiers` from `Configuration`
- [x] T023 [US2] Wire `ASRClient` to read `asr.base_url`, `asr.api_key`, and `asr.model` from `Configuration`
- [x] T024 [US2] Wire `LLMClient` to read `llm.base_url`, `llm.api_key`, `llm.model`, `llm.temperature`, and `llm.max_tokens` from `Configuration`
- [x] T025 [US2] Document in `NoType/README.md` that config changes require an app restart

**Checkpoint**: User Stories 1 and 2 both work independently.

---

## Phase 5: User Story 3 - Clear Recording Feedback (Priority: P3)

**Goal**: The macOS menu-bar icon clearly shows recording, processing, and completion states.

**Independent Test**: Trigger the shortcut and observe the menu-bar icon change to recording state, then back to idle with a brief completion signal.

### Implementation for User Story 3

- [x] T026 [US3] Implement `NoType/NoType/App/StatusBarController.swift` with `NSStatusItem` and a basic menu
- [x] T027 [US3] Add menu-bar icons/assets for idle, recording, processing, success, and error states
- [x] T028 [US3] Update `StatusBarController` in response to `RecordingSession` state changes
- [x] T029 [US3] Show a brief success/error indicator in the menu bar after text injection completes or fails
- [x] T030 [US3] Add "Quit NoType" and "Open config folder" menu items

**Checkpoint**: All user stories are independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Error handling, testing, and validation across all stories.

- [x] T031 [P] Add unit tests in `NoType/NoTypeTests/ConfigLoaderTests.swift` for valid/invalid TOML parsing
- [x] T032 [P] Add unit tests in `NoType/NoTypeTests/AudioBufferTests.swift` for WAV header generation
- [x] T033 [P] Add unit tests in `NoType/NoTypeTests/KeyboardInjectorTests.swift` for Unicode string splitting
- [x] T034 [P] Add unit tests in `NoType/NoTypeTests/PolishPromptTests.swift` for prompt formatting
- [x] T035 Add runtime permission prompts in `NoType/NoType/App/StatusBarController.swift` for microphone and accessibility when missing
- [ ] T036 Run all validation scenarios from [quickstart.md](quickstart.md) and record results
- [x] T037 Code cleanup: remove unused imports, unify error messages, and add inline documentation where non-obvious

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories.
- **User Stories (Phase 3–5)**: All depend on Foundational phase completion.
  - User stories can then proceed in parallel if staffed.
  - Or sequentially in priority order: P1 → P2 → P3.
- **Polish (Phase 6)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Starts after Foundational phase. No dependencies on other stories. This is the MVP scope.
- **User Story 2 (P2)**: Starts after Foundational phase. Extends US1 with configuration wiring; independently testable.
- **User Story 3 (P3)**: Starts after Foundational phase. Adds UI feedback; independently testable.

### Within Each User Story

- Models/services before controller/UI wiring.
- Core implementation before error handling polish.
- Story complete before moving to the next priority.

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel.
- All Foundational model/client tasks marked [P] can run in parallel.
- The three user stories can be worked on in parallel once Foundational is done.
- Polish-phase unit tests marked [P] can run in parallel.

---

## Parallel Example: User Story 1

```bash
# Launch all foundational model/client tasks together:
Task: "Create NoType/NoType/Config/Config.swift"
Task: "Create NoType/NoType/Models/AudioBuffer.swift"
Task: "Create NoType/NoType/Transcription/ASRClient.swift"
Task: "Create NoType/NoType/Transcription/LLMClient.swift"
Task: "Create NoType/NoType/Input/KeyboardInjector.swift"

# Then wire the dictation controller:
Task: "Create NoType/NoType/App/DictationController.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational.
3. Complete Phase 3: User Story 1.
4. **STOP and VALIDATE**: Test User Story 1 independently using [quickstart.md](quickstart.md).
5. Demo the MVP.

### Incremental Delivery

1. Setup + Foundational → Foundation ready.
2. User Story 1 → Test independently → MVP demo.
3. User Story 2 → Test independently → Configurable MVP.
4. User Story 3 → Test independently → Polished MVP.
5. Polish phase → Final validation.

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together.
2. Once Foundational is done:
   - Developer A: User Story 1
   - Developer B: User Story 2
   - Developer C: User Story 3
3. Each story integrates independently into the shared controller.

---

## Notes

- [P] tasks = different files, no dependencies.
- [Story] label maps a task to a specific user story for traceability.
- Each user story should be independently completable and testable.
- Commit after each task or logical group.
- Stop at any checkpoint to validate a story independently.
- Avoid vague tasks, same-file conflicts, and cross-story dependencies that break independence.
