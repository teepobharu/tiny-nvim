----- MY OVERRIDE SETTINGS ------
-- Global defaults for personal Neovim config.
-- Overridable per-project via .nvim-config.lua (loaded before this file).
-- Use these commands to configure the project easily
-- :ProjectSettings
-- :ProjectSettingEditPicker

-- Disabled plugins: single-file core plugins to disable via lazy.nvim spec merging
-- Handled by plugins/extra/disablePlugins.lua which returns { name, enabled = false }
-- For group-level disables, use xx<Name>.lua mute files instead (see enable_extra_plugins).
-- Override per-project: set vim.g.disabled_plugins in .nvim-config.lua before this runs
vim.g.disabled_plugins = vim.g.disabled_plugins
  or {
    -- Single-file core plugins with no group owner
    "jellydn/tiny-term.nvim", -- using snacks.terminal (plugins/tiny-term.lua)
  }

-- Extra plugins to load from lua/plugins/extra/
-- ⚠️ load ORDER follows the order defined here unless deps override it
vim.g.enable_extra_plugins = vim.g.enable_extra_plugins
  or {
    -- UI overrides
    "myUi", -- UI overrides for upstream plugins/ui.lua
    -- Mute switches for core plugin groups (uncomment to disable)
    "xxMiniUi", -- mute mini UI/picker/starter (use snacks equivalents)
    -- "xxMiniCode",        -- mute mini.pairs, mini.ai (coding helpers)
    -- "xxMini",            -- mute ALL mini.* (do NOT combine with xxMiniUi/xxMiniCode)
    -- "xxTest",            -- mute test runners (vim-test, neotest)
    -- "xxRunner",          -- mute task runners (overseer, quick-code-runner, hurl)
    -- "xxLegacyCopilotAi", -- mute legacy CopilotChat
    -- Plugin-level extras
    "harpoon",
    "wakatime",
    "avante",
    -- "codecompanion", -- TODO: after refactor out to myAi should we remove this ?
    -- "blink",
    "claude-code", -- "extras.claudecode" looks config also same not sure why
    "greggh-claude", -- simple claude code
    "lspsaga",
    "neotree",
    "fzf",
    "fold-preview",
    "myToggleterm",
    "snacks", -- above myEditor, mySnacks in case need override
    -- Personal override groups (load after extras they override)
    "myEditor",
    "mySnacks", -- snacks.nvim (picker, dashboard, terminal, explorer, etc.)
    "myCoding",
    "myGit",
    "myAi",
    "myLazyPatcher",
    -- Disable mechanism (must be LAST)
    "disablePlugins",
  }

-- vim.g.lazydev_enabled = false -- uncomment this to load all lua dependencies (get access to vim object) will override one in (myopts - require first)

-- extend vim.lsp.enable

-- require to put in lsp dir with same name as below
vim.lsp.enable {
  "bashls",
  "gitlablsp",
  "markdown",
  "yamlls",
  -- 'eslint' -- oxlint --**disableInit
}

vim.g.follow_current_file_enabled = true
vim.g.picker_source_default_opts = vim.g.picker_source_default_opts
  or {
    files = {
      hidden = false,
      ignored = false,
      follow = false,
    },
    grep = {
      hidden = false,
      ignored = false,
      follow = false,
      regex = true,
      case_mode = "smart",
    },
    grep_word = {
      hidden = false,
      ignored = false,
      follow = false,
      regex = false,
      case_mode = "smart",
    },
  }
-- ~/.config/nvim3_jelly_tinynvim/lua/config/options.lua
-- ~/.config/nvim3_jelly_tinynvim/lua/config/myopts.lua
-- vim.opt.tabstop = 2 -- show tab as n<space> default 8 ?
-- vim.opt.shiftwidth = 2 -- ts_ls format
vim.g.disable_autoformat = true
vim.g.snacks_debug_external_filter = true
-- vim.g.snacks_debug_picker_persist = true
vim.opt.cmdheight = 2 -- Hide message continue prompt startup when has is <=2 line
-- vim.opt.shortmess:append("IFc") -- remove "I" for startup message, "F" for file info, "c" for completion messages (e.g. "match 1 of 2")
