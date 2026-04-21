local M = {}

--- Check if current directory is a git repo
---@return boolean
function M.is_git_repo()
  vim.fn.system "git rev-parse --is-inside-work-tree"
  return vim.v.shell_error == 0
end

--- Get root directory of git project
---@return string|nil
function M.get_git_root()
  return vim.fn.systemlist("git rev-parse --show-toplevel")[1]
end

--- Get root directory of git project or fallback to current directory
---@return string|nil
function M.get_root_directory()
  if M.is_git_repo() then
    return M.get_git_root()
  end

  return vim.fn.getcwd()
end

--- Get relative path from source file/dir to target file/dir, using ../ when needed
---@param target_path string absolute or relative target path
---@param source_path string absolute or relative source path (reference point)
---@return string|nil relative path or nil if target_path is empty
function M.get_relative_path_with_parent(target_path, source_path)
  if not target_path or target_path == "" then
    return nil
  end

  target_path = vim.fn.fnamemodify(target_path, ":p")
  source_path = vim.fn.fnamemodify(source_path, ":p")

  local target_parts = vim.split(target_path, "/", { plain = true })
  local source_parts = vim.split(source_path, "/", { plain = true })

  local common_len = 0
  for i = 1, math.min(#target_parts, #source_parts) do
    if target_parts[i] == source_parts[i] then
      common_len = i
    else
      break
    end
  end

  local ups = #source_parts - common_len - 1
  local rel_parts = {}

  for _ = 1, ups do
    table.insert(rel_parts, "..")
  end

  for i = common_len + 1, #target_parts do
    table.insert(rel_parts, target_parts[i])
  end

  return table.concat(rel_parts, "/")
end

return M
