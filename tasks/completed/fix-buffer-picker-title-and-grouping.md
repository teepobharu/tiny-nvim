---
title: "Fix buffer picker title on a-s + add buffer group ranking"
status: completed
priority: high
created: 2026-06-26
updated: 2026-07-19
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

### Original problem 1: Title not updating

The original `toggle_buffer_scope` action (buffers `a-s`) called
`picker:refresh()` without setting `picker.title`. Compare with
`toggle_cwd_files_grep`, which correctly sets:

```lua
picker.title = string.format("%s [%s] (%d/%d)", title_source, short_cwd, next_idx, #chain)
```

### Original problem 2: No buffer grouping/ranking

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

- [x] Keep the title-update fix scoped to `toggle_buffer_scope` in [editor_keymaps.lua](lua/utils/editor_keymaps.lua:1624-1676).
- [x] Finalize the grouping helper shape in [buffer_groups.lua](lua/utils/buffer_groups.lua) without hard-coding transient buffer names too broadly.
- [x] Wire grouped sorting into the buffer picker by default and preserve existing last-used ordering inside each group.
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
- [x] Hidden/unlisted buffers stay filtered out by default; focused `<A-r>` modes opt into the terminal/agent subsets and keep grouped ordering.
- [x] The all-buffers base title is `Buffers`; scoped and focused modes append path/count and mode suffixes rather than an explicit `all` label.

### Implementation Plan

#### Part A: Fix title update (quick fix)

- [x] In `toggle_buffer_scope` action (`editor_keymaps.lua:1624-1676`), add `picker.title = ...` line before `picker:refresh()`, mirroring the files/grep pattern:
  ```lua
  picker.title = string.format("Buffers [%s] (%d/%d)", short_cwd, next_idx, #chain)
  ```
- [x] When returning to initial (idx=1, showing all buffers), reset the base title to `"Buffers"` while preserving active grouped/focused suffixes.

#### Part B: Buffer group sorting (feature)

- [x] Implement custom sort in the `buffers` source config. Selected Option C:
  - **Option A**: Override the `sort_lastused` behavior by adding a custom comparator that groups by category first, then sorts by `lastused` within each group.
  - **Option B**: Use the `transform` function to add a `_group_rank` field, then sort. But transform runs after sorting, so this won't work for sorting.
  - **Option C**: Use a custom finder that preserves the built-in item shape,
    applies group/last-used ordering, and only then hands items to the Snacks
    matcher/filter.
- [x] Define group classification logic in `lua/utils/buffer_groups.lua`:
  ```lua
  -- Classification based on buftype + name patterns
  local function buffer_group(buf)
    local buftype = vim.bo[buf].buftype
    local name = vim.api.nvim_buf_get_name(buf)

    -- Protect normal files before matching AI words in their path.
    if buftype == "" then
      return 4  -- file buffers
    end

    -- AI identities are checked before generic terminals.
    local ai_patterns = { "claude", "avante", "codecompanion", "pi-agent", "copilot" }
    for _, pat in ipairs(ai_patterns) do
      if name:lower():find(pat) then
        return 1
      end
    end

    if buftype == "terminal" then
      return name:lower():find("lazygit", 1, true) and 3 or 2
    end

    return 5  -- utility/internal
  end
  ```
- [x] Integrate into the buffers picker config so sorting applies on every open/refresh.

### Success Criteria

1. Pressing `a-s` in the buffer picker updates the title bar to show scope path and step count.
2. Buffer list is grouped: AI tool buffers → terminal buffers → LazyGit → file buffers → utility buffers.
3. Within each group, buffers are still sorted by `lastused` (existing behavior preserved).
4. No regression in scope filtering (`a-s`, `a-S`, `a-e`) or existing buffer picker keys.

### Verification

#### How to verify

Open Neovim in a project with multiple buffer types (file buffers, a terminal, an AI tool buffer like Claude or pi). Open the buffer picker with `<leader><space>`.

#### Commands

Automated regression test and merged-config check:

```bash
NVIM_APPNAME=nvimwt3a nvim --headless -u NONE -i NONE \
  --cmd 'set rtp^=/Users/tharutaipree/dotfiles/.config/nvimwt3a' \
  -l tests/test_buffer_groups.lua

NVIM_APPNAME=nvimwt3a nvim --headless -i NONE \
  +'lua local c=Snacks.picker.config.get({ source = "buffers" }); print(vim.inspect({ group_by_kind = c.group_by_kind, hidden = c.hidden, focus_hidden_mode = c.focus_hidden_mode, finder = type(c.finder), format = type(c.format) }))' \
  +qa
```

Manual isolated-profile check:

```bash
NVIM_APPNAME=nvimwt3a nvim
```

Inside Neovim:
1. Open several files to create file buffers
2. Open a terminal (`:terminal`)
3. Open an AI tool (claude, pi, codecompanion, etc.)
4. Press `<leader><space>` to open buffer picker

#### Checklist

- [ ] Buffer picker title shows `Buffers` on first open
- [x] Pressing `a-s` updates title to show scope path and step count (e.g. `Buffers [path] (2/3)`)
- [ ] AI tool buffers (CodeCompanion, Claude/cag, Sidekick/pi, etc.) appear first with `[AI]`
- [ ] Generic terminal buffers appear next with `[T]`
- [ ] LazyGit buffers appear after generic terminals with `[LG]`
- [ ] File buffers appear after LazyGit with `[F]`
- [ ] Utility/internal buffers (quickfix, help, Snacks internal) appear last with `[U]`
- [ ] Within each group, buffers are sorted by last-used (most recent first)
- [ ] Scope filtering (`a-s`, `a-S`, `a-e`) still works correctly with grouped buffers
- [ ] `<A-r>` still cycles terminal/agent focus → agent/chat focus → default without changing group order
- [ ] No errors in message area when cycling scope or refreshing

### Verification evidence (2026-07-19)

- [x] Focused headless regression test passes: classification, exact group order,
      last-used ordering inside AI, default finder grouping, scope-title reset,
      focused-title suffix preservation across the full `<A-r>` cycle, terminal
      cwd false-positive protection, and one refresh per toggle.
- [x] Full `NVIM_APPNAME=nvimwt3a` startup resolves `group_by_kind=true`,
      `hidden=false`, `focus_hidden_mode=0`, and custom finder/formatter functions.
- [x] `git diff --check` passes for the implementation and documentation files.
- [ ] User completed the isolated interactive checklist above and signed off in
      the consolidated review group.

## References

- [toggle_buffer_scope](lua/utils/editor_keymaps.lua:1624-1676)
- [toggle_cwd_files_grep (ref for title update)](lua/utils/snacks_actions.lua:1331-1389)
- buffers source: `~/.local/share/nvim3_jelly_tinynvim/lazy/snacks.nvim/lua/snacks/picker/source/buffers.lua`
- [snacks_picker memory](docs/memory/snacks_picker.md)
