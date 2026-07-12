---
title: "Fix C-space search carry when switching picker scope"
status: open
priority: medium
created: 2026-07-07
updated: 2026-07-07
refs:
related:
  - [toggle_picker_source](lua/utils/snacks_actions.lua:1705-1800)
  - [files keymap with search](lua/utils/editor_keymaps.lua:933-941)
  - [Snacks picker memory](docs/memory/snacks_picker.md)
---

## Objective

When the user selects a word, opens the files picker via `<leader>ff`, and then presses `<C-space>` to cycle to another picker (buffers / git_files), the selected word should carry over as the search filter in the next picker. Currently it is lost.

## Context

**User flow**:

1. Visual-select a word (e.g. `snacks_actions`)
2. Press `<leader>ff` → opens files picker with filtered results (word is hidden in `filter.search`)
3. Press `<C-space>` to switch to buffers or git_files → **word disappears**, picker shows all items

**Root cause**:

The `<leader>ff` keymap passes the visual selection as `search` instead of `pattern`:

```lua
-- lua/utils/editor_keymaps.lua:935-936
Snacks.picker.files(require("utils.snacks_terminal").get_initial_picker_state({
  search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines "visual_selection",
}, { source = "files" }))
```

**Snacks filter semantics** (from `lua/snacks/picker/core/filter.lua`):

- `filter.pattern` — matcher-side fuzzy filter → visible in the input box for non-live pickers
- `filter.search` — finder-side query → visible in the input box for *live* pickers (grep), acts as a hidden filter for non-live pickers

For non-live sources (files/buffers/git_files), the user's typed input lives in `filter.pattern`. Passing `search` to a file picker makes it a silent filter — results are narrowed but the input box stays empty. When `<C-space>` cycles pickers, `toggle_picker_source` reads `filter.pattern`, gets `""`, and the word is lost.

**Fix**: In visual mode, file pickers should pass the selection as `pattern` (not `search`) so the word is both visible in the input box AND carried by `<C-space>`. The `search` field is correct for live pickers (grep/grep_buffers) where it drives the underlying query.

## Implementation Plan

- [ ] Change `<leader>ff` to pass `pattern` instead of `search` for visual mode
- [ ] Change `<leader>fF` (monorepo files) to pass `pattern` instead of `search` for visual mode
- [ ] Change `<leader><space>` files fallback to pass `pattern` instead of `search` for visual mode
- [ ] Leave `search` as-is for live pickers (`<leader>/`, `<leader>fw`, `<leader>sG`, `<leader>sB`) — those are correct
- [ ] Verify `<C-space>` cycle carries the word through files → buffers → git_files → files
- [ ] Verify `<M-g>` (grep toggle) still works — it already reads both fields correctly

## Success Criteria

- Visual-select a word → `<leader>ff` → the word appears in the files picker input box
- Press `<C-space>` → word carries to buffers/git_files picker input
- Press `<C-space>` again → word carries through the full cycle
- Same behavior for `<leader><space>` (buffer picker fallback to files) and `<leader>fF` (monorepo files)
- No regression for grep-based pickers (they correctly use `search`)

## Verification

### How to verify

Test in any project with multiple files. Use a distinctive word that matches at least one filename.

### Commands

```bash
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

### Checklist

- [ ] Visual-select a word that matches a filename (e.g. `snacks_actions` or `editor_keymaps`)
- [ ] Press `<leader>ff` — word appears in the files picker input box
- [ ] Press `<C-space>` — switches to buffers, word is still in the input
- [ ] Press `<C-space>` again — switches to git_files, word is still in the input
- [ ] Press `<C-space>` again — cycles back to files, word is preserved
- [ ] Results are filtered by the word in each picker (not just displayed)
- [ ] No regression: `<leader>ff` in normal mode (no selection) opens files picker empty
- [ ] No regression: `<leader>/` (grep) still uses `search` correctly

## References

- [toggle_picker_source implementation](lua/utils/snacks_actions.lua:1705-1800)
- [toggle_grep_picker with both-field carry](lua/utils/snacks_actions.lua:1820-1916) — already handles pattern + search correctly for grep round-trips
- [files keymap with search opt](lua/utils/editor_keymaps.lua:933-941)
- Snacks `filter.lua`: `~/.local/share/nvim3_jelly_tinynvim/lazy/snacks.nvim/lua/snacks/picker/core/filter.lua` — `pattern` vs `search` semantics
- [Snacks picker filter docs](docs/memory/snacks_picker.md)
