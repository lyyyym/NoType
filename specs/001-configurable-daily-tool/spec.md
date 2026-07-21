# Feature Specification: NoType V2 - Configurable Daily Tool

**Feature Branch**: `001-configurable-daily-tool`

**Created**: 2026-07-21

**Status**: Draft

**Input**: User description: "NoType V2 可配置的日常工具：在 V1 核心语音输入基础上，增加完整设置窗口，支持本地历史记录保存（最近 50 条），支持累计字数和今日字数统计。新增首次启动引导流程（麦克风权限、辅助功能权限、基础配置），新增个人词典手动管理。保持 macOS 首平台，系统托盘常驻，录音悬浮气泡。"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Onboarding & Permissions (Priority: P1)

As a first-time user, I want to be guided through granting microphone and accessibility permissions and completing basic configuration so that the app can record and inject text immediately.

**Why this priority**: Without these permissions, the core voice input flow cannot function. Onboarding removes friction and reduces support burden.

**Independent Test**: A fresh install launches the onboarding flow; after completing it, the user can hold the shortcut and inject text into any app.

**Acceptance Scenarios**:

1. **Given** the app has never been launched, **When** the user opens it, **Then** the onboarding window appears with steps for microphone permission, accessibility permission, and basic configuration.
2. **Given** the user has granted both permissions and saved basic settings, **When** they finish onboarding, **Then** the app enters the normal system-tray state and voice input works.
3. **Given** the user denies microphone permission, **When** they try to record, **Then** the app shows a helpful message explaining how to enable it in System Settings.

---

### User Story 2 - Settings Window (Priority: P1)

As a daily user, I want to open a settings window to change shortcuts, ASR/LLM endpoints, and other preferences without editing a configuration file.

**Why this priority**: Moving configuration from a text file to a GUI makes the tool accessible to non-technical users and encourages frequent tuning.

**Independent Test**: A user opens the settings window, changes the global shortcut, and the new shortcut works immediately after saving.

**Acceptance Scenarios**:

1. **Given** the user clicks the settings menu item, **When** the settings window opens, **Then** it displays all current configuration values.
2. **Given** the user modifies the shortcut and service settings, **When** they save the changes, **Then** the settings are persisted and the new shortcut is active.
3. **Given** the user enters invalid values, **When** they try to save, **Then** the window shows validation errors and prevents saving.

---

### User Story 3 - Recording History (Priority: P2)

As a user, I want to view my last 50 voice inputs locally so that I can reuse or reference previous transcriptions.

**Why this priority**: History adds a safety net for accidentally overwritten or lost text and enables reuse of common phrases.

**Independent Test**: A user records several phrases, opens the history window, and sees the last 50 entries in reverse chronological order.

**Acceptance Scenarios**:

1. **Given** the user has completed at least one voice input, **When** they open the history panel, **Then** they see the raw transcript, polished text, and timestamp.
2. **Given** the history contains 50 entries, **When** the user records a 51st entry, **Then** the oldest entry is removed and the new one appears at the top.
3. **Given** the user selects a history entry, **When** they click copy, **Then** the polished text is copied to the clipboard.

---

### User Story 4 - Word Count Statistics (Priority: P2)

As a user, I want to see all-time and today's total word counts so that I can track my daily voice input productivity.

**Why this priority**: Quantified usage feedback increases engagement and helps users build a habit.

**Independent Test**: After recording several phrases, the user opens the stats panel and sees matching totals for today and cumulative.

**Acceptance Scenarios**:

1. **Given** the user has recorded 200 words today, **When** they view the stats, **Then** today's word count shows 200 and cumulative is at least 200.
2. **Given** the date changes to the next day, **When** the user views the stats, **Then** today's count resets to 0 while cumulative remains unchanged.
3. **Given** the user deletes a history entry, **When** they view the stats, **Then** the word counts are updated accordingly.

---

### User Story 5 - Personal Dictionary (Priority: P2)

As a user, I want to manually manage a list of custom words and phrases so that the app correctly recognizes my specialized vocabulary.

**Why this priority**: Domain-specific terms, names, and jargon are often misrecognized by generic ASR. A user-managed dictionary improves accuracy.

**Independent Test**: A user adds a custom phrase to the dictionary, records it, and the final injected text contains the correct phrase.

**Acceptance Scenarios**:

1. **Given** the user is in the dictionary management panel, **When** they add a new term and save, **Then** the term appears in the list and persists across launches.
2. **Given** the user has a term in the dictionary, **When** they edit it, **Then** the updated term is used in subsequent recordings.
3. **Given** the user deletes a term, **When** they record the same phrase, **Then** the term is no longer applied.

---

### User Story 6 - Floating Recording Bubble (Priority: P3)

As a user, I want a small floating bubble to appear while recording so that I have clear visual feedback that the microphone is active.

**Why this priority**: Visual feedback reduces uncertainty and makes the app feel more responsive.

**Independent Test**: A user holds the shortcut; a floating bubble appears; when released, the bubble disappears.

**Acceptance Scenarios**:

1. **Given** the app is running, **When** the user presses the shortcut, **Then** a floating bubble appears near the cursor or menu bar.
2. **Given** the bubble is visible, **When** the user releases the shortcut, **Then** the bubble disappears.
3. **Given** the user disables the bubble in settings, **When** they press the shortcut, **Then** no bubble appears.

### Edge Cases

- What happens when the user denies permissions during onboarding?
- How does the app handle corrupted or unreadable configuration?
- What happens when the history file is corrupted or missing?
- How does the app behave when the user deletes the currently active dictionary entry?
- What happens when the user changes the shortcut while actively recording?
- How does the floating bubble behave on multi-monitor setups?
- What happens when the user attempts to add duplicate entries to the personal dictionary?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST display a first-launch onboarding flow that guides the user through microphone permission, accessibility permission, and basic configuration.
- **FR-002**: The system MUST provide a settings window for viewing and editing all configuration values, including shortcut, ASR/LLM endpoints, and API credentials.
- **FR-003**: The system MUST validate settings input and prevent saving invalid configuration.
- **FR-004**: The system MUST persist configuration changes immediately after saving.
- **FR-005**: The system MUST record each successful voice input into a local history store, retaining the most recent 50 entries.
- **FR-006**: The system MUST allow the user to view, copy, and delete history entries.
- **FR-007**: The system MUST calculate and display the total number of words injected today (daily count).
- **FR-008**: The system MUST calculate and display the cumulative total number of words injected across all time.
- **FR-009**: The system MUST provide a personal dictionary management interface where users can add, edit, and delete custom terms.
- **FR-010**: The system MUST apply personal dictionary entries during the transcription or polish phase to improve recognition accuracy.
- **FR-011**: The system MUST display a floating bubble while recording is active.
- **FR-012**: The system MUST allow the user to enable or disable the floating bubble in settings.
- **FR-013**: The system MUST continue to provide the V1 core voice input flow (shortcut, record, ASR, polish, inject) unchanged.
- **FR-014**: The system MUST remain a macOS menu-bar-only application.

### Key Entities

- **Recording Entry**: A single voice input record, including raw transcript, polished text, timestamp, and word count.
- **History Store**: The local collection of the most recent 50 recording entries, ordered by recency.
- **Word Count Stats**: Daily and cumulative totals derived from the word counts of recording entries.
- **Personal Dictionary Entry**: A user-managed term or phrase, including the original text and target replacement or hint.
- **Configuration**: User preferences including shortcut, ASR/LLM settings, UI toggles, and permission state.
- **Onboarding State**: Tracks which onboarding steps have been completed and whether the flow is active.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A first-time user can complete onboarding and successfully inject text within 3 minutes of launching the app.
- **SC-002**: 90% of settings changes made in the settings window are persisted and active without requiring an app restart.
- **SC-003**: The history store retains the most recent 50 entries and displays them within 1 second of opening the history panel.
- **SC-004**: Daily word count resets at midnight and remains accurate within ±5 words of the actual injected text.
- **SC-005**: Users can add, edit, and delete personal dictionary entries with fewer than 3 clicks per operation.
- **SC-006**: The floating bubble appears within 200ms of pressing the shortcut and disappears within 200ms of releasing it.

## Assumptions

- The primary platform remains macOS; cross-platform support is out of scope for V2.
- "Word count" refers to the number of words in the injected (polished) text, using a language-aware counting method that handles CJK characters correctly.
- Personal dictionary entries are applied as hints or replacements during the polish/transcription phase.
- History and statistics are stored locally only; cloud sync is out of scope.
- The floating bubble is a visual-only indicator and does not intercept input.
- Users are comfortable with native macOS permission dialogs for microphone and accessibility.
- The settings window replaces the configuration file as the primary configuration interface, but the file may still be supported for backward compatibility.
