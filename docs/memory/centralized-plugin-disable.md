# Centralized Plugin Disable System

## Overview

Mechanism to disable upstream core plugins (e.g., mini.pick, mini.starter, tiny-term) without editing `lua/plugins/*.lua` files directly. Uses lazy.nvim's spec fragment merging.

## How It Works

1. `vim.g.disabled_plugins` is set in `lua/config/mydefault-nvim-config.lua` (with `or` guard for per-project override)
2. `lua/plugins/extra/disablePlugins.lua` reads this list and returns `{ "plugin/name", enabled = false }` specs
3. Lazy.nvim merges these fragments with the original specs from `plugins/*.lua`, disabling the plugins

## Load Order (Critical)

```
init.lua L7-15:   dofile(".nvim-config.lua")             -- (1) project overrides
config/lazy.lua:  require("config.mydefault-nvim-config") -- (2) global defaults (uses `or` guard)
config/lazy.lua:  build specs from vim.g tables            -- (3) reads disabled + enabled lists
config/lazy.lua:  lazy.setup(specs)                        -- (4) evaluates enabled fields
```

Because `.nvim-config.lua` runs before `mydefault-nvim-config.lua`, and the defaults use `vim.g.X = vim.g.X or { ... }`, project files can override any default.

## Configuration

### Global defaults (`lua/config/mydefault-nvim-config.lua`)

```lua
vim.g.disabled_plugins = vim.g.disabled_plugins or {
  -- Single-file core plugins with no group owner
  "jellydn/tiny-term.nvim",     -- using snacks.terminal
}
-- For group-level disables, use xx<Name>.lua mute files (see enable_extra_plugins)
```

### Per-project override (`.nvim-config.lua`)

```lua
-- Disable nothing — use all upstream mini plugins in this project
vim.g.disabled_plugins = {}

-- Or disable only specific plugins
vim.g.disabled_plugins = { "echasnovski/mini.pick" }
```

## Commands

| Command | Description |
|---------|-------------|
| `:DisabledPlugins` | Show currently disabled plugins |
| `:ProjectSettingEditPicker` | Snacks picker with two modes (M-s to switch) |
| `:DisablePluginsPicker` | Alias for `ProjectSettingEditPicker` |
| `:ProjectSettings` | Create/update `.nvim-config.lua` with embedded defaults reference |
| `:ProjectSettingsReload` | Regenerate reference block and reload settings |

### ProjectSettingEditPicker Modes & Keybinds

**Mode 1** (default): `vim.g.disabled_plugins` — browse all lazy.nvim plugins  
**Mode 2** (`M-s`): `vim.g.enable_extra_plugins` — browse `plugins/extra/` files

Footer shows current mode. Status column uses highlight colors:
- `DiagnosticOk` (green) = enabled
- `DiagnosticError` (red) = disabled
- `DiagnosticWarn` (yellow) = missing! (in vim.g but file not on disk)

| Key | Action |
|-----|--------|
| `<Tab>` | Select/deselect item |
| `<C-a>` | Select all |
| `<CR>` | Copy selected names (newline-separated) |
| `<C-y>` | Copy as `vim.g.*` config block |
| `<C-w>` | Write selected to `.nvim-config.lua` (append/replace block) |
| `<C-e>` | Open `.nvim-config.lua` in editor |
| `<M-s>` | Switch between disabled/extras mode |
| `<C-d>` | Toggle filter: disabled only |
| `<C-n>` | Toggle filter: enabled only |
| `<C-x>` | Reset filter (show all) |

**Mode 1 only** (disabled plugins — items are `owner/repo` format):

| Key | Action |
|-----|--------|
| `<C-g>` | Open plugin's GitHub page in browser |
| `<C-r>` | Open plugin's GitHub releases page in browser |

## .nvim-config.lua Marker System

When `:ProjectSettings` or `:ProjectSettingsReload` runs, it embeds a commented-out copy of `mydefault-nvim-config.lua` between markers:

```
-- ──── NVIM DEFAULT CONFIG REFERENCE (auto-generated) DO NOT EDIT BETWEEN MARKERS ────
-- Source: ~/.config/nvimwt3a/lua/config/mydefault-nvim-config.lua
-- ...commented out defaults...
-- ──── END NVIM DEFAULT CONFIG REFERENCE ────

-- User's project-specific overrides are preserved here
```

Content outside the markers is preserved on regeneration.

## Copilot disable flag

Single boolean toggle `vim.g.ai_enable_copilot` (default `false`) drives every
Copilot-backed plugin/provider/keymap inside personal `my*` files:

- `myAi.lua` — `github/copilot.vim`, `CopilotChat.nvim`, mcphub `copilotchat` extension, avante `copilot` provider, codecompanion `copilot` http adapter.
- `myCoding.lua` — blink.cmp `fang2hou/blink-copilot` dep + `copilot` source.

Flip per project via `.nvim-config.lua`:

```lua
vim.g.ai_enable_copilot = true
```

Upstream `extra/copilot-*.lua` files keep their existing `vim.g.enable_extra_plugins` list gate — out of scope here.

## xx Mute Switch Files

Group-level mute switches for multi-spec core plugin files. Each `xx<Name>.lua` returns `{ "plugin/name", enabled = false }` specs for the **unique** plugins in that core file (shared plugins like which-key are NOT affected).

| File | Mutes | Source |
|------|-------|--------|
| `xxMiniUi.lua` | mini.pick, mini.extra, mini.starter, mini.icons, mini.statusline, mini.tabline, mini.bufremove, mini.files, mini.diff | plugins/picker.lua, starter.lua, ui.lua |
| `xxMiniCode.lua` | mini.pairs, mini.ai | plugins/coding.lua |
| `xxMini.lua` | ALL mini.* (combines xxMiniUi + xxMiniCode) | meta-mute |
| `xxTest.lua` | vim-test, neotest | plugins/test.lua |
| `xxRunner.lua` | overseer, quick-code-runner, hurl | plugins/runner.lua |
| `xxLegacyCopilotAi.lua` | CopilotChat | plugins/_legacyCopilotai.lua |

### Usage

```lua
-- In vim.g.enable_extra_plugins (mydefault-nvim-config.lua or .nvim-config.lua)
"xxMiniUi",          -- active by default: mute mini UI, use snacks instead
-- "xxTest",          -- uncomment to mute test runners
-- "xxRunner",        -- uncomment to mute task runners
```

### Design Rules

- `xx` files only disable **unique** plugins from their source file (not shared ones like which-key)
- `myUI.lua` keeps its own `enabled = false` entries as a redundant safety net
- `vim.g.disabled_plugins` holds only single-file plugins with no group owner (e.g., tiny-term)
- `disablePlugins.lua` must be LAST in `enable_extra_plugins` to act as final authority
- Do NOT use `xxMini` together with `xxMiniUi`/`xxMiniCode` — pick one level

## Files

| File | Role |
|------|------|
| `lua/plugins/extra/disablePlugins.lua` | Core mechanism: reads `vim.g.disabled_plugins`, returns `enabled=false` specs |
| `lua/plugins/extra/xxMiniUi.lua` | Group mute: mini UI/picker/starter plugins |
| `lua/plugins/extra/xxMiniCode.lua` | Group mute: mini coding helpers |
| `lua/plugins/extra/xxMini.lua` | Meta mute: all mini.* plugins |
| `lua/plugins/extra/xxTest.lua` | Group mute: test runners |
| `lua/plugins/extra/xxRunner.lua` | Group mute: task runners |
| `lua/plugins/extra/xxLegacyCopilotAi.lua` | Group mute: legacy CopilotChat |
| `lua/plugins/extra/myUI.lua` | UI overrides + redundant mini disables for its own scope |
| `lua/config/mydefault-nvim-config.lua` | Global defaults with `or` guards |
| `lua/plugins/extra/myproject.lua` | `:ProjectSettings` command with marker template |

## Gotchas

- `enabled = false` in lazy.nvim: the **last fragment wins** for non-table values. Since extras load after core plugins, `disablePlugins.lua`'s `enabled = false` overrides the core spec.
- `"disablePlugins"` must be in `vim.g.enable_extra_plugins` to be imported by lazy.lua.
- Plugin names must match exactly (e.g., `"echasnovski/mini.pick"` not `"mini.pick"`).
- Changes to `vim.g.disabled_plugins` require Neovim restart (lazy evaluates at startup).
- Shared plugins (which-key, treesitter, render-markdown) appear in multiple core files — disabling them in any `xx` file would affect all files. Only disable **unique** plugins per group.

## Related

- [lazy-nvim-config-merging.md](lazy-nvim-config-merging.md) — how lazy.nvim merges spec fragments
- [rebase-safe-plugin-overrides.md](rebase-safe-plugin-overrides.md) — concise ownership and toggle layering guideline
- `lua/utils/keyutil.lua` — `isSnackEnabled` flag used for keymap prefix switching
