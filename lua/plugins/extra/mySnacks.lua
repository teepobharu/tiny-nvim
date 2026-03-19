-- mySnacks.lua — Personal snacks.nvim overrides
-- Moved from myEditor.lua to decouple snacks config from general editor config.
local keyutil = require "utils.keyutil"
local editor_keymaps = require "utils.editor_keymaps"

local isSnackEnabled = keyutil.isSnackEnabled

local logo = [[
       \   /
        .-.
    -- (   ) --
        `-'
       /   \
]]

logo = string.rep("\n", 4) .. logo .. "\n\n"

return {
  {
    "folke/snacks.nvim",
    enabled = isSnackEnabled,
    opts = {
      dashboard = {
        enabled = false,
      },
      explorer = {
        replace_netrw = false,
      },
      -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md
      picker = {
        formatters = {
          file = {
            truncate = 200,
          },
        },
        ui_select = true, -- boolean set `vim.ui.select` to a snacks picker, might conflict with fzf
        -- Import pre-configured picker sources from editor_keymaps
        sources = vim.tbl_deep_extend("force", editor_keymaps.sources_n_keys.sources, {
          -- Source-specific overrides (if needed)
          files = {
            hidden = true, -- files picker specific setting
          },
          -- https://deepwiki.com/search/how-can-i-customize-explorer-k_06a6e33a-6125-418e-bd05-d979f1420178?mode=fast
          -- TODO: check does not realy work why ?
        }),
        toggles = {
          -- Existing toggles...
          git_cwd = {
            icon = "",
            value = true, -- Show when case_sensitive is true
          },
          external = {
            icon = "🗑️",
            value = true,
          },
          case_sensitive_custom = {
            icon = "C", -- Icon to show in title
            value = true, -- Show when case_sensitive is true
          },
          case_nonsensitive_custom = {
            icon = "~", -- Icon to show in title
            value = true, -- Show when case_sensitive is true
          },
          custom_cwd = {
            icon = ".", -- Icon to show in title
            value = true, -- Show when case_sensitive is true
          },
        },
        -- Merge path copy actions from editor_keymaps with local actions
        actions = vim.tbl_extend("force", editor_keymaps.snacks_common_actions, {}), -- Close vim.tbl_extend for actions
        -- Import common win settings from editor_keymaps
        win = editor_keymaps.sources_n_keys.common,
      },
      -- https://github.com/folke/snacks.nvim/blob/main/docs/gitbrowse.md
      gitbrowse = {
        url_patterns = {
          ["gitlab%..*"] = {
            branch = "/-/tree/{branch}",
            file = "/-/blob/{branch}/{file}#L{line_start}-L{line_end}",
            permalink = "/-/blob/{commit}/{file}#L{line_start}-L{line_end}",
            commit = "/-/commit/{commit}",
          },
        },
      },
    },
    keys = editor_keymaps.keymaps.snacks,
  },
}
