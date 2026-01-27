# Keybinding Conflicts Resolution

## Overview
This document tracks resolved keybinding conflicts between plugins, specifically for `c-f`, `c-j`, and `c-p` combinations.

## Snacks.nvim Picker Keybindings

### Default Bindings (Disabled)
- **`<c-f>`** → `preview_scroll_down` - Scroll preview window down
- **`<c-j>`** → `list_down` - Move down in picker list
- **`<c-p>`** → `list_up` - Move up in picker list

### Configuration Location
File: [lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua:5-27)

### How to Disable
```lua
{
  "folke/snacks.nvim",
  opts = {
    picker = {
      win = {
        input = {
          keys = {
            ["<c-f>"] = false,
            ["<c-j>"] = false,
            ["<c-p>"] = false,
          },
        },
        list = {
          keys = {
            ["<c-f>"] = false,
            ["<c-j>"] = false,
            ["<c-p>"] = false,
          },
        },
      },
    },
  },
}
```

### Source Reference
- Default keybindings: `~/.local/share/nvim3_jelly_tinynvim/lazy/snacks.nvim/lua/snacks/picker/config/defaults.lua:249-254,304-308`
- Applied in both `input` and `list` windows

## Sidekick.nvim CLI Terminal Keybindings

### Default Bindings (Disabled)
- **`<c-b>`** → `buffers` - Open buffer picker
- **`<c-f>`** → `files` - Open file picker (mode: `nt`)
- **`<c-h>`** → `nav_left` - Navigate to left window (mode: `t`, expr, conditional)
- **`<c-j>`** → `nav_down` - Navigate to window below (mode: `t`, expr, conditional)
- **`<c-k>`** → `nav_up` - Navigate to window above (mode: `t`, expr, conditional)
- **`<c-l>`** → `nav_right` - Navigate to right window (mode: `t`, expr, conditional)
- **`<c-p>`** → `prompt` - Insert prompt or context (mode: `t`)

### Alternative Bindings (Alt/Meta Keys)
Remapped to avoid conflicts, using Alt keys (avoiding `<a-f>` and `<a-b>` for terminal word navigation):
- **`<a-r>`** → `buffers` - Open buffer picker (recent)
- **`<a-e>`** → `files` - Open file picker (edit/explorer)
- **`<a-p>`** → `prompt` - Insert prompt or context

### Configuration Location
File: [lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua:4-40)

**Note:** Includes custom `config` function to remove tmux-navigator keybindings in sidekick terminal buffers

### How to Configure
```lua
{
  "folke/sidekick.nvim",
  opts = {
    cli = {
      win = {
        keys = {
          -- Disable conflicting Ctrl keybindings
          buffers = false,    -- disables <c-b>
          files = false,      -- disables <c-f>
          prompt = false,     -- disables <c-p>
          nav_left = false,   -- disables <c-h>
          nav_down = false,   -- disables <c-j>
          nav_up = false,     -- disables <c-k>
          nav_right = false,  -- disables <c-l>

          -- Remap to Alt/Meta keys (avoiding a-f, a-b for word navigation)
          files_alt = { "<a-e>", "files", mode = "nt", desc = "open file picker" },
          buffers_alt = { "<a-r>", "buffers", mode = "nt", desc = "open buffer picker" },
          prompt_alt = { "<a-p>", "prompt", mode = "t", desc = "insert prompt" },
        },
      },
    },
  },
  config = function(_, opts)
    require("sidekick").setup(opts)

    -- Remove tmux-navigator keybindings in sidekick terminal
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "sidekick_terminal",
      callback = function(ev)
        pcall(vim.keymap.del, "t", "<C-h>", { buffer = ev.buf })
        pcall(vim.keymap.del, "t", "<C-j>", { buffer = ev.buf })
        pcall(vim.keymap.del, "t", "<C-k>", { buffer = ev.buf })
        pcall(vim.keymap.del, "t", "<C-l>", { buffer = ev.buf })
      end,
    })
  end,
}
```

### Source Reference
- Default keybindings: `~/.local/share/nvim3_jelly_tinynvim/lazy/sidekick.nvim/lua/sidekick/config.lua:63-80`
- Mode notation: `"nt"` = normal + terminal, `"t"` = terminal only, `"n"` = normal only

### Other Sidekick CLI Keybindings (Still Active)

```lua
hide_n        = { "q"    , "hide"      , mode = "n" , desc = "hide the terminal window" }
hide_ctrl_q   = { "<c-q>", "hide"      , mode = "n" , desc = "hide the terminal window" }
hide_ctrl_dot = { "<c-.>", "hide"      , mode = "nt", desc = "hide the terminal window" }
hide_ctrl_z   = { "<c-z>", "hide"      , mode = "nt", desc = "hide the terminal window" }
stopinsert    = { "<c-q>", "stopinsert", mode = "t" , desc = "enter normal mode" }
```

## Implementation Details

### Snacks Picker
- Keybindings must be disabled in both `input` and `list` windows
- Setting a key to `false` completely removes the binding
- Default bindings are defined in `defaults.lua` and merged with user config

### Sidekick CLI Terminal
- Uses named keybindings (e.g., `files`, `prompt`) instead of key literals
- Keybindings are processed in `terminal.lua:keys()` method (line 498)
- Keys are merged: `vim.tbl_extend("force", {}, self.opts.keys, self.tool.keys or {})`
- Setting a named key to `false` prevents it from being registered

### Tmux-Navigator Conflict
**Issue:** The `vim-tmux-navigator` plugin ([lua/plugins/tmux-navigator.lua](lua/plugins/tmux-navigator.lua:26-29)) binds `<c-h>`, `<c-j>`, `<c-k>`, `<c-l>` in terminal mode globally, which conflicts with sidekick terminal.

**Solution:** Custom `config` function in `myAi.lua` that:
1. Sets up sidekick with disabled navigation keys
2. Adds a `FileType` autocmd for `sidekick_terminal` buffers
3. Removes tmux-navigator keybindings using `vim.keymap.del` with `pcall` (to avoid errors if keys don't exist)
4. Only affects sidekick terminal buffers, leaving tmux-navigator functional elsewhere

**Why both approaches needed:**
- Disabling in `opts.cli.win.keys` prevents sidekick from creating the bindings
- Autocmd with `vim.keymap.del` removes tmux-navigator's global terminal mode bindings in sidekick buffers

## Rationale

These keybindings were disabled to prevent conflicts with:
- Other plugin keybindings
- User workflow preferences
- Potential terminal/shell keybinding conflicts

## Alternative Keybindings

### Snacks Picker
- Preview scroll: Use `<c-b>` (up) which is still available
- List navigation: Use `<Down>`/`<Up>`, `j`/`k`, or `<c-n>`/`<c-k>`

### Sidekick CLI (Remapped to Alt Keys)
The original Ctrl-based actions are now available via Alt keys:
- **`<a-e>`** - Open file picker (was `<c-f>`)
- **`<a-r>`** - Open buffer picker (was `<c-b>`)
- **`<a-p>`** - Insert prompt (was `<c-p>`)

**Note:** `<a-f>` and `<a-b>` are avoided as they're commonly used for forward-word and backward-word navigation in terminal mode.

## Testing

After making these changes:
1. Restart Neovim or reload config: `:Lazy reload snacks.nvim` and `:Lazy reload sidekick.nvim`
2. Test snacks picker: `<leader><space>` (find files) and verify `<c-f>`, `<c-j>`, `<c-p>` don't trigger actions
3. Test sidekick terminal: `<leader>aa` and verify the disabled keys don't work
4. Check for any error messages: `:messages`

## Related Files
- [lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua) - Custom AI keybinding overrides
- [lua/plugins/snacks.lua](lua/plugins/snacks.lua) - Base snacks configuration
- [lua/plugins/ai.lua](lua/plugins/ai.lua) - Base AI plugin configuration
- [lua/plugins/tmux-navigator.lua](lua/plugins/tmux-navigator.lua) - Source of navigation key conflicts
- [lua/config/mydefault-nvim-config.lua](lua/config/mydefault-nvim-config.lua:17) - Enables myAi extra
- [docs/memory/snacks.md](docs/memory/snacks.md) (if exists)
- [docs/memory/gitsigns.md](docs/memory/gitsigns.md) (similar keybinding patterns)

## Architecture

Custom configurations follow the project's pattern:
- **Base configs**: `lua/plugins/*.lua` - Plugin registration and standard settings
- **Custom overrides**: `lua/plugins/extra/my*.lua` - User-specific modifications
- **Enable extras**: `lua/config/mydefault-nvim-config.lua` via `vim.g.enable_extra_plugins`

This separation allows:
- Easy updates to base plugin configs without losing custom settings
- Clear distinction between standard and custom configurations
- Modular loading of custom features
