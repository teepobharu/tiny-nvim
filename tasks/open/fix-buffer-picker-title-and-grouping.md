---
title: "Fix buffer picker title on a-s + add buffer group ranking"
status: open
priority: high
created: 2026-06-26
updated: 2026-07-06
refs:
  - snacks.nvim: current lazy branch (buffers source at lua/snacks/picker/source/buffers.lua)
related:
  - [toggle_buffer_scope action](lua/utils/editor_keymaps.lua:1624-1676)
  - [toggle_cwd_files_grep (ref impl)](lua/utils/snacks_actions.lua:1331-1389)
  - [snacks_picker memory](docs/memory/snacks_picker.md)
  - "buffers source: ~/.local/share/nvim3_jelly_tinynvim/lazy/snacks.nvim/lua/snacks/picker/source/buffers.lua"
---

## Objective

1. **Fix**: Buffer picker title does not update when pressing `a-s` (scope cycle), unlike the files/grep picker which correctly shows `Files [path] (idx/total)`.
2. **Feature**: Group and rank buffers by type. Current priority: AI buffers first (CodeCompanion, Claude/cag, Sidekick), then regular terminals, then LazyGit, then files, then utility/internal buffers.

## Context

### 2026-07-03 correction: `<A-r>` hidden buffer focus

The current requirement for the buffer picker is:

- Default `<leader><space>` / `<leader>fb` should **not** include hidden/unlisted buffers by default.
- `<A-r>` inside the buffer picker should toggle a focused hidden-buffer view.
- Focused hidden view should show only hidden/unlisted terminal and AI/agent-related buffers, mainly terminal, Claude, agent, CodeCompanion, Avante, Copilot, Codex, Gemini, sidekick, and Snacks terminal buffers.

Root cause found: the buffer source override had `hidden = true`, so hidden buffers were always included on initial open. `<A-r>` was also mapped to grouped sorting instead of a focused hidden-buffer filter.

### Problem 1: Title not updating

The `toggle_buffer_scope` action (buffers `a-s`) in `editor_keymaps.lua:1624-1676` calls `picker:refresh()` but **never sets `picker.title`**. Compare with `toggle_cwd_files_grep` in `snacks_actions.lua:1331-1389` which correctly sets:

```lua
picker.title = string.format("%s [%s] (%d/%d)", title_source, short_cwd, next_idx, #chain)
```

### Problem 2: No buffer grouping/ranking

The buffers source (`snacks.nvim/.../buffers.lua`) sorts only by `lastused`. No grouping by buffer category. The user wants:

| Rank | Group | Examples |
|------|-------|----------|
| 1 | **AI tool buffers** | CodeCompanion, Claude/cag, Sidekick/pi, Avante, Copilot |
| 2 | **Terminal buffers** | generic integrated terminal (`buftype == "terminal"`) |
| 3 | **LazyGit terminals** | lazygit/toggleterm lazygit buffers |
| 4 | **File buffers** | normal `.md`, `.lua`, `.ts` files (`buftype == ""`) |
| 5 | **Utility/internal** | snacks picker input, quickfix, loclist, help (`buftype == "nofile"` or `"quickfix"` or `"help"`) |

Buffer items already carry `buftype` and `filetype` fields from the snacks source.

### Action Items

- [ ] Keep the title-update fix scoped to `toggle_buffer_scope` in [editor_keymaps.lua](lua/utils/editor_keymaps.lua:1624-1676).
- [ ] Finalize the grouping helper shape in [buffer_groups.lua](lua/utils/buffer_groups.lua) without hard-coding transient buffer names too broadly.
- [ ] Wire grouped sorting into the buffer picker and preserve existing last-used ordering inside each group.
- [x] Classify Sidekick and Claude/cag terminals as AI by checking filetype/name patterns before generic terminal classification.
- [x] Classify LazyGit separately after regular terminals.
- [x] Sort focused `<A-r>` modes by group rank even when the grouping toggle is off.
- [x] Add short group labels in buffer picker rows: `[AI]`, `[T]`, `[LG]`, `[F]`, `[U]`.
- [x] Set the default buffer picker back to `hidden = false` so hidden/unlisted buffers are not default.
- [x] Rewire buffer `<A-r>` to toggle focused hidden terminal/agent buffers instead of grouped sorting.
- [x] Exclude ordinary file buffers from `<A-r>` focused hidden mode even when their paths match AI keywords such as `.claude`.
- [x] Make `<A-r>` cycle again into a stricter agent/chat-only mode that filters out common terminals and keeps CodeCompanion chat filetype buffers.
- [x] Keep CodeCompanion chat buffers visible in focused modes after Snacks opens them and they become listed/active (`listed=1`, `hidden=0`).
- [x] Make focused modes consistent before/after opening by filtering on terminal/AI identity rather than `hidden`/`listed` state.
- [x] Add a short note to [snacks_picker memory](docs/memory/snacks_picker.md) if the implementation relies on a non-obvious Snacks picker hook.

### Points to Confirm

- [x] Confirm the desired order for sidekick terminal buffers: AI group.
- [ ] Confirm whether hidden/unlisted buffers should be grouped or filtered out.
- [ ] Confirm whether the title should show `Buffers` only for the all-buffers scope or include an explicit `all` label.

### Implementation Plan

#### Part A: Fix title update (quick fix)

- [ ] In `toggle_buffer_scope` action (`editor_keymaps.lua:1624-1676`), add `picker.title = ...` line before `picker:refresh()`, mirroring the files/grep pattern:
  ```lua
  picker.title = string.format("Buffers [%s] (%d/%d)", short_cwd, next_idx, #chain)
  ```
- [ ] When returning to initial (idx=1, showing all buffers), reset title to just `"Buffers"`.

#### Part B: Buffer group sorting (feature)

- [ ] Implement custom sort in the `buffers` source config. Options:
  - **Option A**: Override the `sort_lastused` behavior by adding a custom comparator that groups by category first, then sorts by `lastused` within each group.
  - **Option B**: Use the `transform` function to add a `_group_rank` field, then sort. But transform runs after sorting, so this won't work for sorting.
  - **Option C**: Use a custom `finder` wrapper that calls the built-in buffers source, then re-sorts the items by group rank before returning.
- [ ] Define group classification logic in `lua/utils/snacks_actions.lua` or a new `lua/utils/buffer_groups.lua`:
  ```lua
  -- Classification based on buftype + name patterns
  local function buffer_group(buf)
    local buftype = vim.bo[buf].buftype
    local name = vim.api.nvim_buf_get_name(buf)

    if buftype == "" then
      return 1  -- file buffers (highest priority)
    end

    -- AI tool detection (check name patterns)
    local ai_patterns = { "claude", "avante", "codecompanion", "pi-agent", "copilot" }
    for _, pat in ipairs(ai_patterns) do
      if name:lower():find(pat) then
        return 2
      end
    end

    if buftype == "terminal" then
      return 3
    end

    return 4  -- utility/internal
  end
  ```
- [ ] Integrate into the buffers picker config so sorting applies on every open/refresh.

### Success Criteria

1. Pressing `a-s` in the buffer picker updates the title bar to show scope path and step count.
2. Buffer list is grouped: file buffers → AI tool buffers → terminal buffers → utility buffers.
3. Within each group, buffers are still sorted by `lastused` (existing behavior preserved).
4. No regression in scope filtering (`a-s`, `a-S`, `a-e`) or existing buffer picker keys.

### Verification

#### How to verify

Open Neovim in a project with multiple buffer types (file buffers, a terminal, an AI tool buffer like Claude or pi). Open the buffer picker with `<leader><space>`.

#### Commands

```bash
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

Inside Neovim:
1. Open several files to create file buffers
2. Open a terminal (`:terminal`)
3. Open an AI tool (claude, pi, codecompanion, etc.)
4. Press `<leader><space>` to open buffer picker

#### Checklist

- [ ] Buffer picker title shows "Buffers" on first open
- [ ] Pressing `a-s` updates title to show scope path and step count (e.g. `Buffers [path] (2/3)`)
- [ ] File buffers appear at the top of the list
- [ ] AI tool buffers (claude, pi, etc.) appear below file buffers
- [ ] Terminal buffers appear below AI buffers
- [ ] Utility/internal buffers (quickfix, help, snacks internal) appear at the bottom
- [ ] Within each group, buffers are sorted by last-used (most recent first)
- [ ] Scope filtering (`a-s`, `a-S`, `a-e`) still works correctly with grouped buffers
- [ ] No errors in message area when cycling scope or refreshing

## References

- [toggle_buffer_scope](lua/utils/editor_keymaps.lua:1624-1676)
- [toggle_cwd_files_grep (ref for title update)](lua/utils/snacks_actions.lua:1331-1389)
- buffers source: `~/.local/share/nvim3_jelly_tinynvim/lazy/snacks.nvim/lua/snacks/picker/source/buffers.lua`
- [snacks_picker memory](docs/memory/snacks_picker.md)
