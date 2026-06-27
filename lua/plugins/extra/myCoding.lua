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
      local t = ls.text_node
      local i = ls.insert_node
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

        -- OKF (Open Knowledge Format) frontmatter snippet
        -- Type "okf" in insert mode on markdown files to expand
        -- Spec: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md
        s("okffmter", {
          t "---",
          t { '', 'type: "' }, i(1), -- type (required) — "Concept" default
          t '",',
          t { '', 'title: "' }, i(2), -- title (recommended)
          t '",',
          t { '', 'description: "' }, i(3), -- description (recommended)
          t '",',
          t { '', 'tags:' },
          t { '', '  - ' }, i(4), -- first tag
          t { '', 'timestamp: "' },
          f(function()
            -- UTC time (correct Zulu suffix)
            return os.date("!%Y-%m-%dT%H:%M:%SZ")
          end, {}),
          t '",',
          t { '', 'updated: "' },
          f(function()
            -- Local time (no timezone marker)
            return os.date("%Y-%m-%dT%H:%M:%S")
          end, {}),
          t '",',
          t { '', 'resource: "' }, i(5), -- canonical URI (optional)
          t '"',
          t { '', '---' },
          t { '', '' },
          i(0), -- final cursor position
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
