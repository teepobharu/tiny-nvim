local M = {}

local fn, api, opt = vim.fn, vim.api, vim.opt

function region_to_text(region)
  local text = ''
  local maxcol = vim.v.maxcol
  for line, cols in vim.spairs(region) do
    local endcol = cols[2] == maxcol and -1 or cols[2]
    local chunk = vim.api.nvim_buf_get_text(0, line, cols[1], line, endcol, {})[1]
    text = ('%s%s\n'):format(text, chunk)
  end
  return text
end

-- FIX: visual not selected correctly
function M.get_selected_or_cursor_word()
  -- Check the current mode
  local mode = vim.api.nvim_get_mode().mode
  vim.print(mode)
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[M.get_selected_or_cursor_word mode:]==], vim.inspect(mode)) -- __AUTO_GENERATED_PRINT_VAR_END__
  print([==[expand]==], vim.fn.expand("<cword>"))
  local selection = ""

  local mode = vim.fn.mode()
  local text = ""
  if mode == "v" or mode == "V" or mode == "\22" then
    local r = vim.region(0, "'<", "'>", vim.fn.visualmode(), true)
    vim.print("==region")
    vim.print(region_to_text(r))
    -- Visual mode: get selected text
    vim.cmd('normal! "vy')
    selection = vim.fn.getreg('v')
  else
    -- Normal mode: get current line
    selection = vim.fn.expand("<cword>")
  end

  local finalText = selection:gsub("^%s*(.-)%s*$", "%1")
  vim.print(finalText)
  print([==[finaltext]==], vim.inspect(finalText)) -- __AUTO_GENERATED_PRINT_VAR_END__
  return finalText
end


-- ================ TOGGLE TERM UTIL COPIED ===============
-- Copy from toggleterm send lines utils
-- TODO: check and validate -- sample usage
-- send_lines_to_terminal("single_line", true, args)
M.getSelectedLines = function(selection_type, trim_spaces)
  local lines = {}
  -- Beginning of the selection: line number, column number
  local start_line, start_col
  if selection_type == nil then 
    if vim.fn.mode() == "n" then
      selection_type = "single_line"
    else
      selection_type = "visual_selection"
    end
  end
  if selection_type == "single_line" then
    start_line, start_col = unpack(api.nvim_win_get_cursor(0))
    -- nvim_win_get_cursor uses 0-based indexing for columns, while we use 1-based indexing
    start_col = start_col + 1
    table.insert(lines, fn.getline(start_line))
  else
    local res = nil
    if string.match(selection_type, "visual") then
      -- This calls vim.fn.getpos, which uses 1-based indexing for columns
      res = M.get_line_selection("visual")
    else
      -- This calls vim.fn.getpos, which uses 1-based indexing for columns
      res = M.get_line_selection("motion")
    end
    start_line, start_col = unpack(res.start_pos)
    -- char, line and block are used for motion/operatorfunc. 'block' is ignored
    if selection_type == "visual_lines" or selection_type == "line" then
      lines = res.selected_lines
    elseif selection_type == "visual_selection" or selection_type == "char" then
      lines = M.get_visual_selection(res, true)
    end
  end

  if not lines or not next(lines) then return end

  return table.concat(lines, "\n")
  -- Skip Execute fn from term.exec
  -- if not trim_spaces then
  --   -- exec = run command
  --   M.exec(table.concat(lines, "\n"), id)
  -- else
  --   for _, line in ipairs(lines) do
  --     local l = trim_spaces and line:gsub("^%s+", ""):gsub("%s+$", "") or line
  --     M.exec(l, id)
  --   end
  -- end
end

---@param mode "visual" | "motion"
---@return table
function M.get_line_selection(mode)
  local start_char, end_char = unpack(({
    visual = { "'<", "'>" },
    motion = { "'[", "']" },
  })[mode])
  -- '< marks are only updated when one leaves visual mode.
  -- When calling lua functions directly from a mapping, need to
  -- explicitly exit visual with the escape key to ensure those marks are
  -- accurate.
  vim.cmd("normal! ")

  -- Get the start and the end of the selection
  local start_line, start_col = unpack(fn.getpos(start_char), 2, 3)
  local end_line, end_col = unpack(fn.getpos(end_char), 2, 3)
  local selected_lines = api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  return {
    start_pos = { start_line, start_col },
    end_pos = { end_line, end_col },
    selected_lines = selected_lines,
  }
end

function M.get_visual_selection(res, motion)

  motion = motion or false
  local mode = fn.visualmode()
  if motion then mode = "v" end

  -- line-visual
  -- return lines encompassed by the selection; already in res object
  if mode == "V" then return res.selected_lines end

  if mode == "v" then
    -- regular-visual
    -- return the buffer text encompassed by the selection
    local start_line, start_col = unpack(res.start_pos)
    local end_line, end_col = unpack(res.end_pos)
    -- exclude the last char in text if "selection" is set to "exclusive"
    if opt.selection:get() == "exclusive" then end_col = end_col - 1 end
    return api.nvim_buf_get_text(0, start_line - 1, start_col - 1, end_line - 1, end_col, {})
  end

  -- block-visual
  -- return the lines encompassed by the selection, each truncated by the start and end columns
  if mode == "\x16" then
    local _, start_col = unpack(res.start_pos)
    local _, end_col = unpack(res.end_pos)
    -- exclude the last col of the block if "selection" is set to "exclusive"
    if opt.selection:get() == "exclusive" then end_col = end_col - 1 end
    -- exchange start and end columns for proper substring indexing if needed
    -- e.g. instead of str:sub(10, 5), do str:sub(5, 10)
    if start_col > end_col then
      start_col, end_col = end_col, start_col
    end
    -- iterate over lines, truncating each one
    return vim.tbl_map(function(line) return line:sub(start_col, end_col) end, res.selected_lines)
  end
end

--- Sets a local window option, like `:setlocal`
--- TODO: replace with double-indexing on `vim.wo` when neovim/neovim#20288 (hopefully) merges
---@param win number
---@param option string
---@param value any
function M.wo_setlocal(win, option, value)

  api.nvim_set_option_value(option, value, { scope = "local", win = win })
end

-- ================ TOGGLE TERM UTIL COPIED END ===============

return M
