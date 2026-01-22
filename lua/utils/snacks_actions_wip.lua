-- Snacks Picker Actions (Work In Progress)
-- Actions that are still being developed or need refinement
-- These will be moved to snacks_actions.lua once they are stable

local M = {}

local gitUtil = require "utils.git"

--#region Git Diff Actions

--- Compare current buffer with a selected git reference using gitsigns diff
--- Opens the current buffer in a new tab with a vertical diff against the selected ref
--- @param picker table Snacks picker instance
--- @param item table Item containing branch or commit reference
--- @param action any Unused action parameter
function M.my_diff_compare(picker, item, action)
  -- Get the selected reference from the picker
  local ref = item.branch or item.commit

  if not ref then
    local git_default = "master"
    ref = git_default
    vim.notify("No reference found, using default: " .. git_default, vim.log.levels.WARN)
  end

  picker:close() -- Close picker first

  -- Use the helper function to open current buffer with diff
  local editor_keymaps = require "utils.editor_keymaps"
  editor_keymaps.helpers.open_current_buffer_with_gitsigns_diff(ref)
end

--#endregion Git Diff Actions

return M
