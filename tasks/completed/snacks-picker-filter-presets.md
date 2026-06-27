---
title: "Snacks picker filter presets — toggle exclude patterns in insert mode"
status: open
priority: medium
created: 2026-06-25
updated: 2026-06-25
refs:
  - [snacks_filter_presets.lua](lua/utils/snacks_filter_presets.lua)
  - [editor_keymaps.lua](lua/utils/editor_keymaps.lua)
  - [matcher.lua (snacks.nvim)](~/.local/share/nvimwt3a/lazy/snacks.nvim/lua/snacks/picker/core/matcher.lua)
---

## Objective

Add quick toggle keys in the snacks picker to:
1. Insert/remove exclude patterns (`!test !snap !mock !md !blob`) into the input
2. Insert path components from the **selected picker item** (filename, dirname, extension, relpath)

## Context

The snacks matcher natively supports fzf-style `!word` as inverse match (exclude).

Snacks already has `<C-r><c-w>`, `<C-r><c-f>`, `<C-r><c-l>`, `<C-r>%`, `<C-r>#` to insert
from the **current Neovim buffer** (see `defaults.lua:271-276`). This adds `<C-r>f/d/e/p`
to insert from the **selected picker item** instead.

Previously the user wanted regex filtering presets for specific projects (e.g. trips-web excludes
test files, snapshots, mocks, markdown, blobs). The cleanest solution is a single toggle key
that inserts/strips `!word` tokens + path component insertion.

## Implementation

### Files created/modified

- **NEW** `lua/utils/snacks_filter_presets.lua` — preset definitions + toggle action
- **MODIFIED** `lua/utils/editor_keymaps.lua` — added `toggle_filter_preset` action + `<M-/>` key in `files_and_grep.input`

### How it works

1. User opens any files/grep picker (`<leader>ff`, `<leader>fg`, etc.)
2. Presses `<M-/>` → inserts project preset tokens (e.g. `!test !snap !mock !md !blob` for trips-web)
3. Presses `<M-/>` again → strips all `!word` tokens from input
4. Presets cycle: `insert → strip → insert ...`

### Project detection

The `get_project_name()` function checks if the cwd contains any known project name (trips-web, agoda, etc.) and falls back to `default` preset.

### Presets

| Project | Tokens | Description |
|---------|--------|-------------|
| trips-web | `!test !snap !mock !md !blob` | Tests, snapshots, mocks, docs, blobs |
| agoda | `!test !snap !mock !md` | Tests, snapshots, mocks, docs |
| default | `!test !snap` | Tests, snapshots |

## Success Criteria

1. `<M-/>` toggles filter excludes in files picker
2. `<M-/>` toggles filter excludes in grep picker
3. Project preset auto-detects when cwd contains "trips-web"
4. Excluded files disappear from results (matcher inverse match)
5. Notification shows current state (ON/OFF + description)

## Verification

### How to verify

Open a project with test files (e.g. trips-web), open the files picker, and press `<M-/>`.

### Commands

```bash
# Navigate to a project with test files
cd ~/AgodaGit/trips-web
NVIM_APPNAME=nvimwt3a nvim
```

```vim
" Open files picker
<leader>ff
" Press <M-/> to insert excludes
" Observe: test files, snapshots, mocks, .md files disappear
" Press <M-/> again to remove excludes
" Observe: all files reappear
" Type some search + <M-/> to combine search with excludes
foo <M-/>
" Observe: input becomes "foo !test !snap !mock !md !blob"
```

### Checklist

- [ ] `<M-/>` in files picker inserts `!test !snap !mock !md !blob` (trips-web cwd)
- [ ] `<M-/>` again strips all `!word` tokens
- [ ] `<M-/>` in grep picker works the same way
- [ ] Manual `!word` tokens work (e.g. `!spec` excludes files containing "spec")
- [ ] Notification shows correct preset description
- [ ] Cursor stays at end of input after toggle
- [ ] Works in both normal and insert mode

## References

- [Snacks matcher `!` inverse logic](~/.local/share/nvimwt3a/lazy/snacks.nvim/lua/snacks/picker/core/matcher.lua:268) — `inverse` flag on `!pattern`
- [Snacks matcher `_prepare`](~/.local/share/nvimwt3a/lazy/snacks.nvim/lua/snacks/picker/core/matcher.lua:262) — pattern parsing including `!`, `'`, `^`, `$`
