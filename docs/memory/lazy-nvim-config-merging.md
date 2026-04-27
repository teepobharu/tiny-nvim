# Lazy.nvim Config Merging Research

## Overview
This document explains how lazy.nvim merges configurations when multiple plugin directories are specified with potentially overlapping keys.

**Source Code Reference**: Lazy.nvim core modules at `~/.local/share/nvim3_jelly_tinynvim/lazy/lazy.nvim/lua/lazy/core/`
- [`plugin.lua`](#source-files) - Plugin spec parsing and merging
- [`util.lua`](#source-files) - Merge function and helpers
- [`meta.lua`](#source-files) - Plugin metadata and fragments
- [`fragments.lua`](#source-files) - Fragment management

## Current Setup
In your configuration ([`lua/config/lazy.lua`](lua/config/lazy.lua) L20-L29):
```lua
local specs = { { import = "plugins" }, { import = "langs" } }
-- Then for each enabled extra plugin:
table.insert(specs, {
  import = "plugins.extra." .. plugin,
})
```

## How Lazy.nvim Merges Configurations

### 1. **Fragment System**
Lazy.nvim uses a **fragment-based architecture** to manage plugin specs:
- Each spec file creates one or more "fragments"
- Fragments are identified by unique IDs (sequential counter)
- Related fragments maintain parent-child relationships via `pid` (parent ID)

**Key Files** (located in `~/.local/share/nvim3_jelly_tinynvim/lazy/lazy.nvim/lua/lazy/core/`):
- [`fragments.lua`](#source-files) - Manages fragment lifecycle
- [`meta.lua`](#source-files) - Manages plugins and their fragments

### 2. **Parsing Order**
When specs are loaded:
1. **Sequential processing**: Specs are added to `self.fragments` in the order they appear
2. **File ordering**: Within each import path, files are processed in **alphabetical order**
3. **Import chain**: With your setup, order is:
   ```
   1. plugins/* (alphabetically)
   2. langs/* (alphabetically)
   3. plugins.extra.harpoon
   4. plugins.extra.wakatime
   5. plugins.extra.avante
   ... (rest of enabled extras in order from vim.g.enable_extra_plugins)
   ```

### 3. **Merging Rules** (see [`util.lua:440-486`](#source-files))

#### Core Merge Logic
```lua
function M.merge(...)
  local ret = select(1, ...)
  for i = 2, select("#", ...) do
    local value = select(i, ...)
    if can_merge(ret) and can_merge(value) then
      -- Both are non-list tables: recursive deep merge
      for k, v in pairs(value) do
        ret[k] = M.merge(ret[k], v)
      end
    elseif value ~= nil then
      -- One is not a table or is a list: OVERRIDE
      ret = value
    end
  end
  return ret
end
```

#### What Gets Merged vs Overridden

**Mergeable Properties** (extended/deep-merged):
- `opts` - Plugin options table ✅ DEEP MERGED
- `dependencies` - Plugin dependencies ✅ EXTENDED (list)
- `cmd` - Commands ✅ EXTENDED (list)
- `event` - Events ✅ EXTENDED (list)
- `ft` - Filetypes ✅ EXTENDED (list)
- `keys` - Keymaps ✅ EXTENDED (list)

**Non-Mergeable Properties** (last wins):
- `config` - Configuration function ❌ OVERRIDE
- `enabled` - Enable flag ❌ OVERRIDE
- `build` - Build command ❌ OVERRIDE
- `dir` - Directory ❌ OVERRIDE
- `branch` - Git branch ❌ OVERRIDE
- `priority` - Load priority ❌ OVERRIDE
- Any other property ❌ OVERRIDE

### 4. **Handling List-Type Values in opts**

**Default Behavior** (problematic):
If `opts.spec` or `opts.items` is a list and multiple fragments define it:
```lua
-- Fragment 1: plugins/which-key.lua
{ "folke/which-key.nvim", opts = { spec = { mapping1 } } }

-- Fragment 2: plugins.extra.myWhichKey.lua
{ "folke/which-key.nvim", opts = { spec = { mapping2 } } }

-- Result: mapping1 is OVERRIDDEN, not extended ❌
```

**Solution**: Use `opts_extend` (available in lazy.nvim v10.23+):
```lua
-- plugins.extra.myWhichKey.lua
{
  "folke/which-key.nvim",
  opts = {
    spec = { mapping2 }
  },
  opts_extend = { "spec" }  -- Tell lazy to extend this list
}
```

Then lazy will:
1. Keep track of all list values via `plugin[prop .. "_extend"]`
2. After merging: `vim.list_extend(accumulated_list, new_value)`
3. Result: Both mappings are included ✅

### 5. **Practical Example with Your Setup**

Scenario: Multiple fragments define telescope.nvim:

```lua
-- plugins/telescope.lua (loaded first)
{
  "nvim-telescope/telescope.nvim",
  opts = {
    defaults = {
      layout_strategy = "horizontal",
      preview = { width = 0.75 }
    }
  },
  keys = { { "<leader>ff", "<cmd>Telescope find_files<cr>" } }
}

-- plugins.extra.fzf.lua (loaded later, overrides telescope)
{
  "nvim-telescope/telescope.nvim",
  opts = {
    defaults = {
      layout_strategy = "vertical"  -- OVERRIDES horizontal
      -- preview is preserved from plugins/telescope.lua
    }
  },
  keys = { { "<leader>fg", "<cmd>Telescope live_grep<cr>" } }
}

-- FINAL RESULT:
-- opts.defaults = {
--   layout_strategy = "vertical",  -- from fzf (later)
--   preview = { width = 0.75 }     -- from telescope.lua (earlier)
-- }
-- keys = {
--   { "<leader>ff", ... },  -- both keymaps preserved (extended)
--   { "<leader>fg", ... }
-- }
```

### 6. **Fragment Resolution** (see [`meta.lua:71-104`](#source-files))

When a plugin has multiple fragments:
1. Lazy creates a `LazyPlugin` meta object
2. All fragments for that plugin are stored in `meta._.frags` array
3. When building the final config, fragments are merged in order

## Key Insights for Your Configuration

### Current Architecture (see [`lua/config/lazy.lua`](lua/config/lazy.lua))
```lua
local specs = {
  { import = "plugins" },      -- Base plugins
  { import = "langs" }          -- Language support
}
-- Then dynamically add extras based on vim.g.enable_extra_plugins
for _, plugin in ipairs(vim.g.enable_extra_plugins) do
  table.insert(specs, {
    import = "plugins.extra." .. plugin,
  })
end
```

**Implications**:
1. ✅ Extras are loaded LAST → highest precedence for overrides
2. ✅ Order in `vim.g.enable_extra_plugins` determines precedence (later = higher)
3. ✅ Easy to enable/disable extras without modifying core plugins
4. ⚠️ List-type opts values will be OVERRIDDEN (use `opts_extend` to fix)

### Memory Pattern: `myEditor`, `myAi`, etc.
Your pattern of using [`plugins/extra/my<Name>.lua`](lua/plugins/extra/) files is **ideal** for:
- Keeping personal overrides separate from upstream
- Maintaining flexibility (alphabetical ordering doesn't conflict)
- Clear separation of concerns

## Caveats & Common Issues

### Issue 1: List Options Get Overridden
**Problem**: If you define a list in base plugin and override in extra plugin:
```lua
-- plugins/codecompanion.lua
{ "oyslan/codecompanion.nvim", opts = { adapters = { "Claude" } } }

-- plugins.extra.myAi.lua
{ "oyslan/codecompanion.nvim", opts = { adapters = { "Custom" } } }

-- Result: only "Custom" adapter (overwrites base)
```

**Solution**: 
```lua
-- plugins.extra.myAi.lua
{
  "oyslan/codecompanion.nvim",
  opts = {
    adapters = { "Custom" }
  },
  opts_extend = { "adapters" }  -- Extend instead of override
}
```

### Issue 2: Deep Table Merging Complexity
Lazy's merge is **deep but destructive** for nested keys:
```lua
-- Fragment 1
{ a = { b = 1, c = 2 } }

-- Fragment 2
{ a = { b = 99 } }

-- Result: { a = { b = 99, c = 2 } } ✅ Works fine
```

But beware of intermediate tables being replaced entirely.

### Issue 3: `enabled = false` in one fragment silently kills the plugin

If any fragment has `enabled = false` and no later fragment overrides it with `enabled = true`,
lazy.nvim treats the merged plugin as disabled — it is **not registered at all**, and every
`keys`, `opts`, `config`, and `event` from *all* fragments is dropped. There is no warning;
keymaps simply do not appear and `Lazy.plugins["<name>"]` returns `nil`.

```lua
-- plugins/extra/avante.lua  (older "migrated" stub)
{ "yetone/avante.nvim", enabled = false, opts = { ... }, config = function() ... end }

-- plugins/extra/myAi.lua  (intended new home)
{ "yetone/avante.nvim", opts = { ... }, keys = { ... } }
-- ⇒ avante.nvim is DISABLED. <leader>r* keymaps silently stop working.
```

**Fix**: explicitly add `enabled = true` to the later fragment to flip it back on, or remove
`enabled = false` from the older stub. See [`lua/plugins/extra/myAi.lua`](lua/plugins/extra/myAi.lua)
avante spec for an example.

**Detection** (headless):
```sh
NVIM_APPNAME=nvim3_jelly_tinynvim nvim --headless \
  -c 'lua print(require("lazy.core.config").plugins["avante.nvim"] and "registered" or "MISSING")' \
  -c 'qa'
```

### Issue 4: Function References in Config
`config` functions **cannot be merged**:
```lua
-- plugins/snacks.lua
{ "folke/snacks.nvim", config = function() ... end }

-- plugins.extra.mySnacks.lua
{ "folke/snacks.nvim", config = function() ... end }

-- Result: plugins.extra.mySnacks config WINS (later fragment)
```

**Solution**: Use `opts` + hooks instead of `config` functions when possible.

## How Lazy.nvim Determines Plugin Identity

A plugin is identified by (in order of precedence):
1. **Plugin name** from spec (explicit `name` key)
2. **URL** (github repo URL)
3. **Dir** (local directory path)

This means overlapping keys are detected when any of these match across fragments.

## Testing Your Configuration

To verify merge behavior in your config:

```lua
-- In your init.lua or a test file
local lazy = require("lazy")
-- After lazy.setup() completes:
for name, plugin in pairs(lazy.plugins()) do
  if plugin.opts then
    print(name .. " opts:", vim.inspect(plugin.opts))
  end
end
```

This will show the final merged opts for each plugin.

## Recommendations for Your Setup

### ✅ Current Best Practices You're Following
1. Using `plugins/extra/my<Name>.lua` pattern - Perfect for overrides
2. Dynamic loading via `vim.g.enable_extra_plugins` - Flexible
3. Alphabetical separation (my* files won't conflict with upstream)

### 🔧 Improvements to Consider
1. **Document `opts_extend` usage** in any my\*.lua that extends lists
2. **Check comment at line 3 of mydefault-nvim-config.lua**:
   ```lua
   -- load order follow the order define in the key unless it was define as deps ?
   ```
   This is MOSTLY CORRECT but clarify: "Order follows spec array order + alphabetical within import paths"

3. **For snacks plugin**, verify it handles merging correctly:
   ```lua
   -- Comment in config says: "error when removed - error when no extra dir"
   -- This suggests circular dependency or load ordering issue to investigate
   ```

## References
- **lazy.nvim Github**: https://github.com/folke/lazy.nvim
- **Lazy Docs**: https://lazy.folke.io/spec
- **Source**: `~/.local/share/nvim3_jelly_tinynvim/lazy/lazy.nvim/lua/lazy/core/`
  - `plugin.lua` - Plugin spec parsing and merging (L440-486)
  - `util.lua` - Merge function and helpers
  - `meta.lua` - Plugin metadata and fragments
  - `fragments.lua` - Fragment management

---
**Last Updated**: 2026-01-29
**Researched By**: Crush
