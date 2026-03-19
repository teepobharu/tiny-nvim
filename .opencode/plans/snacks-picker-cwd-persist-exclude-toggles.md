---
title: "Snacks Picker UX — CWD Persist Pin + Exclude Pattern Toggles"
status: "open"
priority: "high"
created: 2026-03-18
updated: 2026-03-18
related:
  - [Subproject Scope Select Persist (review)](tasks/review/subproject-snacks-scope-select-persist.md)
  - [Snacks Actions](lua/utils/snacks_actions.lua)
  - [Editor Keymaps](lua/utils/editor_keymaps.lua)
  - [Snacks Pickers](lua/utils/snacks_pickers.lua)
  - [Snacks Picker Memory](docs/memory/snacks_picker.md)
  - [Auto-CD Investigation](docs/memory/nvim-auto-cd-investigation.md)
---

# Snacks Picker UX — CWD Persist Pin + Exclude Pattern Toggles

Two related improvements to snacks picker workflow:

1. **CWD Persist Pin** — Pin a subproject CWD so pickers don't auto-reset when navigating files
2. **Exclude Pattern Toggles** — Configurable groups to quickly filter out tests, docs, configs from grep/files

## Feature 1: CWD Persist Pin

### Problem

When selecting a subproject via `<M-S>` picker, the CWD is stored in `vim.g.picker_cwd_cycle_state_value`. But the main keymaps (`<leader>sG`, `<leader>fWg`, `<leader>fF`) pass `use_previous_cwd_state = false` to `get_initial_picker_state()`, so the next picker invocation ignores the persisted state and re-detects the nearest subproject from the current buffer's location.

**Root cause references:**
- `editor_keymaps.lua:863` — `{ cwd_default = "subproject", use_previous_cwd_state = false }`
- `editor_keymaps.lua:873` — same
- `editor_keymaps.lua:942` — same
- `snacks_pickers.lua:1880` — `if cwd_state and opts.use_previous_cwd_state ~= false then` (skipped when `false`)
- `snacks_actions.lua:875-876` — sets the persisted state on subproject select

### Solution: Pinned CWD Concept

#### New Global State

```lua
vim.g.picker_cwd_pinned = false  -- Whether CWD is explicitly pinned by user
-- Existing:
-- vim.g.picker_cwd_cycle_state = "subproject_picker"
-- vim.g.picker_cwd_cycle_state_value = "/path/to/subproject"
```

#### Logic Changes

**`get_initial_picker_state()` in `snacks_pickers.lua`:**
- If `vim.g.picker_cwd_pinned == true`, always use `vim.g.picker_cwd_cycle_state_value` regardless of `use_previous_cwd_state`
- Pinned state overrides everything — this is the user's explicit intent

**`apply_filter` in subproject picker (`snacks_actions.lua:873-886`):**
- Set `vim.g.picker_cwd_pinned = true` when subproject is selected

**`<M-S>` toggle behavior:**
- If NOT pinned → open subproject picker (existing), select pins the CWD
- If ALREADY pinned to same subproject → unpin (set `vim.g.picker_cwd_pinned = false`), notify user, re-detect CWD from buffer location
- If ALREADY pinned to different subproject → open subproject picker to change pin

**`cycle_cwd` action (`<A-s>`):**
- Cycling does NOT auto-unpin (user may want to cycle within pinned context)
- But cycle state resets the pin if the user cycles away from the pinned value

#### Visual Indicator

- Picker title shows pin status: `"Grep [📌 tbff]"` when pinned vs `"Grep [auto: tbff]"` when auto-detected
- Notification on pin: `"CWD pinned to: /path/to/subproject (tbff)"`
- Notification on unpin: `"CWD unpinned — auto-detecting from buffer"`

### Files to Modify

1. **`lua/utils/snacks_pickers.lua:1856-1907`** — `get_initial_picker_state()`: check `vim.g.picker_cwd_pinned`
2. **`lua/utils/snacks_actions.lua:873-886`** — `apply_filter`: set `vim.g.picker_cwd_pinned = true`
3. **`lua/utils/snacks_actions.lua:~870`** — `<M-S>` entry point: add toggle logic (unpin if already pinned to same)
4. **`lua/utils/editor_keymaps.lua:863,873,942`** — Change `use_previous_cwd_state = false` to `true` (or remove override, let pinned state handle it)
5. **`lua/utils/snacks_actions.lua:1054-1056`** — CWD cycle: handle pin state on cycle

### Checklist

- [ ] `vim.g.picker_cwd_pinned` global variable added
- [ ] `get_initial_picker_state()` respects pinned state over `use_previous_cwd_state`
- [ ] Subproject picker selection sets `pinned = true`
- [ ] `<M-S>` toggles pin off when already pinned to same subproject
- [ ] `<M-S>` opens picker when pinned to different subproject or not pinned
- [ ] Title shows pin indicator when pinned
- [ ] Notifications on pin/unpin
- [ ] `use_previous_cwd_state = false` removed from main keymaps (or adjusted)
- [ ] CWD cycle via `<A-s>` works correctly with pin state

---

## Feature 2: Configurable Exclude Pattern Toggle Groups

### Problem

No way to quickly exclude test files, docs, snapshots from files/grep results. Users must manually type `-- -g '!*test*'` in the picker search input each time.

### Solution: Exclude Group Toggles

#### Preset Groups Definition

```lua
-- In snacks_actions.lua (or new util file)
local EXCLUDE_GROUPS = {
  tests = {
    label = "Tests",
    key = "<M-t>",
    patterns = {
      "*test*", "*spec*", "__tests__", "__snapshots__", "__mocks__",
      "*.test.*", "*.spec.*", "test_*", "*_test.*",
    },
  },
  docs = {
    label = "Docs",
    key = "<M-d>",
    patterns = { "*.md", "*.mdx", "*.txt", "*.rst", "docs/*", "README*" },
  },
  config = {
    label = "Config",
    key = "<M-C>",
    patterns = { "*.json", "*.yaml", "*.yml", "*.toml", "*.lock", "*.config.*" },
  },
}
```

#### How It Works

**Snacks native exclude support:**
- Files finder: `opts.exclude` maps to `fd -E <pattern>` or `rg -g !<pattern>` (source: `files.lua:62-73`)
- Grep finder: `opts.exclude` maps to `rg -g !<pattern>` (source: `grep.lua:29-32`)
- Both re-read `opts.exclude` on every `picker:find()` call

**Toggle action per group:**
```lua
function M.toggle_exclude_tests(picker)
  picker.opts._exclude_active = picker.opts._exclude_active or {}
  picker.opts._exclude_active.tests = not picker.opts._exclude_active.tests

  -- Rebuild exclude list from all active groups
  local excludes = {}
  for group_name, active in pairs(picker.opts._exclude_active) do
    if active then
      vim.list_extend(excludes, EXCLUDE_GROUPS[group_name].patterns)
    end
  end
  picker.opts.exclude = excludes

  -- Refresh
  picker.list:set_target()
  picker:find()

  -- Notify
  local state = picker.opts._exclude_active.tests and "ON" or "OFF"
  Snacks.notify.info("Exclude tests: " .. state)
end
```

**Title/footer update:**
- Show active excludes: `"Grep [-tests -docs]"` in title
- Or footer: `"<M-t> tests | <M-d> docs | <M-C> config"`

#### Available Alt-Keys (in picker context)

| Key | Current Use | Available? |
|-----|-------------|-----------|
| `<M-t>` | Not used in picker | Yes — tests |
| `<M-d>` | Not used in picker | Yes — docs |
| `<M-C>` | `<M-c>` = case sensitivity | Yes (shift variant) — config |
| `<M-x>` | Not used | Reserve for "exclude menu" if needed |

### Files to Modify

1. **`lua/utils/snacks_actions.lua`** — Add `EXCLUDE_GROUPS` table + `toggle_exclude_<group>` actions
2. **`lua/utils/editor_keymaps.lua:1231+`** — Wire `<M-t>`, `<M-d>`, `<M-C>` to shared key groups for files/grep pickers

### Checklist

- [ ] `EXCLUDE_GROUPS` preset table defined with tests, docs, config groups
- [ ] `toggle_exclude_<group>` action for each group
- [ ] Action modifies `picker.opts.exclude` and calls `picker:find()`
- [ ] Active excludes tracked in `picker.opts._exclude_active`
- [ ] `<M-t>` toggles test exclusion in files/grep pickers
- [ ] `<M-d>` toggles docs exclusion in files/grep pickers
- [ ] `<M-C>` toggles config exclusion in files/grep pickers
- [ ] Visual indicator shows active excludes (title or footer)
- [ ] Notification on toggle with count of patterns
- [ ] Excludes work with both `fd` and `rg` backends
- [ ] Toggling off removes patterns correctly (not stale excludes)

---

## Implementation Order

1. Feature 1 (CWD Persist Pin) — simpler, fewer files, high-impact UX fix
2. Feature 2 (Exclude Toggles) — more code, but well-contained

## Verification

### How to verify

Restart Neovim worktree profile. Test in a monorepo project with multiple subprojects.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim
```

### Feature 1 Verification

```vim
" 1. Open grep in monorepo context
:lua Snacks.picker.grep()

" 2. Press <M-S> to open subproject picker
" 3. Select a subproject — should see pin indicator in title
" 4. Close picker, navigate to a file in DIFFERENT subproject
" 5. Open grep again (<leader>sG) — should still show pinned subproject

" 6. Press <M-S> again (while pinned to same) — should UNPIN
" 7. Open grep again — should auto-detect from current buffer location

" 8. Test cycle <A-s> works correctly with pin state
```

### Feature 2 Verification

```vim
" 1. Open grep picker
:lua Snacks.picker.grep()

" 2. Search for something common
" 3. Press <M-t> — test files should disappear from results
" 4. Press <M-t> again — test files reappear
" 5. Press <M-d> — docs/markdown files disappear
" 6. Both <M-t> and <M-d> active — both excluded simultaneously
" 7. Check title shows active excludes
```

### Combined Verification

- [ ] Feature 1: Selecting subproject via `<M-S>` pins CWD with indicator
- [ ] Feature 1: `<M-S>` when already pinned to same subproject unpins
- [ ] Feature 1: Pinned CWD persists across picker reopens (`<leader>sG`, `<leader>fF`)
- [ ] Feature 1: Navigating to different file does NOT change pinned CWD
- [ ] Feature 1: `<A-s>` cycle still works with pin state
- [ ] Feature 2: `<M-t>` toggles test file exclusion
- [ ] Feature 2: `<M-d>` toggles docs exclusion
- [ ] Feature 2: `<M-C>` toggles config file exclusion
- [ ] Feature 2: Multiple groups can be active simultaneously
- [ ] Feature 2: Active excludes shown in title/footer
- [ ] Both features work together without conflicts

## Investigation Notes

### CWD Auto-Reset Root Cause

No `autochdir` or `BufEnter` autocmd changes CWD automatically in this config. The "auto reset" is caused by:
1. Main keymaps explicitly set `use_previous_cwd_state = false`
2. `get_initial_picker_state()` then recalculates CWD using `cwd_default = "subproject"` which detects the nearest subproject from the current buffer
3. When the user navigates to a file in a different subproject, the auto-detection picks up that subproject instead

This is a picker-level issue, not a Neovim CWD issue. The actual `vim.fn.getcwd()` is never changed.

### Snacks Exclude Support

Both files and grep finders support `exclude: string[]` natively:
- `files.lua:62-73` — Maps to `fd -E`, `rg -g !`, or `find -not -path`
- `grep.lua:29-32` — Maps to `rg -g !`
- The list is read from `opts.exclude` on every `finder:find()` call, so modifying `picker.opts.exclude` and calling `picker:find()` is sufficient

### Toggle System Reference

Snacks has a built-in toggle system (`config/init.lua:93-105`) that generates `toggle_<name>` actions for boolean options. Our exclude groups need custom actions since they operate on arrays, not booleans. But the pattern (modify `picker.opts`, call `picker:find()`) is the same.
