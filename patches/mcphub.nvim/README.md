# mcphub.nvim patches

Patch files are applied in numeric order by `lazy-local-patcher`.

## 01-codecompanion-v19-compat.patch

- Updates CodeCompanion extension glue for v19 behavior.
- Keeps MCPHub tool/resource/prompt integration stable after upstream API changes.

## 02-env-tool-filters.patch

- Adds env-driven tool filter support (`*_ALLOWED_TOOLS_REGEX`, `*_DENIED_TOOLS_REGEX`, etc.).
- Adds strict hide behavior via `removed_tools` and blocks removed tool execution in mcphub.nvim path.
- Adds UI action key `x` for strict hide toggling in main view tool entries.

## 03-log-dedup-throttle.patch

- Reduces log spam pressure by deduplicating repeated server log entries.
- Throttles UI notification updates to avoid freezes during disconnect/reconnect bursts.

## 04-tool-input-nav-keys.patch

- Adds configurable capability-form navigation keys for tool input fields and submit line.
- Default keys: `<C-j>` next field, `<C-k>` previous field.
- Config path:

```lua
require("mcphub").setup({
  ui = {
    input_navigation = {
      next_field = "<C-j>",
      prev_field = "<C-k>",
    },
  },
})
```

## Validation note

- `04-tool-input-nav-keys.patch` was validated on a clean baseline matching this setup by applying patches `01 -> 02 -> 03` then checking `04` with `git apply --check`.
- `lazy-local-patcher` can show a contradictory notification (`Error applying...` and `Applied ...`) due notifier behavior; use manual `git apply --check` for authoritative validation.
