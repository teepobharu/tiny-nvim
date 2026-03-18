----- MY OVERRIDE SETTINGS ------
-- Global defaults for personal Neovim config.
-- Overridable per-project via .nvim-config.lua (loaded before this file).
-- All vim.g tables use `or` guard so .nvim-config.lua values take precedence.

-- Disabled plugins: core upstream plugins to disable via lazy.nvim spec merging
-- Handled by plugins/extra/disablePlugins.lua which returns { name, enabled = false }
-- Override per-project: set vim.g.disabled_plugins in .nvim-config.lua before this runs
vim.g.disabled_plugins = vim.g.disabled_plugins
  or {
    -- Core plugins to disable when using snacks equivalents
    -- TODO: remove from these init list ideally this part should be empty first accept if the plugin itself is define in a single file or define in extras/disable<plugin>.lua
    "echasnovski/mini.pick", -- using snacks.picker instead (plugins/picker.lua)
    "echasnovski/mini.extra", -- dependency of mini.pick (plugins/picker.lua)
    "echasnovski/mini.starter", -- using snacks.dashboard instead (plugins/starter.lua)
    -- "folke/persistence.nvim", -- session restore in mini.starter (plugins/starter.lua)
    "jellydn/tiny-term.nvim", -- using snacks.terminal instead (plugins/tiny-term.lua)
    "echasnovski/mini.files", -- uncomment to use snacks.explorer (plugins/ui.lua)
    -- "echasnovski/mini.tabline",  -- uncomment to use snacks bufferline (plugins/ui.lua)
  }

-- Extra plugins to load from lua/plugins/extra/
-- ⚠️ load ORDER follows the order defined here unless deps override it
vim.g.enable_extra_plugins = vim.g.enable_extra_plugins
  or {
    "myUi", -- UI overrides for upstream plugins/ui.lua
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
    "myEditor",
    "mySnacks", -- snacks.nvim (picker, dashboard, terminal, explorer, etc.)
    "myCoding",
    "myGit",
    "myAi",
    "myLazyPatcher",
    "disablePlugins", -- must be last to ensure it can override any plugin spec with `enabled = false`
  }

-- vim.g.lazydev_enabled = false -- uncomment this to load all lua dependencies (get access to vim object) will override one in (myopts - require first)

-- extend vim.lsp.enable

-- require to put in lsp dir with same name as below
vim.lsp.enable {
  "bashls",
  "gitlablsp",
  "markdown",
  "yamlls",
  -- 'eslint'
}

vim.g.disable_autoformat = true
