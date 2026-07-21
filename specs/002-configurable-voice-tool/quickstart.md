# Quickstart Validation Guide: NoType V2 - Configurable Voice Tool

**Feature**: [spec.md](../spec.md)
**Plan**: [plan.md](../plan.md)
**Data Model**: [data-model.md](../data-model.md)

This guide provides runnable validation scenarios for the V2 feature. It assumes the repository is already cloned and the development environment is the same as V1 (macOS, Swift Package Manager, Xcode Command Line Tools).

## Prerequisites

- macOS 14 or later
- Xcode Command Line Tools installed (`xcode-select --install` if needed)
- Swift 6.0 toolchain available
- A valid `~/.config/notype/config.toml` with ASR and LLM credentials
- Accessibility permission granted to the development environment or terminal for testing keyboard injection

## Build and Run

```bash
cd /Users/yiming/Documents/learn-speckit/NoType
swift build
swift test
swift run NoType
```

`swift run NoType` launches the menu-bar app. Keep the terminal visible to read logs.

## Validation Scenarios

### 1. First-Launch Onboarding

**Setup**: Remove the onboarding state file to simulate a fresh install:

```bash
rm ~/Library/Application\ Support/NoType/onboarding.json
```

**Steps**:
1. Run `swift run NoType`.
2. Confirm the onboarding wizard appears before the menu bar shows the active state.
3. Step through microphone permission, accessibility permission, and basic configuration.
4. Save the configuration.
5. Confirm the wizard closes and the menu-bar icon appears.

**Expected outcome**: A new `onboarding.json` is created with `hasCompletedOnboarding: true`. The core voice input flow works after onboarding.

### 2. Settings Window

**Steps**:
1. Click the menu-bar icon and select **Settings**.
2. Change the global shortcut (e.g., from `command + .` to `command + /`).
3. Change the floating bubble toggle.
4. Save the settings window.
5. Close the settings window.

**Expected outcome**: `~/.config/notype/config.toml` reflects the new shortcut and bubble setting. The new shortcut starts/stops recording. The old shortcut no longer triggers.

### 3. Recording History

**Steps**:
1. Perform 3 voice inputs using the shortcut.
2. Click the menu-bar icon and select **History**.
3. Verify the 3 entries appear in reverse chronological order.
4. Select one entry and click **Copy**.
5. Paste into a text editor and confirm it matches the polished text.
6. Delete one entry and confirm the list updates.

**Expected outcome**: History window shows raw transcript, polished text, timestamp, and word count for each entry. Copy puts the polished text on the clipboard. Deletion removes the entry.

### 4. Word Count Statistics

**Steps**:
1. Note the current daily and cumulative counts from the **Stats** menu item.
2. Record a phrase of approximately 10 words/characters.
3. Check the stats again.
4. Delete the newest history entry.
5. Check the stats again.

**Expected outcome**: Both daily and cumulative counts increase by the word count of the new phrase. After deletion, both decrease by the same amount, clamped at 0.

### 5. Personal Dictionary

**Steps**:
1. Open **Dictionary** from the menu bar.
2. Add a term that the ASR often misrecognizes (e.g., a technical term or name).
3. Add an optional hint describing the preferred spelling.
4. Save the dictionary.
5. Record a phrase containing that term.

**Expected outcome**: The injected text uses the preferred form from the dictionary more consistently than without it. The dictionary persists across app restarts.

### 6. Floating Recording Bubble

**Steps**:
1. Enable the floating bubble in **Settings**.
2. Hold the global shortcut.
3. Confirm a small bubble appears near the cursor or menu bar.
4. Release the shortcut.
5. Confirm the bubble disappears.

**Expected outcome**: Bubble appears within 200ms of pressing the shortcut and disappears within 200ms of release.

### 7. Core Voice Input Regression

**Steps**:
1. Focus any text editor.
2. Hold the shortcut and speak.
3. Release the shortcut.

**Expected outcome**: The ASR recognizes the speech, the LLM polishes it, and the final text is injected at the cursor position. This matches V1 behavior.

## Automated Test Commands

Run the unit test suite after any implementation change:

```bash
swift test
```

New V2 test targets should be added for:
- `HistoryStore` eviction and persistence
- `StatsStore` daily reset and cumulative totals
- `DictionaryStore` add/update/delete uniqueness
- Word counting for mixed CJK/Latin text
- `Configuration` round-trip through TOML

## Troubleshooting

- **Onboarding does not appear**: Delete `~/Library/Application Support/NoType/onboarding.json` and restart.
- **Settings not saved**: Verify write permissions for `~/.config/notype/config.toml`.
- **History empty after restart**: Check that `~/Library/Application Support/NoType/history.json` exists and is valid JSON.
- **Bubble not visible**: Confirm `showFloatingBubble` is true in settings and the app has Accessibility permission.
- **Dictionary not improving recognition**: Verify the term is saved and the LLM polish prompt includes the dictionary hint block.

## Notes

- All local data files live in `~/Library/Application Support/NoType/`.
- Configuration remains in `~/.config/notype/config.toml`.
- No cloud services are involved in V2 local features.
