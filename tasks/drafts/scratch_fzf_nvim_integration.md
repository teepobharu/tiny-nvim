---
title: "Create nvim scratch fzf system — recreate/extend scratch.fzf with multi-source, grep mode, source cycling"
status: draft
priority: medium
created: 2026-07-03
updated: 2026-07-03
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

- [ ] Create new snacks picker source `scratch_multi` aggregating all 4 sources
- [ ] Implement source cycling action (`<A-s>`) with dynamic picker refresh + title update
- [ ] Add grep mode toggle (`<A-g>`) — switch from file list to `Snacks.picker.grep` scoped to active source
- [ ] Add file preview with actual content (snacks preview)
- [ ] Support daily note creation from within picker
- [ ] Map to chosen entry key (pending Q2)

## Success Criteria

- `<leader>ns` (or chosen key) opens a unified picker with all 4 note sources
- `alt-s` cycles through sources with visual feedback (title change)
- Grep mode toggle searches file contents within the active source
- File preview shows actual content (not just metadata)
- Daily note creation works from within the picker
- No regression to existing `<leader>no` scratch buffer creation

## Verification

### How to verify

Open Neovim with main profile, trigger the scratch picker, and test all modes.

### Commands

```bash
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

### Checklist

- [ ] Scratch picker opens with files from multiple sources
- [ ] `alt-s` cycles through sources (daily-work → daily-personal → raw-notes → scratch-files → all)
- [ ] Title updates to show current source
- [ ] Grep mode toggle searches file contents
- [ ] File preview panel shows actual file content
- [ ] Existing `<leader>no` still works for new scratch buffers
- [ ] Works when some source directories are empty or missing
