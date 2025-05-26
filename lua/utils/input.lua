local M = {}
-- FIX: visual not selected correctly
function M.get_selected_or_cursor_word()
  -- Check the current mode
  local mode = vim.api.nvim_get_mode().mode
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[M.get_selected_or_cursor_word mode:]==], vim.inspect(mode)) -- __AUTO_GENERATED_PRINT_VAR_END__

  local selection = ""
  if mode == "v" or mode == "V" or mode == "\22" then -- Visual modes
    -- Get the visual selection
    local s_start = vim.fn.getpos("'<")
    -- __AUTO_GENERATED_PRINT_VAR_START__
    print([==[M.get_selected_or_cursor_word#if s_start:]==], vim.inspect(s_start)) -- __AUTO_GENERATED_PRINT_VAR_END__
    local s_end = vim.fn.getpos("'>")
    -- __AUTO_GENERATED_PRINT_VAR_START__
    print([==[M.get_selected_or_cursor_word#if s_end:]==], vim.inspect(s_end)) -- __AUTO_GENERATED_PRINT_VAR_END__
    local lines = vim.fn.getline(s_start[1], s_end[1])
    -- __AUTO_GENERATED_PRINT_VAR_START__
    print([==[M.lines:]==], vim.inspect(lines)) -- __AUTO_GENERATED_PRINT_VAR_END__

    if #lines == 1 then
      selection = lines[1]:sub(s_start[3], s_end[3])
    else
      lines[1] = lines[1]:sub(s_start[3])
      lines[#lines] = lines[#lines]:sub(1, s_end[3])
      selection = table.concat(lines, " ")
    end

    return selection
  end
  return selection ~= "" and vim.fn.expand("<cword>") or selection
end

return M
