-- Snacks terminal utilities for sending lines/visual selections
-- Similar functionality to ToggleTerm's send_lines_to_terminal

-- done : send with vcount 20251209:17:34:53

local M = {}

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

  -- Get terminal name from buffer or winbar
  if terminal.buf and vim.api.nvim_buf_is_valid(terminal.buf) then
    -- Try to get term_title from buffer variable
    local ok, term_title = pcall(vim.api.nvim_buf_get_var, terminal.buf, 'term_title')
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

  -- print([==[find_best_terminal#if count:]==], vim.inspect(count)) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- If count is specified, use that terminal (user explicitly chose it)
  if count and count > 0 then
    -- __AUTO_GENERATED_PRINT_VAR_START__
    -- First try to match the explicit count to a terminal's assigned id
    for _, term in ipairs(terminals) do
      -- Match by terminal.id if present
      if term.id and term.id == count then
        -- print([==[find_best_terminal#if#for#if term.id and term.id == count:]==], vim.inspect(term.id and term.id == count)) -- __AUTO_GENERATED_PRINT_VAR_END__
        return term
      end

      -- Match by buffer variable snacks_terminal.id if present
      if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
        local ok, buf_var = pcall(vim.api.nvim_buf_get_var, term.buf, 'snacks_terminal')
        if ok and buf_var and buf_var.id == count then
          -- print([==[find_best_terminal#if#for# == count buf_var:]==], vim.inspect(buf_var)) -- __AUTO_GENERATED_PRINT_VAR_END__
          return term
        end
      end
    end

    -- Fallback to positional indexing if no id match found
    local idx = math.min(count, #terminals)
    print([==[find_best_terminal#if count (#terminals):]==], vim.inspect(idx)) -- __AUTO_GENERATED_PRINT_VAR_END__
    return terminals[idx]
  end

  -- No count specified - find visible terminal in current tab first
  local current_tab = vim.api.nvim_get_current_tabpage()
  local terminal_infos = {}

  -- Gather info about all terminals
  for i, term in ipairs(terminals) do
    local info = get_terminal_info(term)
    info.index = i
    table.insert(terminal_infos, info)
  end

  -- Print terminal info for debugging
  print([==[Available terminals:]==])
  for _, info in ipairs(terminal_infos) do
    print(string.format("  [%d] buf=%d win=%s tab=%s visible=%s name=%s",
      info.index,
      info.buf,
      info.win or "none",
      info.tab or "none",
      info.visible_in_current_tab and "YES" or "no",
      info.name or "unknown"
    ))
  end

  -- Priority 1: Visible terminal in current tab
  for _, info in ipairs(terminal_infos) do
    if info.visible_in_current_tab and info.win_valid and not info.closed then
      print(string.format("→ Selected terminal [%d] (visible in current tab)", info.index))
      return info.terminal
    end
  end

  -- Priority 2: Any valid terminal in current tab (even if hidden)
  for _, info in ipairs(terminal_infos) do
    if info.tab == current_tab and not info.closed then
      print(string.format("→ Selected terminal [%d] (in current tab)", info.index))
      return info.terminal
    end
  end

  -- Priority 3: First non-closed terminal
  for _, info in ipairs(terminal_infos) do
    if not info.closed then
      print(string.format("→ Selected terminal [%d] (first available)", info.index))
      return info.terminal
    end
  end

  -- Fallback: First terminal
  print(string.format("→ Selected terminal [1] (fallback)"))
  return terminals[1]
end

-- Get the current Snacks terminal or create one
local function get_snacks_terminal(count)
  local terminals = require("snacks").terminal.list()

  -- Find an existing terminal or create a new one
  if #terminals > 0 then
    return find_best_terminal(terminals, count)
  else
    -- Create a new terminal only if none exist
    print("→ Creating new terminal (none exist)")
    return require("snacks").terminal()
  end
end

-- Send text to Snacks terminal
local function send_to_snacks_terminal(text, count)
  local terminal = get_snacks_terminal(count)
  -- print([==[send_to_snacks_terminal terminal:]==], vim.inspect(terminal)) -- __AUTO_GENERATED_PRINT_VAR_END__

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
  if terminal.closed or not terminal.win or not vim.api.nvim_win_is_valid(terminal.win) then
    terminal:show()
  end

  -- Focus the terminal if it has a valid window
  -- if terminal.win and vim.api.nvim_win_is_valid(terminal.win) then
  --   vim.api.nvim_set_current_win(terminal.win)
  -- end
end

-- Send current line to Snacks terminal
function M.send_current_line(count)
  local line = vim.api.nvim_get_current_line()
  -- print("📤 Sending line to Snacks terminal: " .. line)
  send_to_snacks_terminal(line, count)
end

-- Send all buffer content to Snacks terminal
function M.send_all_lines(count)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, "\n")
  -- print("📤 Sending all lines to Snacks terminal (" .. #lines .. " lines)")
  send_to_snacks_terminal(text, count)
end

function M.send_previous_selection(count)
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
  send_to_snacks_terminal(text, count)
  -- set win and same mode as before
  vim.api.nvim_set_current_win(current_win)
  vim.api.nvim_win_set_cursor(0, curr_pos)
  -- n mode
  vim.cmd("stopinsert")
end

-- Export the send function with count support
function M.send_to_snacks_terminal(text, count)
  -- Capture count at the time of function call
  local terminal_count = count or (vim.v.count > 0 and vim.v.count or nil)
  send_to_snacks_terminal(text, terminal_count)
end

--#region Pickers Docs
-- Pickers sample
-- with format : https://github.com/folke/snacks.nvim/discussions/498
--#endregion

--#region Pickers tmux

function _get_tmux_windows()
    local windows_raw = vim.fn.system("tmux list-windows -F '#{window_index}: #{window_name}'")
    local windows = {}

    for window in windows_raw:gmatch("[^\r\n]+") do
      table.insert(windows, { text = window })
    end

    return windows
end

function M.pick_tmux_window()
  local windows = _get_tmux_windows()

  Snacks.picker.pick({
    source = "tmux_windows",
    items = windows,
    format = "text",
    layout = {
      preset = "vscode",
    },
    confirm = function(picker, item)
      picker:close()
      local window_index = item.text:match("^(%d+):")
      if window_index then
        vim.fn.system(string.format("tmux select-window -t %s", window_index))
      end
    end,
  })
end

--#endregion
--
--
--#region Pickers Git file pick
-- -- ref: https://www.reddit.com/r/neovim/comments/1j4e7fq/comment/mgd5wto/
--     { "<leader>fs", custom_pickers.git_show, desc = "Find in Git Show" },
--     { "<leader>fb", custom_pickers.git_diff_upstream, desc = "Find in Git Branch" },
--     { "<leader>fd", function() Snacks.picker.git_status() end, desc = "Find in Git Diff" },

local function pick_cmd_result(picker_opts)
  local git_root = Snacks.git.get_root()
  local function finder(opts, ctx)
    -- Merge picker_opts into opts for proc
    local proc_opts = vim.tbl_extend("force", opts, {
      cmd = picker_opts.cmd,
      args = picker_opts.args,
      transform = function(item)
        item.cwd = picker_opts.cwd or git_root
        item.file = item.text
      end,
    })
    return require("snacks.picker.source.proc").proc(proc_opts, ctx)
  end

  Snacks.picker.pick {
    source = picker_opts.name,
    finder = finder,
    format = "file",
    preview = picker_opts.preview,
    title = picker_opts.title,
  }
end

-- Custom Pickers
M.custom_git_pickers = {}

function M.custom_git_pickers.git_show()
  pick_cmd_result {
    cmd = "git",
    args = { "diff-tree", "--no-commit-id", "--name-only", "--diff-filter=d", "HEAD", "-r" },
    name = "git_show",
    title = "Git Last Commit",
    preview = "git_show",
  }
end

function M.custom_git_pickers.git_diff_upstream()
  pick_cmd_result {
    cmd = "git",
    args = { "diff-tree", "--no-commit-id", "--name-only", "--diff-filter=d", "HEAD@{u}..HEAD", "-r" },
    name = "git_diff_upstream",
    title = "Git Branch Changed Files",
    preview = "file",
  }
end

--
--#endregion
return M
