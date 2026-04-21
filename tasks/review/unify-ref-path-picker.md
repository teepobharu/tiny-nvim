---
title: "Unify ref path picker — shared logic for keymap and sub-picker flows"
status: review
priority: high
created: 2026-04-20
updated: 2026-04-20
related:
  - [code_ref.lua](lua/utils/code_ref.lua)
  - [code_ref_picker_builder.lua](lua/utils/code_ref_picker_builder.lua)
  - [snacks_pickers.lua](lua/utils/snacks_pickers.lua)
  - [snacks_actions.lua](lua/utils/snacks_actions.lua)
  - [path.lua](lua/utils/path.lua)
  - [mykeymaps.lua](lua/config/mykeymaps.lua)
---

## Objective

Eliminate code duplication between the two ref path picker flows:

1. **Keymap picker** (`<localleader>crp`) — `code_ref_picker()` in `snacks_pickers.lua`
2. **Sub-picker** (`<M-y>` inside file/grep picker) — `copy_path_select()` in `snacks_actions.lua`

Both flows now share a single source of truth for:
- Path variant generation (`generate_path_variants()`)
- Code-ref formatting (`generate_coderef_items()` wrapping `format_ref()`)
- Picker UI construction (`code_ref_picker_builder.build()`)

## Changes Made

### New files

- **`lua/utils/code_ref_picker_builder.lua`** — shared picker builder with unified format, keybindings (`<C-y>` copy, `<C-p>` paste, `<C-n>` markdown, `<A-c>` toggle), configurable confirm mode, and optional preview pane

### Modified files

- **`lua/utils/code_ref.lua`**:
  - Added `M.generate_path_variants(file_path, opts)` — unified path variant generator with dedup (8 variants: relative-to-buffer, git, cwd, absolute + directory variants)
  - Added `M.generate_coderef_items(path_variants, line, col, range, show_char_range)` — generates picker items using `format_ref()` (no more inline `string.format` duplication)
  - Promoted `get_visual_range()` from local to `M.get_visual_range()` (needed by picker)
  - Removed dead `get_path_parts()` function
  - Simplified `current_options()` to use the two new functions

- **`lua/utils/snacks_pickers.lua`**:
  - Simplified `code_ref_picker()` to use `code_ref_picker_builder.build()`
  - Now generates items via `code_ref.generate_path_variants()` + `code_ref.generate_coderef_items()`

- **`lua/utils/snacks_actions.lua`**:
  - Simplified `copy_path_select()` to use `code_ref_picker_builder.build()`
  - Removed ~210 lines of duplicated code: `generate_path_formats()`, `generate_coderef_formats()`, `get_path_stats()`, `insert_at_cursor()`, `insert_markdown_link()`
  - `copy_path_relative_buffer()` now uses `path_utils.get_relative_path_with_parent()`

- **`lua/utils/path.lua`**:
  - Added `M.get_relative_path_with_parent(target_path, source_path)` — shared utility for computing relative paths with `../` traversal

### Behavioral changes

- Keymap picker (`<localleader>crp`) now gains `<C-p>` paste, `<C-n>` markdown link actions (previously copy-only)
- Keymap picker now shows all 8 path variants with dedup (previously only git + cwd + absolute)
- Both pickers use `format_ref()` for consistent formatting (sub-picker previously used inline `string.format`)

## Verification

### How to verify

Restart Neovim with the worktree profile. Test both picker flows in a git project with nested directories.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim lua/utils/code_ref.lua
```

### Checklist

- [ ] `<localleader>crp` in normal mode opens code ref picker with path variants (Relative, Git, CWD, Absolute + dirs)
- [ ] Selecting an item in `<localleader>crp` and pressing Enter copies to clipboard
- [ ] `<C-p>` in `<localleader>crp` pastes the selected ref into buffer
- [ ] `<C-n>` in `<localleader>crp` pastes as markdown link
- [ ] `<C-y>` in `<localleader>crp` copies without closing picker
- [ ] `<A-c>` in `<localleader>crp` toggles col visibility and refreshes items
- [ ] `<localleader>crp` in visual mode (multi-line selection) shows range format and `<A-c>` toggles char range
- [ ] Files picker (`<leader>ff` or equivalent) → navigate to a file → press `<M-y>` → sub-picker opens with path + code-ref formats
- [ ] Grep picker → navigate to a result → press `<M-y>` → sub-picker shows code-ref items with line/col
- [ ] Enter in sub-picker pastes into buffer (closes both pickers)
- [ ] `<C-y>` in sub-picker copies to clipboard (stays open for multiple copies)
- [ ] `<A-c>` in sub-picker toggles col visibility and refreshes
- [ ] Direct copy keymaps still work: `<localleader>crr`, `<localleader>crs`, `<localleader>cra`, `<localleader>crb`, `<localleader>crh`
- [ ] Direct copy keymaps in visual mode capture the range correctly
- [ ] No errors on startup (`:messages` is clean)

## References

- [code_ref.lua](lua/utils/code_ref.lua) — `generate_path_variants()` at L189, `generate_coderef_items()` at L292
- [code_ref_picker_builder.lua](lua/utils/code_ref_picker_builder.lua) — `build()` at L132
- [snacks_pickers.lua](lua/utils/snacks_pickers.lua) — `code_ref_picker()` at L2196
- [snacks_actions.lua](lua/utils/snacks_actions.lua) — `copy_path_select()` at L575
