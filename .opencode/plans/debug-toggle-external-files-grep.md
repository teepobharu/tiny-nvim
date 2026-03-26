---
title: "Debug: toggle_external not affecting files/grep results"
status: "active"
created: 2026-03-25
---

# Debug: toggle_external not affecting files/grep results

## Problem
Pressing `<A-e>` in files/grep picker produces zero visible change — no notification, no title change, no result change. Meanwhile `<A-s>` and `<A-S>` work correctly.

## Diagnostic Patch

Add 2 unconditional `vim.notify` calls to `toggle_external` in `lua/utils/snacks_actions.lua`.

### Location: `lua/utils/snacks_actions.lua`, inside `function M.toggle_external(picker)` (~line 147)

**After line 155** (after `local source = ...`), add:

```lua
  -- DEBUG: unconditional — remove after diagnosis
  vim.notify(string.format("toggle_external: source=%q", source), vim.log.levels.WARN)
```

**After line 163** (after `local chain, _ = get_picker_traversal_state(...)`), add:

```lua
    -- DEBUG: unconditional — remove after diagnosis
    vim.notify(string.format("chain=%d, initial=%s, step=%d",
      #chain,
      tostring(picker.opts._scope_initial_cwd),
      picker.opts._scope_step_index or -1
    ), vim.log.levels.WARN)
```

### What to do

1. Apply the 2 debug lines above
2. Open Neovim: `NVIM_APPNAME=nvimwt3a nvim`
3. Open a files picker in a project where CWD != git root (or use `<A-S>` to select a subproject first)
4. Press `<A-e>`
5. Check `:messages` and report what you see

### Expected debug output & interpretation

| You see | Meaning |
|---------|---------|
| Nothing at all | `toggle_external` is not being called → keybinding issue |
| `source=""` or `source="nil"` | Source name lost → `apply_filter` or `vim.tbl_deep_extend` issue |
| `source="files"` + `chain=1` | CWD == git root → no parent scope (expected if testing in this repo directly) |
| `source="files"` + `chain=2+` but no result change | Chain built correctly, issue is in refresh/cwd/exclude application |

### Cleanup
Remove both `-- DEBUG:` lines after diagnosis.
