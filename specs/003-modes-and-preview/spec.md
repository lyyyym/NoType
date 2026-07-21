# Feature Specification: NoType V3 - Polishing Modes & Preview Before Injection

**Feature Branch**: `003-modes-and-preview`

**Created**: 2026-07-21

**Status**: Draft

**Input**: User description: "NoType V3 多模式与注入前预览：在 V2 可配置日常工具基础上，新增多套「润色模式」，每套模式绑定独立的全局快捷键，并拥有自己的润色 prompt 与目标语言/风格（例如：日常口语润色、翻译模式说中文出英文、正式书面/邮件风格）。用户可在设置窗口中新增、编辑、删除模式并配置其快捷键。同时新增「注入前预览」功能：松开快捷键完成润色后，先弹出一个可编辑的预览小窗展示润色结果，用户确认后再注入光标处，或修改后注入，或取消放弃。预览为可选行为，可在设置中开关。保持 macOS 首平台、系统托盘常驻、录音悬浮气泡、历史记录、字数统计、个人词典等 V2 现有能力不变。"

## Clarifications

### Session 2026-07-21

- Q: 开启预览后预览窗会抢占键盘焦点，确认时文本应注入到哪里？ → A: 回到「开始录音时最前台的 App」注入——确认时先重新激活该 App，再注入，从而保留用户原本的打字目标。
- Q: 「注入前预览」开关的默认值是开还是关？ → A: 默认关闭，保留 V2 的即时注入体验；需要预览的用户在设置中自行开启。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Multiple Polishing Modes via Dedicated Shortcuts (Priority: P1)

As a daily user, I want several "modes", each bound to its own global shortcut, so that I can choose how my speech is processed by which key I hold — everyday spoken polish with one shortcut, translate-to-English with another, formal email style with a third — without digging through menus each time.

**Why this priority**: This is the headline capability of V3. It transforms NoType from a single-style tool into a multi-purpose input surface while keeping the friction-free "hold a key, speak, release" interaction. It must work out of the box with sensible defaults.

**Independent Test**: Launch the app, hold one mode's shortcut and speak, confirm the output matches that mode's style; hold a different mode's shortcut, speak the same words, confirm the output reflects the other mode's style. Delivers value with zero configuration thanks to shipped defaults.

**Acceptance Scenarios**:

1. **Given** the app is running with default modes, **When** the user holds the "Everyday polish" shortcut and speaks a casual sentence, **Then** the injected text is a cleaned-up, natural version of the speech.
2. **Given** the app is running, **When** the user holds the "Translate to English" shortcut and speaks in Chinese, **Then** the injected text is an English translation of the speech.
3. **Given** the app is running, **When** the user holds the "Formal / email" shortcut and speaks a rough message, **Then** the injected text is a polished, formally-worded version.
4. **Given** two distinct modes exist, **When** the user speaks the identical phrase through each mode's shortcut, **Then** the two injected outputs differ according to each mode's style.

---

### User Story 2 - Preview Before Injection (Priority: P1)

As a user, after I release the shortcut and the speech is processed, I want an editable preview of the result before it is typed into my document, so that I can confirm it, fix a misheard word, or cancel and discard it entirely rather than having to undo an injection gone wrong.

**Why this priority**: This is the second headline capability of V3 and is especially valuable for longer sentences and translation, where an unreviewed mistake is costly to undo. It is orthogonal to modes: it works whether one mode or many exist, and can be used independently. It is a global, optional behavior.

**Independent Test**: Enable preview in settings, hold a shortcut and speak, confirm the preview window appears with the processed text, edit it, confirm, and verify the edited text is what gets injected; then trigger it again and cancel to confirm nothing is injected.

**Acceptance Scenarios**:

1. **Given** preview is enabled, **When** the user releases the shortcut after a successful recognition, **Then** an editable preview window appears showing the processed text before anything is injected.
2. **Given** the preview window is open, **When** the user edits the text and confirms, **Then** the edited text is injected into the app that was frontmost when recording began.
3. **Given** the preview window is open, **When** the user cancels, **Then** nothing is injected and the window closes.
4. **Given** the preview window is open, **When** the user confirms without editing, **Then** the processed text is injected as-is into the app that was frontmost when recording began.
5. **Given** preview is disabled, **When** the user releases the shortcut, **Then** the text is injected immediately, identical to V2 behavior.

---

### User Story 3 - Manage Modes in Settings (Priority: P2)

As a power user, I want to create, edit, and delete polishing modes and assign each its own global shortcut from the settings window, so that I can tailor the set of modes to my own workflow and languages.

**Why this priority**: Default modes make the app fully usable without this, so it is a refinement rather than a blocker. It unlocks long-term value and personalization once the core experience works.

**Independent Test**: Open settings, create a new mode with a name, an unused shortcut, and a custom instruction; save; use the new shortcut to record and confirm the output follows the custom instruction; then edit the mode's instruction, use it again, and confirm the output changed; finally delete it and confirm its shortcut no longer triggers.

**Acceptance Scenarios**:

1. **Given** the settings window is open, **When** the user creates a new mode with a unique shortcut and saves, **Then** the mode appears in the list and its shortcut becomes active immediately.
2. **Given** an existing mode, **When** the user edits its instruction and saves, **Then** subsequent uses of that mode apply the new instruction.
3. **Given** an existing mode, **When** the user deletes it, **Then** its shortcut no longer triggers and the mode is removed from the list.
4. **Given** a new mode is being created, **When** the user assigns a shortcut already used by another mode, **Then** the system prevents saving and shows a clear conflict message.

---

### Edge Cases

- What happens when two modes are assigned the same shortcut? The system must reject it and inform the user.
- What happens when the user deletes the last remaining mode? At least one mode must be retained; deletion is refused or a default is re-seeded, and the user is informed.
- What happens when a mode's polishing instruction is left empty? Processing falls back to the raw recognized transcript (no polishing), so the mode still functions as plain dictation.
- What happens when the preview window is open and the user triggers a new recording? The in-flight preview is finalized or discarded deterministically before the new recording begins; no two previews coexist.
- What happens when recognition returns empty (no speech captured)? The system reports the error as in V2 and never opens the preview window.
- What happens when the user switches focus away from the target app while the preview is open? The preview remains editable; on confirm, NoType re-activates the app that was frontmost when recording started and injects there, preserving the original target even though the preview took keyboard focus.
- What happens when a mode's assigned shortcut conflicts with a system-wide or third-app shortcut? Handled the same way as the V2 shortcut conflict: the system cannot always detect external conflicts, so the user is responsible for choosing a free combination.
- What happens to existing V2 users on first launch of V3? Their previously configured shortcut and the built-in polish style are preserved by migrating them into a default mode; default behavior does not change.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support multiple polishing modes, where each mode carries a display name, a polishing instruction (the style/language guidance applied after recognition), and an optional target output language.
- **FR-002**: System MUST bind each mode to its own dedicated global shortcut; pressing a mode's shortcut records audio and processes it using that mode's instruction.
- **FR-003**: System MUST ship with a sensible set of default modes (everyday spoken polish, translate-to-English, formal/email style) so the feature is usable immediately without configuration.
- **FR-004**: System MUST preserve existing V2 behavior on upgrade by migrating the previously configured shortcut and the built-in polish instruction into a default mode on first launch of V3.
- **FR-005**: Users MUST be able to create, edit, and delete modes from the settings window, and assign each mode a global shortcut.
- **FR-006**: System MUST prevent two modes from sharing the same global shortcut and surface a clear, specific conflict message when it occurs.
- **FR-007**: System MUST require each mode to have a non-empty name and a shortcut; the polishing instruction MAY be empty, in which case the raw transcript is used as-is.
- **FR-008**: System MUST persist the mode list locally so it survives app restarts.
- **FR-009**: When "preview before injection" is enabled, the system MUST present an editable preview of the processed text after recognition/polishing and before injecting.
- **FR-010**: From the preview, the user MUST be able to (a) confirm to inject the text as-is, (b) edit the text and then inject, or (c) cancel to discard without injecting.
- **FR-011**: When "preview before injection" is disabled, the system MUST inject the text immediately after processing, identical to V2 behavior.
- **FR-012**: The "preview before injection" setting MUST be toggleable from the settings window and take effect immediately without restarting the app.
- **FR-013**: History, word-count statistics, and the personal dictionary MUST continue to operate on the final injected text, regardless of which mode was used or whether preview was involved.
- **FR-014**: The personal dictionary hint MUST be applied during polishing for every mode, including default and user-created modes.
- **FR-015**: System MUST keep all V2 features (onboarding, settings window, history, statistics, dictionary, floating recording bubble, menu-bar presence) fully functional.
- **FR-016**: When preview is confirmed or cancelled, and when a mode is used, the recording session MUST be reset so the same shortcut can be used again immediately, consistent with the V2 reuse behavior.
- **FR-017**: When preview before injection is enabled, the system MUST capture the frontmost application at the moment recording starts and, on confirm, re-activate that application before injecting, so the text lands where the user was originally typing despite the preview window having taken keyboard focus.

### Key Entities *(include if feature involves data)*

- **PolishingMode**: A named, user-configurable processing profile. Key attributes: unique identifier, display name, global shortcut, polishing instruction (style/language guidance text), optional target output language, and a flag indicating whether it is a built-in default. Belongs to the mode collection.
- **Mode Collection**: The ordered set of all polishing modes. Operations: add, update, delete (subject to the minimum-one-mode rule and shortcut uniqueness), and lookup of the mode bound to a given shortcut.
- **Preview Session**: A transient (non-persisted) state representing the processed text awaiting the user's decision. Resolved by confirm (possibly after edits) or cancel.
- **Configuration (extension)**: Gains a "preview before injection" toggle. The existing single shortcut field is superseded by per-mode shortcuts carried in the mode collection; backward compatibility with the prior single-shortcut field is handled via migration.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can obtain two appropriately different outputs from the same spoken phrase within a single session by holding two different mode shortcuts, without any settings changes.
- **SC-002**: A user can create a new custom mode and successfully use it to produce tailored output in under 30 seconds using only the settings window.
- **SC-003**: When preview is enabled, a user can review, edit, and confirm injection of a typical sentence in under 5 seconds.
- **SC-004**: 100% of existing V2 capabilities — onboarding, settings, history, statistics, personal dictionary, floating bubble, menu-bar presence — continue to work unchanged.
- **SC-005**: An existing V2 user perceives no change in default behavior on first launch of V3: their prior shortcut still triggers, and their prior polish style is preserved as a default mode.
- **SC-006**: A user can enable or disable "preview before injection" at any time, and the change takes effect on the very next recording, with no impact on mode behavior.
- **SC-007**: Deleting or editing a mode takes effect immediately; a deleted mode's shortcut no longer triggers within the same session.

## Assumptions

- "Preview before injection" is OFF by default, preserving the instant-injection experience V2 users are accustomed to; users who want review turn it on. (This default can be revisited if the project prefers review-on-by-default.)
- A mode's "polishing instruction" is free-form guidance text supplied by the user (analogous to the built-in polish guidance in V2). An empty instruction means "use the raw transcript verbatim" (plain dictation mode).
- The app ships with three default modes — everyday spoken polish, translate-to-English, and formal/email. Users may delete any of these, but at least one mode must always remain.
- Modes affect only the post-recognition processing (the polishing instruction); they do not change how audio is captured or recognized. Source language is auto-detected by the recognition service, and the instruction steers the output language/style.
- "Preview before injection" is a single global toggle, not a per-mode setting. Per-mode preview control is out of scope for V3.
- Shortcut conflicts with system-wide or third-party application shortcuts are the user's responsibility to avoid, consistent with V2; the system only guarantees uniqueness among its own modes.
- Modes persist locally alongside other user data (no cloud sync), consistent with the local-first principle.

## Out of Scope

- Per-mode preview toggles (preview is global for V3).
- Re-processing the same recording with a different mode from within the preview window.
- Streaming/real-time recognition display during recording.
- Cloud synchronization or sharing of modes across devices.
- Changing the audio capture or recognition engine per mode.
