-- Personal coding overrides kept out of core plugin specs
local ENABLE_COPILOT = require("utils.my_ai_default_config").ENABLE_COPILOT

local specs = {
  -- Pin blink.cmp to v1.10.2. v2 requires Neovim 0.12+ and saghen/blink.lib.
  -- Nvim 0.11.6 installed. Use commit pin since upstream spec sets branch="main" which
  -- takes precedence over version="1.*" in Lazy spec merging.
  {
    "saghen/blink.cmp",
    commit = "9b189bb2a0e03412e0e901dfbd09904f86cd593c", -- v1.10.2
  },
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
      {
        "<Esc>",
        function()
          local ls = require "luasnip"
          if ls.session.current_nodes[vim.api.nvim_get_current_buf()] then
            ls.unlink_current()
          end
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "in", false)
        end,
        mode = "i",
        desc = "Dismiss active snippet or exit insert",
      },
    },
  },
}

-- Support copilot as blink.cmp source only when Copilot is enabled
if ENABLE_COPILOT then
  table.insert(specs, {
    -- define here since coding removed blink.cmp
    "saghen/blink.cmp",
    dependencies = { "fang2hou/blink-copilot" },
    opts = {
      keymap = {
        -- <C-c> is the unified AI-completion trigger: copilot when enabled, minuet when disabled (see myMinuet.lua)
        ["<C-c>"] = {
          function(cmp)
            return cmp.show { providers = { "copilot" } }
          end,
          "fallback",
        },
      },
      sources = {
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
  })
end

return specs
