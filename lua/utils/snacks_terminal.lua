-- Snacks terminal utilities for sending lines/visual selections
-- Similar functionality to ToggleTerm's send_lines_to_terminal

local M = {}

-- Get the current Snacks terminal or create one
local function get_snacks_terminal()
  local terminals = require("snacks").terminal.list()

  -- Find an existing terminal or create a new one
  if #terminals > 0 then
    return terminals[vim.v.count > 0 and vim.v.count or 1] -- Use the specified terminal number or the first available
  else
    -- Create a new terminal
    return require("snacks").terminal()
  end
end

-- Send text to Snacks terminal
local function send_to_snacks_terminal(text)
  local terminal = get_snacks_terminal()
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[send_to_snacks_terminal terminal:]==], vim.inspect(terminal)) -- __AUTO_GENERATED_PRINT_VAR_END__

  if not terminal or not terminal.buf then
    vim.notify("No Snacks terminal available", vim.log.levels.ERROR)
    return
  end

  -- Get the terminal channel
  local chan = vim.bo[terminal.buf].channel
  if not chan or chan == 0 then
    vim.notify("Terminal channel not available", vim.log.levels.ERROR)
    return
  end

  -- Send the text to terminal
  vim.fn.chansend(chan, text .. "\n")

  -- Show the terminal if it's hidden
  if not terminal.closed then
    terminal:show()
  end

  -- Focus the terminal
  vim.api.nvim_set_current_win(terminal.win)
end

-- Send current line to Snacks terminal
function M.send_current_line()
  local line = vim.api.nvim_get_current_line()
  -- print("📤 Sending line to Snacks terminal: " .. line)
  send_to_snacks_terminal(line)
end

-- Send all buffer content to Snacks terminal
function M.send_all_lines()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, "\n")
  -- print("📤 Sending all lines to Snacks terminal (" .. #lines .. " lines)")
  send_to_snacks_terminal(text)
end

function M.send_previous_selection()
  -- previous selected with gv
  local current_win = vim.api.nvim_get_current_win()
  local curr_pos = vim.api.nvim_win_get_cursor(current_win)
  local curr_mode = vim.fn.mode()
  vim.cmd("normal! gv")
  local start_pos = vim.fn.getpos("v") -- Use 'v' for visual mode
  local end_pos = vim.fn.getpos(".")   -- Use '.' for current cursor position in visual mode
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  local text = table.concat(lines, "\n")
  if #lines == 0 then
    vim.notify("No lines selected", vim.log.levels.WARN)
    return
  end

  vim.cmd("normal! ")
  send_to_snacks_terminal(text)
  -- set win and same mode as before
  vim.api.nvim_set_current_win(current_win)
  vim.api.nvim_win_set_cursor(0, curr_pos)
  -- n mode
  vim.cmd("stopinsert")
end

M.send_to_snacks_terminal = send_to_snacks_terminal
return M
