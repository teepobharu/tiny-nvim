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
  -- "fold-preview",
  "myToggleterm",
  "myEditor",
}

-- vim.g.lazydev_enabled = false -- uncomment this to load all lua dependencies (get access to vim object)

-- extend vim.lsp.enable

-- require to pit in lsp dir with same name as below
vim.lsp.enable {
  'bashls'
}
