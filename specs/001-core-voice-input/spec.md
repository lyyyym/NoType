# Feature Specification: NoType V1 Core Voice Input

**Feature Branch**: `[001-core-voice-input]`

**Created**: 2026-07-21

**Status**: Draft

**Input**: User description: "NoType V1 核心语音输入：按住全局快捷键录音，用 OpenAI 兼容 API 识别,模型使用qwen-asr-flash，再经 OpenAI 兼容 LLM 润色，最终通过模拟键盘输入注入当前光标位置。MVP 只支持 macOS，配置先用本地 TOML 文件，不做设置窗口 UI。"

## Clarifications

### Session 2026-07-21

- **Q**: TOML 配置文件应存放在哪里？API 凭据如何存储？ **→ A**: 配置文件位于 `~/.config/notype/config.toml`，API 凭据以明文写入该文件（MVP 优先可用性，用户自行保管）。
- **Q**: LLM 润色失败时应该如何处理？ **→ A**: 如果 LLM 服务不可用或返回错误，系统应将原始 ASR 文本直接注入光标位置，不额外提示用户，以保证语音输入的核心流程可用。
- **Q**: 最大录音时长是多少？超过后如何处理？ **→ A**: 单次录音最长 60 秒，超过后自动停止录音并继续完成识别与注入流程。
- **Q**: 录音状态反馈应采用什么形式？ **→ A**: 通过 macOS 菜单栏图标状态变化反馈：按住快捷键时显示录音状态，松开后恢复，完成注入后短暂显示完成标记。
- **Q**: 运行时修改 TOML 配置后是否需要热重载？ **→ A**: 不需要。应用在启动时读取一次配置，修改后需要重启应用才能生效。

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Dictate Anywhere with a Global Shortcut (Priority: P1)

As a user, I want to hold a global shortcut anywhere on macOS, speak naturally, and have the final polished text inserted at my current cursor position so that I can enter text faster without switching apps or touching the keyboard.

**Why this priority**: This is the core value proposition of NoType. If this flow works, the product is viable as an MVP.

**Independent Test**: A user can open any text field in any macOS app, hold the configured shortcut, speak a sentence, release the shortcut, and see the sentence appear as polished text at the cursor.

**Acceptance Scenarios**:

1. **Given** the app is running and the cursor is in a text field, **When** the user holds the global shortcut, speaks clearly, and releases the shortcut, **Then** the polished text appears at the cursor within a few seconds.
2. **Given** the app is running and the user is not in a text field, **When** the user holds the global shortcut, speaks, and releases, **Then** the system still processes the audio but degrades gracefully without injecting unexpected text.

---

### User Story 2 - Configure Services via a Local File (Priority: P2)

As a user, I want to set my ASR and LLM endpoint URLs, credentials, and model choices in a local TOML file so that I can use my own OpenAI-compatible providers without needing a settings window.

**Why this priority**: Service configuration is required for the core flow to function, but it only needs to be set up once. A file-based config is acceptable for the MVP audience.

**Independent Test**: A user can edit a local TOML file with provider details, restart the app, and successfully complete a voice dictation that uses the configured services.

**Acceptance Scenarios**:

1. **Given** the app is closed, **When** the user edits the local TOML config with valid credentials and starts the app, **Then** the next voice dictation uses the configured ASR and LLM endpoints.
2. **Given** the app is running, **When** the user edits the local TOML config and restarts the app, **Then** the next voice dictation uses the updated ASR and LLM endpoints.

---

### User Story 3 - Clear Recording Feedback (Priority: P3)

As a user, I want the macOS menu bar icon to clearly indicate when NoType is recording and when text injection is complete so that I know when my voice is being captured and when it is safe to release the shortcut.

**Why this priority**: Reduces uncertainty during the hold-to-record interaction and prevents truncated or missed audio.

**Independent Test**: A user can trigger the shortcut and immediately see the macOS menu bar icon change to a recording state; when the shortcut is released the icon returns to idle and briefly shows a completion signal after the final text is injected.

**Acceptance Scenarios**:

1. **Given** the app is running, **When** the user presses the global shortcut, **Then** the macOS menu bar icon changes to a recording state.
2. **Given** the app is recording, **When** the user releases the shortcut, **Then** the menu bar icon returns to idle and briefly shows a completion signal after the final text is injected.

---

### Edge Cases

- **Empty audio**: What happens when the user releases the shortcut without speaking or when the microphone picks up no usable audio?
- **No microphone access**: How does the system behave if the microphone is unavailable, muted, or permission was denied?
- **API failure**: How does the system behave when the ASR or LLM endpoint is unreachable, returns an error, or times out? (When the LLM step fails, the system falls back to raw ASR transcription.)
- **Shortcut conflict**: How does the system behave when the configured shortcut is already used by macOS or another app?
- **No text field focused**: What happens when the user triggers dictation while no editable text field has focus?
- **Long dictation**: How does the system handle continuous speech that exceeds 60 seconds or the ASR/LLM context limits? (Recordings are capped at 60 seconds; context limit failures fall back to raw ASR text.)
- **Privacy**: Are recorded audio samples retained locally after the final text is injected?
- **Mixed languages**: How does the system handle speech that switches between multiple languages in one recording?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to trigger voice input by holding a global shortcut.
- **FR-002**: The system MUST record audio continuously while the global shortcut is held.
- **FR-014**: The system MUST automatically stop a recording when it reaches a maximum duration of 60 seconds and proceed with transcription and text insertion.
- **FR-003**: The system MUST stop recording when the user releases the global shortcut.
- **FR-004**: The system MUST convert the recorded audio into raw text using a configured speech recognition service.
- **FR-005**: The system MUST send the raw text to a configured language model service for polishing.
- **FR-006**: The system MUST insert the final polished text at the current cursor position using simulated keyboard input.
- **FR-007**: The system MUST read all configuration from a local TOML file.
- **FR-008**: The system MUST provide a recording indicator via the macOS menu bar icon while audio is being captured, and show a brief completion signal after the final text is inserted.
- **FR-009**: The system MUST handle ASR, LLM, network, and microphone errors gracefully without crashing.
- **FR-013**: The system MUST fall back to inserting the raw ASR transcription when the LLM polishing step fails or times out, so that the core dictation flow remains usable.
- **FR-010**: The system MUST NOT provide a settings window UI in the MVP.
- **FR-011**: The system MUST use `Command + .` (period) as the default global shortcut to trigger recording, while allowing users to override it via the local TOML configuration file.
- **FR-012**: The system MUST discard recorded audio immediately after the transcription and text insertion flow completes; no audio samples are retained on disk by default.

### Key Entities *(include if feature involves data)*

- **Configuration**: The set of user-defined parameters that control the global shortcut, ASR service, LLM service, model selection, and runtime behavior. Persisted in a local TOML file at `~/.config/notype/config.toml`. API credentials are stored in plaintext in this file.
- **Recording Session**: A single voice capture bounded by shortcut press and release, including the raw audio data and its metadata.
- **Raw Transcription**: The unpolished text output produced by the speech recognition service.
- **Polished Text**: The final refined text output produced by the language model service, ready for insertion.
- **Cursor Context**: The currently focused editable text field and insertion point where the polished text will be delivered.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can complete a standard voice dictation (10 seconds of speech) and have polished text appear at the cursor within 8 seconds of releasing the shortcut.
- **SC-002**: At least 95% of clearly spoken dictations in the supported language produce a final text that is semantically equivalent to the user's speech.
- **SC-003**: Users can trigger the core flow without switching applications or manually selecting a text field, improving text input speed compared to typing for sentences longer than 15 words.
- **SC-004**: The system remains responsive and does not crash when the microphone is unavailable, the network is disconnected, or the configured service returns an error.
- **SC-005**: The system is installable and usable on macOS without requiring a graphical settings window.

## Assumptions

- **MVP platform**: The first version supports macOS only; cross-platform support is out of scope.
- **Configuration method**: All settings are managed through a local TOML file at `~/.config/notype/config.toml`; API credentials are stored in plaintext. No settings window UI is provided.
- **ASR service**: The speech recognition service is OpenAI-compatible and uses the qwen-asr-flash model by default.
- **LLM service**: The text polishing service is OpenAI-compatible and configured by the user.
- **Text insertion**: The final text is delivered by simulating keyboard input into the currently focused text field.
- **Connectivity**: The system requires internet access to reach the configured ASR and LLM services.
- **Language**: The default behavior is to auto-detect the spoken language and return polished text in the same language as the input.
- **Audio retention**: Recorded audio is discarded immediately after the transcription and text insertion flow completes; no audio samples are retained on disk by default.
- **Configuration reload**: Configuration is read once at application startup. Changes to the TOML file require an application restart to take effect.
- **Global shortcut**: The default trigger is `Command + .` (period); users can override this via the local TOML configuration file.
