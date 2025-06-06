----- MY OVERRIDE SETTINGS END ------
-- TO OVERRIDE USE THIS
-- load order follow the order define in the key unless it was define as deps ?
vim.g.enable_extra_plugins = {
  "harpoon",
  "wakatime",
  "avante",
  "codecompanion",
  -- "blink",
  "lspsaga",
  "neotree",
  "fzf",
  "fold-preview",
  "myToggleterm",
  "myEditor",
}
-- __AUTO_GENERATED_PRINT_VAR_START__
vim.g.enable_langs = {
  "lua_ls",      -- Lua
  "biome",       -- Biome = Eslint + Prettier
  "json",        -- JSON
  "pyright",     -- Python
  "gopls",       -- Go
  "tailwindcss", -- Tailwind CSS
  -- "rust",
  "typescript",
  "tailwindcss",
}

-- extend vim.lsp.enable

-- require to pit in lsp dir with same name as below
vim.lsp.enable {
  'bashls'
}
