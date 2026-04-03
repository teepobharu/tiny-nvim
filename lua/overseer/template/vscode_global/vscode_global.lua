-- https://deepwiki.com/search/can-i-proviede-global-vscode-t_c7366185-16a4-4def-b614-f4c6732dff43?mode=fast
local vscode = require "overseer.vscode"
local vs_util = require "overseer.vscode.vs_util"

local function get_git_root(path)
  local git_entry = vim.fs.find(".git", { upward = true, path = path })[1]
  if git_entry then
    return vim.fs.dirname(git_entry)
  end
  return nil
end

---@type overseer.TemplateFileProvider
return {
  name = "global_vscode",
  tags = { "custom", "vscode~" },
  generator = function(opts)
    -- Load global tasks.json from user config directory
    -- local global_tasks_file = vim.fs.joinpath(vim.fn.stdpath "config", "tasks.json")
    local global_tasks_file = os.getenv "HOME" .. "/Library/Application Support/Code/User/tasks.json"
    -- "~/Library/Application Support/Code/User/tasks.json"

    if not vim.uv.fs_stat(global_tasks_file) then
      return "No global tasks.json found"
    end

    -- Reuse the existing VS Code loading utilities
    local content = vs_util.load_tasks_file(global_tasks_file)
    if not content or not content.tasks then
      return "Invalid global tasks.json format"
    end

    -- Convert tasks using existing VS Code converter
    local ret = {}
    local precalculated_vars = require("overseer.vscode.variables").precalculate_vars()

    -- Fix bug when in mmbweb proj it get $HOME as workspaceDir
    --  local cwd = vim.fn.getcwd()
    local cwd = vim.fn.getcwd()
    precalculated_vars.workspaceFolder = cwd
    precalculated_vars.workspaceFolderBasename = vim.fs.basename(cwd)
    -- Custom variable for global tasks: nearest git root from current file/cwd.
    local file_dir = vim.fn.expand("%:p:h")
    precalculated_vars.workspaceGitDir = get_git_root(file_dir) or get_git_root(cwd) or cwd
    _G.userdbg([==[generator precalculated_vars:]==], vim.inspect(precalculated_vars))

    for _, task in ipairs(content.tasks) do
      local tmpl = vscode.convert_vscode_task(task, precalculated_vars)
      if tmpl then
        -- Add a prefix to distinguish global tasks
        tmpl.name = "vscode~ " .. (tmpl.label or tmpl.name)
        table.insert(ret, tmpl)
      end
    end

    return ret
  end,
}
