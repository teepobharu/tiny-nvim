local M = {}

local uv = vim.uv or vim.loop

---@param start? string
---@return string
function M.git_root(start)
  start = start or uv.cwd()
  return vim.fs.root(start, ".git") or start
end

return M
