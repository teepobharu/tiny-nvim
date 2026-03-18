-- UI overrides for upstream core plugins (lua/plugins/ui.lua)
-- Follows the myEditor.lua pattern: override/disable without editing upstream files.
--
-- Core ui.lua plugins that may need overriding:
--   echasnovski/mini.icons       (line 81)  - icon provider, mocks nvim-web-devicons
--   echasnovski/mini.statusline  (line 99)  - custom statusline
--   echasnovski/mini.tabline     (line 129) - buffer tabline (replaced bufferline.nvim)
--   echasnovski/mini.bufremove   (line 143) - buffer deletion helper
--   echasnovski/mini.files       (line 147) - file explorer (replaced snacks.explorer)
--   echasnovski/mini.diff        (line 432) - git hunk navigation (replaced gitsigns.nvim)
--   folke/which-key.nvim         (line 384) - keymap hint popup
--   MagicDuck/grug-far.nvim      (line 476) - search and replace
--
-- To disable a plugin, prefer using vim.g.disabled_plugins in mydefault-nvim-config.lua
-- (handled by disablePlugins.lua) instead of { name, enabled = false } here.
-- Use this file for config overrides (opts, keys, etc.) that need deep-merge.

-- Disable mini-* core plugins listed above to prefer snacks equivalents.
-- These entries set enabled = false so lazy.nvim will skip loading them.

return {
  { "echasnovski/mini.icons", enabled = false },
  { "echasnovski/mini.statusline", enabled = false },
  { "echasnovski/mini.tabline", enabled = false },
  { "echasnovski/mini.bufremove", enabled = false },
  { "echasnovski/mini.files", enabled = false },
  { "echasnovski/mini.diff", enabled = false },
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {},
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
  },
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = (function()
      local base = vim.deepcopy(require("utils.editor_keymaps").keymaps.bufferline or {})
      local extra = {
        { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle Pin" },
        { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Non-Pinned Buffers" },
        { "<leader>bo", "<Cmd>BufferLineCloseOthers<CR>", desc = "Delete Other Buffers" },
        { "<leader>br", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
        { "<leader>bl", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
        { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
        { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
        { "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
        { "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
        { "[B", "<cmd>BufferLineMovePrev<cr>", desc = "Move buffer prev" },
        { "]B", "<cmd>BufferLineMoveNext<cr>", desc = "Move buffer next" },
      }
      for _, m in ipairs(extra) do
        table.insert(base, m)
      end
      return base
    end)(),

    opts = {
      options = {
        always_show_bufferline = false,
        -- check on health groups
        -- items = {
        --   require('bufferline.groups').builtin.ungrouped,
      },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

        map("n", "]h", function()
          if vim.wo.diff then
            vim.cmd.normal { "]c", bang = true }
          else
            gs.nav_hunk "next"
          end
        end, "Next Hunk")
        map("n", "[h", function()
          if vim.wo.diff then
            vim.cmd.normal { "[c", bang = true }
          else
            gs.nav_hunk "prev"
          end
        end, "Prev Hunk")
        map("n", "]H", function()
          gs.nav_hunk "last"
        end, "Last Hunk")
        map("n", "[H", function()
          gs.nav_hunk "first"
        end, "First Hunk")
        map({ "n", "v" }, "<leader>ghs", ":Gitsigns stage_hunk<CR>", "Stage Hunk")
        map({ "n", "v" }, "<leader>ghr", ":Gitsigns reset_hunk<CR>", "Reset Hunk")
        map("n", "<leader>ghS", gs.stage_buffer, "Stage Buffer")
        map("n", "<leader>ghu", gs.undo_stage_hunk, "Undo Stage Hunk")
        map("n", "<leader>ghU", gs.reset_buffer_index, "Unstage Buffer")
        map("n", "<leader>ghR", gs.reset_buffer, "Reset Buffer")
        map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview Hunk Inline")
        map("n", "<leader>ghb", function()
          gs.blame_line { full = true }
        end, "Blame Line")
        map("n", "<leader>ghB", function()
          gs.blame()
        end, "Blame Buffer")
        map("n", "<leader>ghd", gs.diffthis, "Diff This")
        map("n", "<leader>ghD", function()
          gs.diffthis "~"
        end, "Diff This ~")
        map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")

        -- Toggle blame line
        map("n", "<leader>tb", function()
          gs.toggle_current_line_blame()
        end, "Toggle Blame Line")
      end,
    },
  },

  -- Override which-key preset back to "helix" if preferred
  {
    "folke/which-key.nvim",
    enabled = true,
    opts = {
      preset = "helix",
    },
  },

  -- Re-add gitsigns-equivalent keymaps lost in mini.diff migration
  -- mini.diff doesn't have direct equivalents for:
  --   ghS (stage buffer), ghu (undo stage), ghU (unstage buffer/reset_buffer_index)
  --   ghp (preview hunk inline), ghb/ghB (blame), ghd/ghD (diffthis)
  -- These would need a separate git plugin or shell commands.
  -- {
  --   "echasnovski/mini.diff",
  --   keys = {
  --     -- Example: add custom keymap
  --   },
  -- },
}
