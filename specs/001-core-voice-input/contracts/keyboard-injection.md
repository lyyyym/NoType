# Contract: Keyboard Injection

## Purpose

Define how the system delivers final text into the currently focused application.

## Behavior

- The system simulates keystrokes using macOS `CGEventPost`.
- For ASCII text, virtual key codes are generated from a US keyboard layout.
- For non-ASCII text (e.g., Chinese), the system uses `CGEvent.keyboardSetUnicodeString` to inject whole characters directly.
- Keystrokes are posted to the HID event tap (`CGEventTapLocation.cghidEventTap`), so they go to the frontmost application.

## Pre-conditions

- The app must have Accessibility permission.
- The target application must be the frontmost app at the time of injection.

## Post-conditions

- The final text appears at the current cursor position, if the focused field accepts keyboard input.
- If no editable field is focused, the keystrokes are silently ignored by the target app.

## Error Handling

- If Accessibility permission is missing, the app shows a menu-bar alert and does not attempt injection.
- Injection errors are logged but do not crash the app.

## Example

Injecting "Hello, 世界" produces a sequence of events:
1. `H`, `e`, `l`, `l`, `o`, `,`, ` ` via key-down/key-up events.
2. The Unicode string "世界" injected as a single key event.
