----- MY OVERRIDE SETTINGS END ------
-- TO OVERRIDE USE THIS
-- load order follow the order define in the key unless it was define as deps ?
-- TODO add extra filtering logic out if the root project specific config defined by user need to disable
-- check duplicate require if needed init vs lazy
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
  "myCoding",
  "myGit",
  "myAi",
  "snacks", -- error when removed - error when no extra dir so create dummy {}
}

-- vim.g.lazydev_enabled = false -- uncomment this to load all lua dependencies (get access to vim object) will override one in (myopts - require first)

-- extend vim.lsp.enable

-- require to pit in lsp dir with same name as below
vim.lsp.enable {
  "bashls",
  "gitlablsp",
  "markdown",
  "yamlls",
  -- 'eslint'
}
