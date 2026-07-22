# Contract: TOML Configuration (V3)

**Feature**: [spec.md](../spec.md)

This contract documents the V3 additions to `~/.config/notype/config.toml` and the handling of the legacy `[shortcut]` section. It extends the V1 `[shortcut]`, `[asr]`, `[llm]`, and `[ui]` sections; only the V3 deltas are described here. Service sections (`[asr]`, `[llm]`) are unchanged from V1/V2.

## Full shape (V3)

```toml
[shortcut]                       # LEGACY in V3 — read only to bootstrap the default mode
key = "."
modifiers = ["command"]

[asr]
base_url = "https://…/v1"
api_key = "sk-…"
model = "qwen3-asr-flash"

[llm]
base_url = "https://…/v1"
api_key = "sk-…"
model = "deepseek-chat"
temperature = 0.0
max_tokens = 4096

[ui]
show_floating_bubble = true              # V2
bubble_position = "cursor"               # V2 ("cursor" | "menuBar")
show_preview_before_injection = false    # NEW in V3 — default false
```

## V3 additions

### `[ui].show_preview_before_injection`

- **Type**: boolean.
- **Default**: `false`.
- **Effect**: when `true`, after polishing the app shows the editable preview window before injecting (FR-009/FR-010). When `false`, injection is immediate, identical to V2 (FR-011). Changes take effect on the next recording without restart (FR-012).
- **Parsing**: handled by the existing flat key/value reader in `ConfigLoader.buildUI` (same pattern as `show_floating_bubble`). Unknown values fall back to `false`.

## `[shortcut]` — legacy / migration

- In V3, **active shortcuts come from `modes.json`** (see [polish-modes.md](polish-modes.md)), not from `[shortcut]`.
- `[shortcut]` is read **only** when seeding default modes on first launch (no `modes.json`): its `key` + `modifiers` become the "Everyday polish" default mode's shortcut (FR-004, SC-005). If `[shortcut]` is absent, `Command + .` is used.
- Once `modes.json` exists, `[shortcut]` is ignored for shortcut selection. It is **not** deleted or rewritten by the app (no destructive migration); it simply ceases to be authoritative.
- The struct field `Configuration.shortcut` is retained for this bootstrap path and for tests; it is not the runtime source of truth when modes are present.

## Round-trip guarantees

- `ConfigStore.serialize` writes `show_preview_before_injection` alongside the other `[ui]` keys, so saving in the Settings window preserves it.
- All other sections round-trip exactly as in V2.
