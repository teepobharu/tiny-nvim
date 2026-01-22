-- Snacks terminal utilities for sending lines/visual selections
-- Similar functionality to ToggleTerm's send_lines_to_terminal
--
-- NOTE: Custom pickers have been moved to lua/utils/snacks_pickers.lua
-- NOTE: Picker actions have been moved to lua/utils/snacks_actions.lua

local inputUtil = require "utils.input"

local M = {}

--#region Terminal Information Helpers

-- Get detailed information about a terminal
local function get_terminal_info(terminal)
  local info = {
    terminal = terminal,
    buf = terminal.buf,
    win = terminal.win,
    id = terminal.id or 1, -- Default to 1 if no id
    closed = terminal.closed or false,
    win_valid = false,
    visible_in_current_tab = false,
    tab = nil,
    name = nil,
  }

  -- Check if window is valid
  if terminal.win and vim.api.nvim_win_is_valid(terminal.win) then
    info.win_valid = true

    -- Get the tab page for this window
    info.tab = vim.api.nvim_win_get_tabpage(terminal.win)

    -- Check if it's in the current tab
    local current_tab = vim.api.nvim_get_current_tabpage()
    info.visible_in_current_tab = (info.tab == current_tab)
  end

  if terminal.buf and vim.api.nvim_buf_is_valid(terminal.buf) then
    local ok, term_title = pcall(vim.api.nvim_buf_get_var, terminal.buf, "term_title")
    if ok and term_title then
      info.name = term_title
    else
      info.name = string.format("Terminal %d", info.id)
    end
  end

  return info
end

-- Find the best terminal to use based on visibility and count
local function find_best_terminal(terminals, count)
  if #terminals == 0 then
    return nil
  end

  if count and count > 0 then
    for _, term in ipairs(terminals) do
      if term.id and term.id == count then
        return term
      end

      if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
        local ok, buf_var = pcall(vim.api.nvim_buf_get_var, term.buf, "snacks_terminal")
        if ok and buf_var and buf_var.id == count then
          return term
        end
      end
    end

    local idx = math.min(count, #terminals)
    return terminals[idx]
  end

  local current_tab = vim.api.nvim_get_current_tabpage()
  local terminal_infos = {}

  for i, term in ipairs(terminals) do
    local info = get_terminal_info(term)
    info.index = i
    table.insert(terminal_infos, info)
  end

  for _, info in ipairs(terminal_infos) do
    if info.visible_in_current_tab and info.win_valid and not info.closed then
      return info.terminal
    end
  end

  for _, info in ipairs(terminal_infos) do
    if info.tab == current_tab and not info.closed then
      return info.terminal
    end
  end

  for _, info in ipairs(terminal_infos) do
    if not info.closed then
      return info.terminal
    end
  end

  return terminals[1]
end

--#endregion Terminal Information Helpers

--#region Terminal Management

-- Get the current Snacks terminal or create one
local function get_snacks_terminal(count)
  local terminals = require("snacks").terminal.list()

  if #terminals > 0 then
    return find_best_terminal(terminals, count)
  else
    return require("snacks").terminal()
  end
end

-- Send text to Snacks terminal
local function send_to_snacks_terminal(text, count)
  local terminal = get_snacks_terminal(count)

  if not terminal or not terminal.buf then
    vim.notify("No Snacks terminal available", vim.log.levels.ERROR)
    return
  end

  local chan = vim.bo[terminal.buf].channel
  if not chan or chan == 0 then
    vim.notify("Terminal channel not available", vim.log.levels.ERROR)
    return
  end

  vim.fn.chansend(chan, text .. "\n")

  if terminal.closed or not terminal.win or not vim.api.nvim_win_is_valid(terminal.win) then
    terminal:show()
  end
end

--#endregion Terminal Management

--#region Public API

--- Get the Snacks terminal (exposed for external use)
--- @param count number|nil Terminal count/id
--- @return table Terminal instance
function M.get_snacks_terminal(count)
  return get_snacks_terminal(count)
end

--- Send text to Snacks terminal
--- @param text string Text to send
--- @param count number|nil Terminal count/id
function M.send_to_snacks_terminal(text, count)
  local terminal_count = count or (vim.v.count > 0 and vim.v.count or nil)
  send_to_snacks_terminal(text, terminal_count)
end

--- Send current line to Snacks terminal
--- @param count number|nil Terminal count/id
function M.send_current_line(count)
  local line = vim.api.nvim_get_current_line()
  send_to_snacks_terminal(line, count)
end

--- Send all buffer content to Snacks terminal
--- @param count number|nil Terminal count/id
function M.send_all_lines(count)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, "\n")
  send_to_snacks_terminal(text, count)
end

--- Send previous selection to Snacks terminal
--- @param count number|nil Terminal count/id
function M.send_previous_selection(count)
  local current_win = vim.api.nvim_get_current_win()
  local curr_pos = vim.api.nvim_win_get_cursor(current_win)
  local text = inputUtil.getPreviousSelectedText()

  send_to_snacks_terminal(text, count)

  vim.api.nvim_set_current_win(current_win)
  pcall(vim.api.nvim_win_set_cursor, 0, curr_pos)
end

--#endregion Public API

--#region Delegate Functions (backward compatibility)
-- These delegate to the new modules for backward compatibility

--- Tmux window picker (delegates to snacks_pickers)
function M.pick_tmux_window()
  require("utils.snacks_pickers").pick_tmux_window()
end

--- Git last commit files picker (delegates to snacks_pickers)
M.custom_git_pickers = {
  git_last_commit_show = function()
    require("utils.snacks_pickers").custom_git_pickers.git_last_commit_show()
  end,
  git_diff_upstream = function()
    require("utils.snacks_pickers").custom_git_pickers.git_diff_upstream()
  end,
}

--- Custom change list picker (delegates to snacks_pickers)
function M.custom_change_list_picker()
  require("utils.snacks_pickers").custom_change_list_picker()
end

--- Terminal picker (delegates to snacks_pickers)
function M.custom_terminal_show()
  require("utils.snacks_pickers").custom_terminal_show()
end

--- Get initial picker state (delegates to snacks_pickers)
function M.get_initial_picker_state(pickerOpts, opts)
  return require("utils.snacks_pickers").get_initial_picker_state(pickerOpts, opts)
end

--- Toggle CWD for files/grep pickers (delegates to snacks_actions)
function M.toggle_cwd_files_grep(picker, item)
  require("utils.snacks_actions").toggle_cwd_files_grep(picker, item)
end

--- Adjust picker depth (delegates to snacks_actions)
function M.adjust_picker_depth(picker, item, direction, max_depth_limit)
  require("utils.snacks_actions").adjust_picker_depth(picker, item, direction, max_depth_limit)
end

--- Path copy actions (delegates to snacks_actions)
function M.copy_path_relative_buffer(picker, item)
  require("utils.snacks_actions").copy_path_relative_buffer(picker, item)
end

function M.copy_path_relative_git(picker, item)
  require("utils.snacks_actions").copy_path_relative_git(picker, item)
end

function M.copy_path_relative_cwd(picker, item)
  require("utils.snacks_actions").copy_path_relative_cwd(picker, item)
end

function M.copy_path_absolute(picker, item)
  require("utils.snacks_actions").copy_path_absolute(picker, item)
end

function M.copy_path_select(picker, item)
  require("utils.snacks_actions").copy_path_select(picker, item)
end

--#endregion Delegate Functions

return M
