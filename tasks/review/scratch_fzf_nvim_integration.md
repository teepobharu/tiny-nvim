---
title: "Create nvim scratch fzf system — recreate/extend scratch.fzf with multi-source, grep mode, source cycling"
status: review
priority: medium
created: 2026-07-03
updated: 2026-08-29
implementation_status: ready-for-review
created_by: task-orchestrator-skill
task_orchestrator_version: "1.4.0"
source: text
synthesis_confidence: medium
missing_info: []
related:
  - "scratch.fzf script: /Users/tharutaipree/dotfiles/scripts/everything.fzf/scratch.fzf"
  - "scratch.fzf helpers: /Users/tharutaipree/dotfiles/scripts/everything.fzf/helpers/"
  - [snacks.lua scratch config](lua/plugins/extra/snacks.lua)
  - [fzf.lua config](lua/plugins/extra/fzf.lua)
  - "Snacks.scratch upstream: ~/.local/share/nvim3_jelly_tinynvim/lazy/snacks.nvim/lua/snacks/scratch.lua"
  - [editor_keymaps.lua — keymaps](lua/utils/editor_keymaps.lua)
  - [mykeymaps.lua — existing <leader>ns/no](lua/config/mykeymaps.lua)
---

## Objective

Build a Neovim-native scratch notes browser that recreates (and extends) the capabilities of the existing `scratch.fzf` CLI tool, with multi-source aggregation, grep mode, and source cycling.

## Context

### Existing scratch.fzf (CLI)
Located at `/Users/tharutaipree/dotfiles/scripts/everything.fzf/scratch.fzf` (~800 lines bash). Aggregates 4 sources into one fzf picker:
- **daily-work**: `~/Documents/daily/YYYYMMDD/user.md`
- **daily-personal**: `~/Personal/mynotes/Daily/YYYY-MM-DD.md`
- **raw-notes**: `~/dotfiles/ai/agents/raw/notes/`
- **scratch-files**: `~/dotfiles/.config/myscripts/scratch/`

Features: `alt-s` source cycling, display density toggle (`alt-c`), file preview via `bat`, clipboard append, multi-select actions, new scratch file creation with boilerplate.

### Existing nvim scratch (Snacks.scratch)
- `<leader>no` — `Snacks.scratch()` — opens new scratch buffer
- `<leader>ns` — `Snacks.scratch.select()` — picker of existing scratch buffers
- Limited to single scratch root (`~/.local/share/nvim3_jelly_tinynvim/scratch/`)
- No daily notes, no multi-source, no content grep, no source cycling

### Gap
Snacks.scratch is a scratch buffer utility. scratch.fzf is a full notes ecosystem. Need to bridge the gap inside nvim.

### Constraint
- **Picker backend: snacks.picker only** (project convention)

## Clarification Questions

Answer these before starting implementation. Each includes a suggested default based on the investigation.

Accepted for this implementation cycle:

- [x] Coexist with `scratch.fzf` as the CLI fallback.
- [x] Add `<leader>nS`; preserve native `<leader>ns` and `<leader>no`.
- [x] Include all four sources in the MVP.
- [x] Restrict grep to the active source roots.
- [x] Deliver source cycling, preview, grep, and daily-note creation together.

1. Replace or coexist with scratch.fzf?
   - A) Full nvim recreation (cleaner long-term, more work)
   - B) Coexist — keep CLI as fallback (safer, faster MVP)
   - Suggestion: B — scratch.fzf is ~800 lines of proven bash logic; recreating clipboard append, raw-note CRUD, and multi-editor routing in Lua is non-trivial. Coexist for MVP, migrate later if scratch.fzf becomes a maintenance burden.

2. Entry key
   - A) Replace `<leader>ns` (current `scratch.select`)
   - B) New key `<leader>nn` (keeps old scratch.select at `<leader>ns`)
   - Suggestion: A — the current `scratch.select` is limited to one source; the new multi-source picker strictly supersedes it. The old `<leader>no` (new scratch buffer) stays untouched.

3. Source priority for MVP
   - A) All 4 sources at once
   - B) Start with raw-notes + scratch-files, add daily sources later
   - Suggestion: A — the source cycling architecture is the same regardless of count; adding sources is just adding entries to a config table. No reason to phase.

4. Grep scope when toggling grep mode
   - A) Active source directory only
   - B) All sources
   - Suggestion: A — matches scratch.fzf's mental model (you're browsing one source, then grep inside it). Less confusing UX.

5. MVP scope
   - A) Source cycling + preview first, grep in follow-up
   - B) Build everything (cycling + preview + grep + daily note creation) in one pass
   - Suggestion: B — the snacks picker extension is a single module; grep toggle is just an action that swaps the picker source. All features share the same infrastructure, so splitting adds overhead without reducing risk.

## Implementation Plan

- [x] Create new snacks picker source `scratch_multi` aggregating all 4 sources
- [x] Implement source cycling action (`<A-s>`) with dynamic picker refresh + title update
- [x] Add grep mode toggle (`<A-g>`) — switch from file list to `Snacks.picker.grep` scoped to active source
- [x] Add file preview with actual content (snacks preview)
- [x] Support daily note creation from within picker
- [x] Add `<leader>nS` while preserving native `<leader>ns` and `<leader>no`

## Implementation

- [Multi-source picker](lua/utils/scratch_notes_picker.lua) — source discovery, dynamic catalog, grep mode, previews, and daily-note creation.
- [Snacks keymap](lua/plugins/extra/mySnacks.lua) — routes `<leader>nS` to the new picker while preserving the native `<leader>ns` selector and `<leader>no` creator.
- [Regression tests](tests/test_scratch_notes_picker.lua) — source cycling, date paths, depth/type filtering, aggregation, missing roots, and idempotent note creation.
- [Living memory](docs/memory/scratch_picker.md) — controls and non-obvious Snacks finder/grep behavior.

## Success Criteria

- `<leader>nS` opens a unified picker with all 4 note sources
- `alt-s` cycles through sources with visual feedback (title change)
- Grep mode toggle searches file contents within the active source
- File preview shows actual content (not just metadata)
- Daily note creation works from within the picker
- No regression to native `<leader>ns` scratch selection or `<leader>no` scratch buffer creation

## Verification

### How to verify

Run the pure filesystem regression test, then open the isolated worktree profile and test all picker modes. Do not use the daily-driver profile until the batch is accepted.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim --headless -u NONE -i NONE \
  --cmd 'set rtp^=/Users/tharutaipree/dotfiles/.config/nvimwt3a' \
  -l tests/test_scratch_notes_picker.lua
```

```bash
NVIM_APPNAME=nvimwt3a nvim
```

### Checklist

- [ ] Scratch picker opens with files from multiple sources
- [ ] `alt-s` cycles through sources (daily-work → daily-personal → raw-notes → scratch-files → all)
- [ ] Title updates to show current source
- [ ] Grep mode toggle searches file contents
- [ ] File preview panel shows actual file content
- [ ] `<C-n>` creates today's note for the active daily source and prompts from `all`/`scratch-files`
- [ ] Existing `<leader>no` still works for new scratch buffers
- [ ] Works when some source directories are empty or missing

### Verification evidence (2026-07-19)

- [x] Headless filesystem suite covers source cycling, depth/type filtering,
      aggregation, missing roots, idempotent creation, and blank override
      fallback (no root-level daily targets).
- [x] Source-level review confirms `<leader>nS` is added for the new picker while
      native `<leader>ns` and `<leader>no` bindings remain available.
- [ ] User completed the interactive checklist and signed off in the
      consolidated review group.

## User Signoff

- [ ] Close this task after all manual checks pass.
- [ ] Keep this task open and record failed checks below.

### Failed checks / follow-up

- None recorded.

## Review Feedback — 2026-07-27

1. **Switch key from `<leader>ns` to `<leader>nS`** — capital S distinguishes the multi-source picker from the simpler scratch select.
2. **Add `<A-e>` to toggle visibility of empty file content** — filter out/show scratch files that have zero content.
3. **Remove indent space from labels** — labels currently have leading space padding; remove it for compact display.
4. **Add source filter for `Snacks.scratch.list()` entries** — the scratch source returns items from `Snacks.scratch.list()` that include metadata like `item.cwd`, `item.ft`, `item.branch`, `item.stat.size`. Use these fields to filter/deduplicate and distinguish by:
   - File extension (`.lua`, `.json`, `.startify`, etc.)
   - Branch context (`item.branch` when present)
   - Empty vs non-empty files (`item.stat.size == 0`)
   - CWD context (`item.cwd`)

Sample item structure captured from runtime:
```lua
{
  _path = ".../scratch/9a10cdef.lua",
  item = {
    count = 1,
    cwd = ".../lua/config",
    file = ".../scratch/9a10cdef.lua",
    ft = "lua",
    icon = "󰢱",
    name = "Scratch",
    stat = { size = 33, ... }
  },
  text = "Scratch lua",
  title = "Scratch"
}
```

- [x] Change entry key to `<leader>nS`
- [x] Add `<A-e>` toggle for empty file visibility
- [x] Remove label indent space
- [x] Add source filter using `Snacks.scratch.list()` metadata fields
