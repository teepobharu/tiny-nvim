local M = {}

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

return M
