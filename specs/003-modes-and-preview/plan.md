# Implementation Plan: NoType V3 - Polishing Modes & Preview Before Injection

**Branch**: `003-modes-and-preview` | **Date**: 2026-07-21 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-modes-and-preview/spec.md`

## Summary

NoType V3 turns the single-style dictation tool into a multi-purpose input surface and adds an optional review step. Two headline capabilities are added on top of the unchanged V2 pipeline (hold shortcut → record → ASR → LLM polish → inject):

1. **Polishing modes**: several named modes, each with its own global shortcut and its own polishing instruction / output language (e.g. everyday polish, translate-to-English, formal/email). The app ships with sensible defaults and lets users create, edit, and delete modes in the Settings window.
2. **Preview before injection**: an optional, globally-toggleable editable preview window shown after polishing. The user confirms (inject as-is), edits then injects, or cancels. Because the preview window must take keyboard focus, NoType captures the frontmost app when recording starts and re-activates it on confirm before injecting.

Modes are stored as local user data (`modes.json` under Application Support), consistent with V2's history/dictionary pattern; the preview toggle is a simple setting in the existing TOML config. The V2 single shortcut and built-in polish prompt are migrated into a default mode so existing users see no behavior change.

## Technical Context

**Language/Version**: Swift 5 language mode (SPM tools version 6.0, `swiftLanguageMode(.v5)`)

**Primary Dependencies**: AppKit, AVFoundation, Carbon.HIToolbox, CoreGraphics, Foundation, swift-testing

**Storage**: Local JSON files in `~/Library/Application Support/NoType/` for modes (new), history, statistics, dictionary, onboarding state; TOML at `~/.config/notype/config.toml` for service config and UI toggles (gains the preview toggle).

**Testing**: swift-testing (`@Suite` / `@Test` / `#expect`)

**Target Platform**: macOS 14+ (Apple Silicon and Intel)

**Project Type**: Desktop menu-bar application

**Performance Goals**: Existing V2 targets retained (settings window < 500ms open, bubble < 200ms appear). New: preview window appears within 200ms of polish completion; re-activating the target app and injecting on confirm completes within 500ms for a typical sentence.

**Constraints**: Requires Accessibility permission (global shortcut monitoring + keyboard injection + app activation); requires Microphone permission; no cloud storage; modes and preview are local-only.

**Scale/Scope**: Single-user, local-first; mode count expected to stay small (single digits, bounded by available free global shortcuts); history capped at 50; dictionary/stats small.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution: [`.specify/memory/constitution.md`](../../../../.specify/memory/constitution.md), supported by [code-style.md](../../../../docs/code-style.md) and [directory-structure.md](../../../../docs/directory-structure.md).

- **I. Spec-Driven**: Spec, plan, tasks live under `NoType/specs/003-modes-and-preview/`. ✅ Pass.
- **II. Layered Architecture**: New files respect the dependency direction — `PolishingMode` (Models) ← `ModeStore` (Persistence) ← `GlobalShortcut` multi-match (Input) / `PolishPrompt` mode-aware (Transcription) / `PreviewWindowController` (UI) / `DictationController` orchestration (App). No upward dependency from Models. ✅ Pass.
- **III. Consistent Style**: New code follows code-style.md — value types for models (`struct PolishingMode`), `final class` for stores/controllers, `@MainActor` for AppKit/CGEvent drivers, `[Module]` log prefixes, initializer DI with defaults, `// MARK: -` sections, `///` doc comments. ✅ Pass.
- **IV. Test Coverage**: New logic is unit-testable in isolation — `ModeStore` CRUD + uniqueness + min-one, `GlobalShortcut` per-mode matching (pure matching helpers), `PolishPrompt` mode-aware message composition, preview confirm/cancel/edit state, TOML preview-toggle round-trip. ✅ Pass.
- **V. Graceful Degradation**: Empty mode instruction → raw transcript (plain dictation); LLM failure → raw transcript fallback (unchanged); preview cancel → no injection, no history/stats; target app gone on confirm → inject into current frontmost with a logged warning. ✅ Pass.

**Result**: Pass. No gate violations; no Complexity Tracking entries needed.

## Project Structure

### Documentation (this feature)

```text
specs/003-modes-and-preview/
├── plan.md              # This file (/speckit-plan output)
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── config-toml.md       # V3 config additions + [shortcut] migration
│   └── polish-modes.md      # Mode entity, shortcut→mode binding, prompt composition
└── tasks.md             # Phase 2 output (/speckit-tasks - NOT created here)
```

### Source Code (repository root = `NoType/`)

```text
NoType/
├── Package.swift                 # unchanged
├── README.md                     # updated for V3
└── NoType/
    ├── App/
    │   ├── AppDelegate.swift             # wires ModeStore, multiple shortcuts, preview
    │   ├── DictationController.swift     # mode-aware flow + preview gate + target capture
    │   └── ... (unchanged V2 files)
    ├── Models/
    │   ├── PolishingMode.swift           # NEW: mode entity
    │   ├── Configuration.swift           # EXTEND: showPreviewBeforeInjection
    │   └── ...
    ├── Config/
    │   ├── Config.swift                  # (alias/bridge; Configuration lives in Models)
    │   └── ConfigLoader.swift            # EXTEND: parse [ui].show_preview_before_injection
    ├── Persistence/
    │   ├── ModeStore.swift               # NEW: modes.json CRUD + uniqueness + migration seed
    │   ├── ConfigStore.swift             # EXTEND: serialize preview toggle
    │   └── ...
    ├── Input/
    │   ├── GlobalShortcut.swift          # EXTEND: match N shortcuts, report matched id
    │   ├── KeyboardInjector.swift        # unchanged (inject already targets frontmost)
    │   └── FrontmostApp.swift            # NEW: capture/restore frontmost app helper
    ├── Transcription/
    │   ├── PolishPrompt.swift            # EXTEND: mode-aware system instruction
    │   ├── LLMClient.swift               # EXTEND: accept per-call system instruction
    │   └── ...
    └── UI/
        ├── PreviewWindowController.swift # NEW: editable preview panel
        ├── SettingsWindowController.swift# EXTEND: modes management section + preview toggle
        ├── ModeEditorView.swift          # NEW: reusable add/edit mode form
        └── ...
NoTypeTests/
├── ModeStoreTests.swift                 # NEW
├── GlobalShortcutMatchingTests.swift    # NEW (pure matching helpers)
├── PolishPromptModeTests.swift          # NEW
├── PreviewWindowControllerTests.swift   # NEW (state transitions)
├── ConfigStoreTests.swift               # EXTEND: preview toggle round-trip
└── ...
```

**Structure Decision**: Keep the existing SPM + layered layout. Modes are a user-data collection, so they follow the V2 history/dictionary pattern: a `Model` + a `Persistence` store backed by `JSONFileStore`, surfaced through a Settings UI section and a reusable form view. The preview toggle is a simple boolean setting, so it extends the existing TOML `[ui]` section. `GlobalShortcut` is generalized from one configuration to a set of (mode-id → shortcut) bindings behind a single global event monitor. No new dependencies, no new frameworks.

## Complexity Tracking

No constitution violations. (Empty.)
