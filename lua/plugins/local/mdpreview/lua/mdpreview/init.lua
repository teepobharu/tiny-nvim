local M = {}

local server = require "mdpreview.server"
local augroup = vim.api.nvim_create_augroup("MdPreview", { clear = true })

local DEFAULT_MAX_FILES = 50

--- Collect .md sibling files in same directory as `file`
local function siblings(file)
  local dir = vim.fn.fnamemodify(file, ":h")
  local result = vim.fn.glob(dir .. "/*.md", false, true)
  vim.list_extend(result, vim.fn.glob(dir .. "/*.markdown", false, true))
  return result
end

--- Collect .md files under cwd (capped)
local function cwd_mds(max)
  local files = vim.fn.glob(vim.fn.getcwd() .. "/**/*.md", false, true)
  if #files > max then
    files = vim.list_slice(files, 1, max)
  end
  return files
end

--- Determine allowed path roots from a file list
local function roots_from_files(files)
  local roots = {}
  local seen = {}
  for _, f in ipairs(files) do
    local dir = vim.fn.fnamemodify(f, ":h")
    if not seen[dir] then
      seen[dir] = true
      table.insert(roots, dir)
    end
  end
  return roots
end

--- Open browser at URL
local function open_browser(url)
  local cmd
  if vim.fn.has "mac" == 1 then
    cmd = "open"
  elseif vim.fn.has "unix" == 1 then
    cmd = "xdg-open"
  else
    cmd = "start"
  end
  vim.fn.jobstart({ cmd, url }, { detach = true })
end

--- Main entry point
--- @param args string[]  optional explicit file paths
function M.open(args)
  local files = {}

  if args and #args > 0 then
    for _, a in ipairs(args) do
      local abs = vim.fn.fnamemodify(vim.fn.expand(a), ":p")
      table.insert(files, abs)
    end
  else
    local buf_file = vim.fn.expand "%:p"
    local ft = vim.bo.filetype
    if ft == "markdown" and buf_file ~= "" then
      files = siblings(buf_file)
      if #files == 0 then
        files = { buf_file }
      end
    else
      files = cwd_mds(DEFAULT_MAX_FILES)
    end
  end

  if #files == 0 then
    vim.notify("[mdpreview] No markdown files found", vim.log.levels.WARN)
    return
  end

  -- Determine initial file: prefer current buffer if in list
  local buf_abs = vim.fn.expand "%:p"
  local initial = files[1]
  for _, f in ipairs(files) do
    if f == buf_abs then
      initial = f
      break
    end
  end

  local roots = roots_from_files(files)
  -- add cwd as allowed root
  table.insert(roots, vim.fn.getcwd())
  -- add git root so `assets/foo.png` from repo root resolves correctly
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if git_root and git_root ~= "" and not git_root:find "^fatal" then
    table.insert(roots, git_root)
  end

  if server.is_running() then
    server.stop()
  end

  local port = server.start(files, initial, roots)
  local url = string.format("http://127.0.0.1:%d/", port)
  vim.notify(string.format("[mdpreview] Serving %d file(s) at %s", #files, url), vim.log.levels.INFO)
  open_browser(url)

  -- BufWritePost autocmd for live reload
  vim.api.nvim_clear_autocmds { group = augroup }
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    pattern = "*.md,*.markdown",
    callback = function()
      server.broadcast_reload()
    end,
  })
end

function M.stop()
  server.stop()
  vim.api.nvim_clear_autocmds { group = augroup }
  vim.notify("[mdpreview] Stopped", vim.log.levels.INFO)
end

function M.setup()
  -- nothing to configure yet
end

return M
