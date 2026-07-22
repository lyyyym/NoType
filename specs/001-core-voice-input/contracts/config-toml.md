# Contract: TOML Configuration Schema

**File**: `~/.config/notype/config.toml`

## Purpose

Defines the structure and valid values for the local configuration file read at application startup.

## Schema

```toml
[shortcut]
key = "."              # Single character or named key
modifiers = ["command"] # Array of modifier names

[asr]
base_url = "https://api.example.com/v1"
api_key = "sk-..."
model = "qwen-asr-flash"

[llm]
base_url = "https://api.example.com/v1"
api_key = "sk-..."
model = "gpt-4o-mini"
temperature = 0.0
max_tokens = 4096
```

## Field Rules

- `shortcut.key`: single Unicode character or a named key (e.g., `"period"`, `"f12"`). Default is `"."`.
- `shortcut.modifiers`: each element must be one of `command`, `option`, `control`, `shift`. Default is `["command"]`.
- `asr.base_url` and `llm.base_url`: valid HTTPS URL strings; must not contain a trailing `/` that would produce `//v1/...` when appended.
- `asr.api_key` and `llm.api_key`: non-empty strings.
- `llm.temperature`: optional, numeric, 0.0–2.0. Default `0.0`.
- `llm.max_tokens`: optional, integer > 0. Default `4096`.

## Lifecycle

- The app reads the file once at startup.
- Changes require an application restart to take effect.
- If the file is missing or invalid, the app shows a menu-bar error and exits.
