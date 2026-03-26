---
title: "Revise toggle_external and toggle_cwd — subproject upward traversal"
status: "approved"
priority: "high"
created: 2026-03-25
---

# Revise toggle_external and toggle_cwd — Subproject Upward Traversal

## Overview

Replace the fixed CWD cycle set and single-jump external toggle with **subproject marker upward traversal**. Both `<A-s>` (scope toggle) and `<A-e>` (external toggle) walk up the subproject marker chain from the initial cwd to git root. Buffer pickers get their own separate persistence.

## Actions Summary

| Key | Action | Files/Grep | Buffers |
|-----|--------|-----------|---------|
| `<A-S>` | `select_subproject_cwd` | Persist to `vim.g.picker_cwd_cycle_state_value` | Persist to `vim.g.picker_buffer_cwd_state_value` |
| `<A-s>` | `toggle_cwd_files_grep` | Traverse UP subproject chain (short-lived) | Same (short-lived, for buffer filtering) |
| `<A-e>` | `toggle_external` | Move cwd UP one step + exclude initial cwd | Filter: show buffers outside scope cwd |

## State Model

```
Persistent state (survives across picker opens):
  vim.g.picker_cwd_cycle_state_value     → files/grep initial cwd
  vim.g.picker_buffer_cwd_state_value    → buffers initial cwd (NEW)

Picker-session state (stored on picker.opts, reset on each open):
  picker.opts._scope_initial_cwd         → initial cwd when picker opened
  picker.opts._scope_traversal_chain     → ordered list [initial_cwd, ..., git_root]
  picker.opts._scope_step_index          → current position in chain
  picker.opts._external_step_index       → current external step (for C1)
  picker.opts._external_exclude_cwd      → cwd being excluded in external mode
  picker.opts._external_original_exclude → saved exclude list for restoration
```

## File Changes

### 1. `lua/utils/snacks_actions.lua` — Core action revisions

#### a) Replace lines 12-144 with new shared helpers + revised toggle_external

**Remove**: `external_cwd_sources`, old `build_cwd_exclude_pattern`, old `toggle_external`

**Add new region** `--#region Scope Traversal Helpers`:

```lua
--#region Scope Traversal Helpers
-- Shared helpers for subproject-based upward traversal used by:
--   B (a-s): toggle_cwd_files_grep — cycle scope up subproject chain
--   C (a-e): toggle_external — move cwd up one step + exclude initial cwd
--   D (buffers): same patterns with separate persistence

--- Sources that support cwd-based scope traversal and external toggling
local scope_traversal_sources = {
  files = true,
  grep = true,
  grep_word = true,
}

--- Build ordered traversal chain from initial_cwd upward through subproject markers to git root
--- Returns: { initial_cwd, subproj_parent1, ..., git_root } (deduplicated, ascending depth)
--- @param initial_cwd string Starting directory
--- @return string[] chain Ordered directories from initial_cwd to git root
local function build_scope_traversal_chain(initial_cwd)
  local path = require "utils.path"
  local git_root = path.get_root_directory() or Snacks.git.get_root()

  if not initial_cwd or initial_cwd == "" then
    initial_cwd = vim.fn.getcwd()
  end
  initial_cwd = vim.fn.fnamemodify(initial_cwd, ":p"):gsub("/$", "")

  -- Single-entry chain if no git root or cwd IS git root
  if not git_root or git_root == "" then
    return { initial_cwd }
  end
  git_root = vim.fn.fnamemodify(git_root, ":p"):gsub("/$", "")
  if initial_cwd == git_root then
    return { git_root }
  end

  -- Get all subprojects with metadata, sorted nearest-first
  local subprojects = pathUtil.get_sub_project_dirs_from_root(git_root, initial_cwd, true, true, "nearest") or {}

  -- Filter to in_cwd_traversal items (on the path from initial_cwd up to git_root)
  local traversal_dirs = {}
  local seen = {}

  -- Always start with initial_cwd
  seen[initial_cwd] = true
  table.insert(traversal_dirs, initial_cwd)

  for _, sp in ipairs(subprojects) do
    if sp.in_cwd_traversal and sp.dir then
      local normalized = vim.fn.fnamemodify(sp.dir, ":p"):gsub("/$", "")
      if not seen[normalized] and normalized ~= initial_cwd then
        seen[normalized] = true
        table.insert(traversal_dirs, normalized)
      end
    end
  end

  -- Ensure git root is always last
  if not seen[git_root] then
    table.insert(traversal_dirs, git_root)
  end

  -- Sort by depth (deepest first = initial_cwd, shallowest last = git_root)
  table.sort(traversal_dirs, function(a, b)
    local depth_a = select(2, a:gsub("/", ""))
    local depth_b = select(2, b:gsub("/", ""))
    return depth_a > depth_b
  end)

  return traversal_dirs
end

--- Get or initialize traversal chain for a picker
--- @param picker table Snacks picker instance
--- @param persist_key string|nil vim.g key for persisted initial cwd (nil = use vim.fn.getcwd())
--- @return string[] chain, number step_index
local function get_picker_traversal_state(picker, persist_key)
  if not picker.opts._scope_traversal_chain then
    local initial_cwd = (persist_key and vim.g[persist_key]) or picker.opts.cwd or vim.fn.getcwd()
    picker.opts._scope_initial_cwd = initial_cwd
    picker.opts._scope_traversal_chain = build_scope_traversal_chain(initial_cwd)
    picker.opts._scope_step_index = 1 -- start at initial_cwd (index 1)
  end
  return picker.opts._scope_traversal_chain, picker.opts._scope_step_index
end

--- Reset traversal state on a picker (called when A-S selects new subproject or scope changes)
--- @param picker table Snacks picker instance
local function reset_picker_traversal_state(picker)
  picker.opts._scope_traversal_chain = nil
  picker.opts._scope_step_index = nil
  picker.opts._scope_initial_cwd = nil
  -- Also reset external state
  picker.opts._external_step_index = nil
  picker.opts._external_exclude_cwd = nil
  picker.opts._external_original_exclude = nil
  picker.opts.external = nil
end

--- Build a relative exclude pattern from exclude_cwd relative to search_cwd
--- @param exclude_cwd string The directory to exclude from search
--- @param search_cwd string The broader search cwd
--- @return string|nil The relative path to exclude, or nil if not applicable
local function build_cwd_exclude_pattern(exclude_cwd, search_cwd)
  if not exclude_cwd or not search_cwd then
    return nil
  end
  exclude_cwd = vim.fn.fnamemodify(exclude_cwd, ":p"):gsub("/$", "")
  search_cwd = vim.fn.fnamemodify(search_cwd, ":p"):gsub("/$", "")

  if exclude_cwd == search_cwd then
    return nil
  end
  if exclude_cwd == "/" or exclude_cwd == vim.env.HOME then
    return nil
  end

  local prefix = search_cwd .. "/"
  if exclude_cwd:sub(1, #prefix) == prefix then
    return exclude_cwd:sub(#prefix + 1)
  end
  return nil
end

-- Expose helpers for buffer actions in editor_keymaps
M._build_scope_traversal_chain = build_scope_traversal_chain
M._get_picker_traversal_state = get_picker_traversal_state
M._reset_picker_traversal_state = reset_picker_traversal_state
M._build_cwd_exclude_pattern = build_cwd_exclude_pattern

--#endregion Scope Traversal Helpers
```

**Add revised `toggle_external`:**

```lua
--- Toggle picker external filter flag and re-run finder
--- For files/grep pickers: steps cwd up one subproject level + excludes initial scope cwd
--- For other pickers (buffers, git): toggles boolean flag checked in transform
--- @param picker table Snacks picker instance
function M.toggle_external(picker)
  if not picker then
    return
  end

  local source = picker.opts and picker.opts.source or ""

  if vim.g.snacks_debug_external_filter then
    print(string.format("toggle_external: source=%s", source))
  end

  -- For files/grep pickers: step-based external with exclude
  if scope_traversal_sources[source] then
    local chain, _ = get_picker_traversal_state(picker, "picker_cwd_cycle_state_value")

    if #chain <= 1 then
      vim.notify("No parent scope to expand to — already at top", vim.log.levels.INFO)
      return
    end

    -- Initialize external state if needed
    if not picker.opts._external_step_index then
      local current_scope_idx = picker.opts._scope_step_index or 1
      picker.opts._external_step_index = current_scope_idx
      picker.opts._external_exclude_cwd = chain[current_scope_idx]
      picker.opts._external_original_exclude = picker.opts.exclude and vim.deepcopy(picker.opts.exclude) or nil
    end

    -- Advance external step (one up)
    local ext_idx = picker.opts._external_step_index + 1

    if ext_idx > #chain then
      -- Reached top — disable external mode, restore original state
      vim.notify("External: reached top, disabling", vim.log.levels.INFO)
      picker.opts._external_step_index = nil
      picker.opts._external_exclude_cwd = nil
      picker.opts.external = false

      local scope_idx = picker.opts._scope_step_index or 1
      picker.opts.cwd = chain[scope_idx]

      if picker.opts._external_original_exclude ~= nil then
        picker.opts.exclude = picker.opts._external_original_exclude
      else
        picker.opts.exclude = nil
      end
      picker.opts._external_original_exclude = nil

      local title_source = source:sub(1, 1):upper() .. source:sub(2)
      picker.title = title_source
    else
      picker.opts._external_step_index = ext_idx
      picker.opts.external = true

      local new_cwd = chain[ext_idx]
      local exclude_cwd = picker.opts._external_exclude_cwd
      local exclude_pattern = build_cwd_exclude_pattern(exclude_cwd, new_cwd)

      picker.opts.cwd = new_cwd

      local base_exclude = picker.opts._external_original_exclude
          and vim.deepcopy(picker.opts._external_original_exclude)
        or {}
      if exclude_pattern then
        table.insert(base_exclude, exclude_pattern)
      end
      picker.opts.exclude = #base_exclude > 0 and base_exclude or nil

      local title_source = source:sub(1, 1):upper() .. source:sub(2)
      local short_cwd = vim.fn.fnamemodify(new_cwd, ":~")
      local short_excl = exclude_pattern or "none"
      picker.title = string.format("%s [ext: %s, excl: %s]", title_source, short_cwd, short_excl)

      if ext_idx == #chain then
        vim.notify("External: reached git root — next toggle disables", vim.log.levels.INFO)
      end

      if vim.g.snacks_debug_external_filter then
        print(string.format(
          "toggle_external[%s]: cwd=%s, exclude=%s, step=%d/%d",
          source, new_cwd, exclude_pattern or "none", ext_idx, #chain
        ))
      end
    end

    picker:refresh()
  else
    -- For other pickers (buffers, git): simple boolean toggle
    picker.opts.external = not picker.opts.external
    if vim.g.snacks_debug_external_filter then
      print(string.format("toggle_external: source=%s -> %s", source, tostring(picker.opts.external)))
    end
    picker:find()
  end
end
```

#### b) Revise `toggle_cwd_files_grep` (~line 1058-1301)

**Replace** the entire function with:

```lua
--- Toggle CWD scope for pickers (files/grep/etc)
--- Traverses upward through subproject markers from initial scope cwd to git root
--- Short-lived: does NOT persist across picker sessions (only A-S persists)
function M.toggle_cwd_files_grep(picker, item)
  local chain, step_idx = get_picker_traversal_state(picker, "picker_cwd_cycle_state_value")

  if #chain <= 1 then
    vim.notify("Only one scope available — no other levels to traverse", vim.log.levels.INFO)
    return
  end

  -- Advance to next step
  local next_idx = step_idx + 1

  if next_idx > #chain then
    -- At git root (top) — notify and wrap to initial
    vim.notify("Reached git root — returning to initial scope", vim.log.levels.INFO)
    next_idx = 1
  elseif step_idx == #chain then
    -- Was at git root, wrapping back
    next_idx = 1
  end

  picker.opts._scope_step_index = next_idx
  local new_cwd = chain[next_idx]

  -- Reset external state when scope changes
  picker.opts._external_step_index = nil
  picker.opts._external_exclude_cwd = nil
  picker.opts._external_original_exclude = nil
  picker.opts.external = nil
  picker.opts.exclude = nil

  -- Apply new cwd
  local source = picker.opts and picker.opts.source or "Picker"
  local title_source = source:sub(1, 1):upper() .. source:sub(2)
  local short_cwd = vim.fn.fnamemodify(new_cwd, ":~")

  picker.opts.cwd = new_cwd
  picker.opts.args = nil -- clear any max-depth from previous state
  picker.opts.show_empty = true
  picker.title = string.format("%s [%s] (%d/%d)", title_source, short_cwd, next_idx, #chain)

  -- Preserve search state
  local filter_pattern = picker.input.filter and (picker.input.filter.pattern ~= "" and picker.input.filter.pattern)
  local filter_search = picker.input.filter and (picker.input.filter.search ~= "" and picker.input.filter.search)
  if filter_pattern then
    picker.opts.pattern = filter_pattern
  end
  if filter_search then
    picker.opts.search = filter_search
  end

  if next_idx == #chain then
    vim.notify(string.format("Scope: git root — %s", short_cwd), vim.log.levels.INFO)
  else
    vim.notify(string.format("Scope: %s (%d/%d)", short_cwd, next_idx, #chain), vim.log.levels.INFO)
  end

  picker:refresh()
end
```

#### c) Update `select_subproject_cwd` apply_filter action (~line 988-1001)

In the `apply_filter` action inside `select_subproject_cwd`, after setting `vim.g.picker_cwd_cycle_state_value`, also reset the parent picker's traversal state:

```lua
apply_filter = function(subpicker, item)
  vim.print("Applying CWD: " .. tostring(item.dir))
  vim.g.picker_cwd_cycle_state = "subproject_picker"
  vim.g.picker_cwd_cycle_state_value = item.dir
  subpicker:action "cancel"
  -- Reset traversal state on parent picker for fresh chain from new initial cwd
  reset_picker_traversal_state(picker)
  local newOpts = require("utils.snacks_terminal").get_initial_picker_state {}
  picker.opts = vim.tbl_deep_extend("force", picker.opts, newOpts)
  picker:find()
end,
```

### 2. `lua/utils/editor_keymaps.lua` — Buffers source config

#### a) Replace buffers source (~lines 1446-1542) with:

```lua
buffers = {
  -- External filter modes:
  --   external=true + scope="cwd": show buffers outside current scope CWD
  --   external=true + scope="project": show buffers outside project dir (git root)
  transform = function(item, ctx)
    local show_external = ctx and ctx.picker and ctx.picker.opts.external
    if not show_external then
      return item
    end

    -- Get the scope cwd for buffer filtering
    local scope_cwd = ctx.picker.opts._buffer_scope_cwd
      or vim.g.picker_buffer_cwd_state_value
      or vim.fn.getcwd()

    local path = nil
    local ok, util = pcall(function()
      return require("snacks").picker.util
    end)
    if ok and util then
      path = util.path(item)
    end

    -- Check for missing (non-existent) files
    local missing = false
    if path and path ~= "" then
      missing = vim.fn.filereadable(path) == 0 and vim.fn.isdirectory(path) == 0
    end

    if vim.g.snacks_debug_external_filter then
      print(
        string.format(
          "external_filter[buffers]: show_external=%s scope_cwd=%s missing=%s file=%s",
          tostring(show_external),
          vim.fn.fnamemodify(scope_cwd, ":~"),
          tostring(missing),
          tostring(item and (item.file or item.text) or "nil")
        )
      )
    end

    -- Always show missing buffers in external mode
    if missing then
      return true
    end

    -- Filter: show buffers outside scope cwd
    if path then
      local normalized_cwd = vim.fn.fnamemodify(scope_cwd, ":p"):gsub("/$", "") .. "/"
      local normalized_path = vim.fn.fnamemodify(path, ":p")
      return normalized_path:sub(1, #normalized_cwd) ~= normalized_cwd
    end
    return not pathUtil.is_in_project_dir(item)
  end,
  actions = {
    toggle_external = function(picker)
      require("utils.snacks_actions").toggle_external(picker)
    end,
    toggle_buffer_scope = function(picker)
      -- Buffer version of a-s: upward traversal through subproject chain
      local snacks_actions = require "utils.snacks_actions"
      local chain, step_idx = snacks_actions._get_picker_traversal_state(picker, "picker_buffer_cwd_state_value")

      if #chain <= 1 then
        vim.notify("Only one scope available for buffers", vim.log.levels.INFO)
        return
      end

      local next_idx = step_idx + 1
      if next_idx > #chain then
        vim.notify("Reached git root — returning to initial scope", vim.log.levels.INFO)
        next_idx = 1
      end

      picker.opts._scope_step_index = next_idx
      picker.opts._buffer_scope_cwd = chain[next_idx]

      -- Reset external when scope changes
      picker.opts.external = nil

      local short_cwd = vim.fn.fnamemodify(chain[next_idx], ":~")
      vim.notify(string.format("Buffer scope: %s (%d/%d)", short_cwd, next_idx, #chain), vim.log.levels.INFO)
      picker:find()
    end,
    select_buffer_subproject = function(picker)
      -- Buffer version of a-S: open subproject picker, persist to buffer-specific state
      -- Reuse select_subproject_cwd but override the persist target
      local snacks_actions = require "utils.snacks_actions"
      -- TODO: either pass a param to select_subproject_cwd or create a buffer-specific variant
      -- For now, call the same picker but override the apply_filter to use buffer state
      snacks_actions.select_subproject_cwd(picker, { persist_key = "picker_buffer_cwd_state_value" })
    end,
  },
  win = {
    input = {
      footer = "a-e: external, a-s: scope, a-S: subproject",
      keys = vim.tbl_extend("force", snacks_picker_group_keys.files_keys.input, {
        ["<M-e>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle external buffers" },
        ["<M-b>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle external buffers" },
        ["<A-s>"] = { "toggle_buffer_scope", mode = { "n", "i" }, desc = "Cycle buffer scope" },
        ["<M-S>"] = { "select_buffer_subproject", mode = { "n", "i" }, desc = "Pick buffer subproject" },
      }),
    },
  },
},
```

#### b) Update `select_subproject_cwd` to accept persist_key option

In `snacks_actions.lua`, modify `select_subproject_cwd` signature:

```lua
function M.select_subproject_cwd(picker, opts_or_item)
  -- Support opts table with persist_key for buffer-specific persistence
  local persist_key = "picker_cwd_cycle_state_value" -- default for files
  if type(opts_or_item) == "table" and opts_or_item.persist_key then
    persist_key = opts_or_item.persist_key
  end
  -- ... rest of function
  -- In apply_filter:
  --   vim.g[persist_key] = item.dir  (instead of hardcoded vim.g.picker_cwd_cycle_state_value)
```

## Interaction Rules

1. **B resets C**: When `<A-s>` changes scope, external state (`_external_step_index`, etc.) is fully cleared
2. **A resets B+C**: When `<A-S>` selects new subproject, both scope traversal chain and external state are reset
3. **B is short-lived**: Does NOT update `vim.g.picker_cwd_cycle_state_value`
4. **A persists**: `<A-S>` is the only way to persist cwd across picker sessions
5. **Buffer vs Files**: Separate persistence keys, separate traversal state

## Example Walkthrough

Given subproject markers at `git/b/c`, `git/b`, and `git`:

```
Initial state: picker_cwd = git/b/c
Chain = [git/b/c, git/b, git]

Action: <A-s> → scope becomes git/b (step 2/3)
Action: <A-s> → scope becomes git (step 3/3), notify "git root"
Action: <A-s> → wraps to git/b/c (step 1/3)

Action: <A-e> → cwd=git/b, exclude=git/b/c (ext step 2/3)
Action: <A-e> → cwd=git, exclude=git/b/c (ext step 3/3), notify "git root"
Action: <A-e> → disable external, back to scope cwd

Action: <A-s> → scope changes → external state resets
Action: <A-e> → starts fresh from new scope
```

## Files to Modify
- `lua/utils/snacks_actions.lua` — helpers, toggle_external, toggle_cwd_files_grep, select_subproject_cwd
- `lua/utils/editor_keymaps.lua` — buffers source config (transform, actions, keys)

## Edge Cases
- If initial cwd IS git root: chain = [git_root] only, both a-s and a-e notify "only one scope"
- If no subproject markers between cwd and git root: chain = [cwd, git_root]
- Guard against `/` and `$HOME` in exclude patterns
- Preserve search filter (pattern/search) across scope changes
