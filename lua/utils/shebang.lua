local M = {}

--- Detect shebang from first line of a file.
--- @param file string absolute file path
--- @return table { has_shebang: boolean, interpreter: string|nil, args_table: table|nil, raw_line: string }
function M.detect(file)
  local lines = vim.fn.readfile(file, "", 1)
  if not lines or #lines == 0 then
    return { has_shebang = false, raw_line = "" }
  end

  local first_line = lines[1]
  if not first_line:match "^#!" then
    return { has_shebang = false, raw_line = first_line }
  end

  local shebang_cmd = first_line:match "^#!%s*(.+)$" or ""
  local args = {}
  for arg in shebang_cmd:gmatch "[^%s]+" do
    table.insert(args, arg)
  end

  return {
    has_shebang = true,
    interpreter = args[1],
    args_table = args,
    raw_line = first_line,
  }
end

--- Build command to execute file via its shebang.
--- Execute file directly so kernel resolves full shebang definition.
--- @param file string absolute file path
--- @return table|nil command args table
function M.build_exec_cmd(file)
  local shebang_info = M.detect(file)
  if not shebang_info.has_shebang then
    return nil
  end
  return { "sh", "-c", string.format("chmod +x %q && exec %q", file, file) }
end

return M
