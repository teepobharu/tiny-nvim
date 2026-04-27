# Snacks Picker Memory Bank

## Critical Patterns & Caveats

### 1. Items Must Have `text` Field

**Problem**: "attempt to index local 'str' (a nil value)" error in matcher.lua:524
**Root Cause**: Snacks picker matcher requires a `text` field on all items for filtering/matching
**Pattern**: When creating picker items:

```lua
table.insert(items, {
  text = item_display_text,  -- REQUIRED: this is what gets matched
  file = item_path,          -- optional: for file pickers
  -- other fields...
})
```

**Reference**: lua/utils/snacks_pickers.lua:40-42

### 2. Static vs Dynamic Item Sources

**Static items** (use when list doesn't change):

```lua
Snacks.picker.pick {
  items = static_list,  -- Direct list
  -- ...
}
```

**Dynamic items** (use when list can change):

```lua
Snacks.picker.pick {
  finder = function(_opts, _ctx)
    local items = scan_source()  -- Rescanned on each refresh
    return items
  end,
  -- ...
}
```

**Reference**: lua/utils/snacks_pickers.lua:29-63

### 3. Picker Refresh Without Closing

**Pattern**: Keep picker open after save/delete operations

```lua
-- DO NOT close picker
-- picker:close()  -- ❌ Wrong

-- Instead, refresh after operation
vim.cmd("SDelete! " .. session)
vim.notify("Deleted", vim.log.levels.INFO)
vim.defer_fn(function()
  picker:refresh()  -- Rescans finder function
end, 100)  -- 100ms delay to let filesystem sync
```

**Why defer_fn**: Avoids race conditions when filesystem isn't immediately updated
**Reference**: lua/utils/snacks_pickers.lua:91-108

### 5. Function Parameter Requirements

**Issue**: `snacks_action_factories.create_git_file_actions` requires 2 parameters

```lua
-- ❌ Wrong - missing second parameter
local actions = create_git_file_actions("HEAD~1")

-- ✓ Correct - with no_resolve flag
local actions = create_git_file_actions("HEAD~1", false)
```

**Parameters**:

- `ref_provider`: Git reference to use
- `no_resolve`: boolean - if true, skip ref resolution
  **Reference**: lua/utils/snacks_pickers.lua:220, 333

### 6. Capturing Source Buffer Info in Finder

**⚠️ CRITICAL CAVEAT**: When accessing the current buffer's filetype/properties in a finder function, **always use `picker.main`** to get the source window, NOT `vim.bo.ft`.

**Problem**: Inside a finder function called from `picker:find()`, the active buffer is the **picker input buffer** (`snacks_picker_input`), not the original source buffer.

```lua
finder = function(_, ctx)
  -- ❌ WRONG - reads from picker input buffer
  local ft = vim.bo.ft  -- Returns "snacks_picker_input"

  -- ✓ CORRECT - reads from original source window
  local source_buf = vim.api.nvim_win_get_buf(ctx.picker.main)
  local source_ft = vim.bo[source_buf].filetype

  -- Use source_ft for all source-buffer-aware logic
end
```

**Why this matters**:

- The picker temporarily changes the active buffer to the input prompt
- Direct `vim.bo` access returns the picker's own buffer properties
- `picker.main` preserves the original window reference across the picker lifetime
- This is especially critical when toggling filters or refreshing the finder

**Use case**: Snippets picker that filters by current buffer's filetype - when user presses the toggle key, `picker:find()` is called and the finder runs again, but `vim.bo.ft` would return "snacks_picker_input" instead of "lua" (or whatever the source was).

**Reference**: lua/utils/snacks_pickers.lua:2190-2191 (LuaSnip snippets picker implementation)

### 7. Scope Persistence vs Scope Toggle in Buffer Transforms

**Problem**: Buffer picker scope looked unfiltered after selecting subproject scope (`<M-S>`), but external mode (`<M-e>`) still used that scope.

**Root Cause**: Transform logic only treated transient `_buffer_scope_cwd` as "has scope". Persisted scope (`vim.g.picker_buffer_cwd_state_value`) was read later for path checks, but was not counted in the "scope active" gate.

**Pattern**:

```lua
local scope_cwd = picker.opts._buffer_scope_cwd
if scope_cwd == nil then
  scope_cwd = vim.g.picker_buffer_cwd_state_value
end
local has_scope = type(scope_cwd) == "string" and scope_cwd ~= ""
```

If `has_scope` ignores persisted scope, non-external mode returns all buffers early.

### 8. Traversal Chain Must Start From Active Picker CWD

**Problem**: External/scope traversal used an old persisted directory instead of the picker's current scope.

**Root Cause**: Traversal init prioritized global persisted cwd over `picker.opts.cwd`.

**Pattern**:

```lua
local initial_cwd = picker.opts.cwd or vim.g[persist_key] or vim.fn.getcwd()
```

Always prefer active picker scope first; persisted state should be fallback.

### 9. `toggle_<name>` Action Name Collision with Snacks Toggles

**Problem**: Custom `toggle_external` action stops working for file pickers; keypress only flips a boolean and does not apply custom cwd/exclude logic.

**Root Cause**: Snacks auto-generates `toggle_<toggle_name>` actions from `opts.toggles` during config init, and this overwrites user actions with the same key (e.g. `toggle_external`).

**Pattern**:

- Avoid naming custom actions as `toggle_<name>` when `<name>` exists in `opts.toggles`.
- Use a non-colliding action name (e.g. `toggle_external_scope`) and map keys to that action.

This keeps custom external traversal logic intact while still using the `external` toggle state for UI/title indicators.

## Actions

https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/actions.lua

ask in : https://deepwiki.com/search/is-there-copy-action-and-how-d_e0314aa4-42c3-4052-878a-ab59592d04ec?mode=fast

## Debugging Tips

### Picker Item Structure Issues

If getting matcher errors:

1. Check all items have `text` field (required for format="text")
2. Use `finder` function for dynamic data
3. Verify item structure matches picker format type

### Refresh Not Working

- Use `vim.defer_fn()` with ~100ms delay after file operations
- Direct `picker:refresh()` doesn't reschedule if timing is off
- Test with print statements to verify refresh is called

### Resume Behavior

- Check `resume = false` to prevent unwanted cached state
- Useful for pickers showing dynamic data (sessions, terminals, etc)

## Related Files

- lua/utils/snacks_pickers.lua - Main picker implementations
- lua/utils/snacks_actions.lua - Picker action handlers
- ~/.local/share/nvim/lazy/snacks.nvim - Official snacks source

## Session Picker Implementation

**File**: `lua/utils/snacks_pickers.lua:146-430`
**Keymap**: `<leader>fs`
**Two sources, toggled with `<M-s>`**:

### Startify source (default)

- Dynamic finder scans `vim.g.startify_session_dir` on refresh
- Items: `{ text = name, file = path }` — name must match `^[%a%d][%w_]*$`
- **Enter**: `:SLoad <name>`
- **C-s**: `:SSave! <name>` (uses query input or selection, prompts if empty)
- **C-x**: `:SDelete! <name>` with Yes/No confirmation
- **M-s**: Toggle to Persistence source

### Persistence source

- Uses `require("persistence").list()` → sorted by mtime
- Items: `{ text = display, dir = resolved_path, branch = string|nil, session = file_path }`
- **Enter**: `vim.fn.chdir(item.dir)` then sources the specific session file directly
- **C-s**: `persistence.save()` (saves **current CWD**, not selected item — no custom name support)
- **C-x**: `uv.fs_unlink(item.session)` async with confirmation
- **M-s**: Toggle back to Startify source

### Persistence filename encoding caveat

persistence.nvim encodes session files as: `cwd:gsub("[\\/:]+", "%%")` (init.lua:13).
In Lua gsub **replacement**, `%%` means a **literal single `%`** character.
So `/Users/foo/project` becomes filename `%Users%foo%project.vim` (single `%` separators).

Branch is appended with `"%%" ..` (Lua string literal `%%` = two literal percent signs):
`%Users%foo%project%%feature-branch.vim`

To decode (mirrors persistence's own select() at init.lua:112-114):

```lua
local dir_encoded, branch = unpack(vim.split(encoded, "%%", { plain = true }))
local dir = dir_encoded:gsub("%%", "/")  -- gsub pattern "%%" matches literal "%"
```

**Key insight**: `%%` means different things in different Lua contexts:

- In `string.gsub` replacement: literal `%` (so replacement `"%%"` → single `%` in output)
- In `string.gsub` pattern: literal `%` (so pattern `"%%"` matches single `%` in input)
- In string literals: just `%%` (two characters, no escaping — `%` is not special in literals)

### Toggle pattern (close + defer_fn reopen)

```lua
toggle_source = function(picker, _item)
  picker:close()
  vim.defer_fn(function()
    M.session_picker("persistence")  -- or "startify"
  end, 50)
end
```

The 50ms defer allows the first picker to fully close before opening the next.

### Caveat: persistence C-s saves current CWD, not selected item

Unlike Startify where C-s saves the selected/typed session name, persistence.save() always
saves the **current working directory** session. No custom name support — it's always per-CWD
(+ branch if configured). The selected item's dir is only used on Enter (load).

### Caveat: confirm sources session file directly

The confirm action uses `vim.cmd("silent! source " .. fnameescape(item.session))` instead of
`persistence.load()` because `persistence.load()` re-derives the session path from the new CWD
via `persistence.current()`, which may not match the selected item if the branch differs.

### To fix

Testing

- TO confirm branch shown show `%%` text in item display when the have `/` in the branch name

---

### Key Callbacks: `win.input.keys` vs `actions`

**Caveat**: `function(picker, item)` signature only works in `actions = {}` config. In `win.input.keys` (and `win.list.keys`), the callback receives `snacks.win` — NOT the picker. `item` is always `nil`.

**Wrong** (keys config — `item` is always nil):
```lua
win = {
  input = {
    keys = {
      ["<M-e>"] = {
        function(picker, item)  -- item is ALWAYS nil here
          -- picker is snacks.win, not the real picker
        end,
      },
    },
  },
},
```

**Correct** — fetch the real picker via `Snacks.picker.get`:
```lua
win = {
  input = {
    keys = {
      ["<M-e>"] = {
        function()
          local picker = (Snacks.picker.get { source = "my_source" })[1]
          if not picker then return end
          local item = picker:current()
          if not item then return end
          -- ...
        end,
        mode = { "n", "i" },
        desc = "...",
      },
    },
  },
},
```

**Rule**: Only define keys in `win.input.keys` (not `win.list.keys` — redundant and can conflict). Use `actions = {}` if you need `(picker, item)` signature directly.
