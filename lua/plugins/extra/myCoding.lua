-- Personal coding overrides kept out of core plugin specs
return {
  {
    "L3MON4D3/LuaSnip",
    opts = {
      store_selection_keys = "<C-s>",
    },
    -- more info https://www.dmsussman.org/resources/luasnippets/
    -- dynamic snippets : code ref is mapped here : lua/config/mykeymaps.lua:146
    config = function(_, opts)
      local ls = require "luasnip"
      local s = ls.snippet
      local f = ls.function_node

      ls.config.setup(opts)

      -- Add minimal absolute ref snippet (kept for backward compat)
      ls.add_snippets("all", {
        s("refAbs", {
          f(function()
            local path = vim.fn.expand "%:p" -- absolute path
            local line = vim.fn.line "." -- 1-based
            local col = vim.fn.col "." -- 1-based
            return string.format("%s:%d:%d", path, line, col)
          end, {}),
        }),
      })
    end,
    keys = {
      -- {
      --   "<C-x>",
      --   function()
      --     -- require("luasnip").store_selection()
      --     require("luasnip").expand()
      --     -- require("luasnip").get_current_choices()
      --     -- require("luasnip").get_active_snip()
      --   end,
      --   mode = "x",
      --   desc = "expand",
      -- },
    },
  },
  -- Support copilot as source
  {
    -- define here since coding removed blink.cmp
    "saghen/blink.cmp",
    dependencies = { "fang2hou/blink-copilot" },
    opts = {
      sources = {
        -- default = { "copilot" }, -- dont show it but togglable with c-c (see myEditor blink.cmp <C-c> keymap)
        providers = {
          copilot = {
            name = "copilot",
            module = "blink-copilot",
            score_offset = 100,
            async = true,
          },
        },
      },
    },
  },
}
