-- https://github.com/stevearc/overseer.nvim/blob/master/lua/overseer/template/vscode/init.lua
-- COPY FROM ABOVE to reuse the template exports and only change the tasks file path to be from macOS vscode global tasks.json
-- local constants = require("overseer.constants")
local files = require("overseer.files")
-- local log = require("overseer.log")
-- local problem_matcher = require("overseer.template.vscode.problem_matcher")
local variables = require("overseer.template.vscode.variables")
local vs_util = require("overseer.template.vscode.vs_util")

local vstemplate = require("overseer.template.vscode")


local function get_tasks_file()
  -- Placeholder for obtaining macOS-specific vscode tasks file
  local user_tasks_path = os.getenv("HOME") .. "/Library/Application Support/Code/User/tasks.json"
  return user_tasks_path -- Retrieve macOS user tasks file
end

return {
  cache_key = function(opts)
    -- return vs_util.get_tasks_file(vim.fn.getcwd(), opts.dir)
    return get_tasks_file(vim.fn.getcwd(), opts.dir)
  end,
  condition = {
    callback = function(opts)
      -- if not vs_util.get_tasks_file(vim.fn.getcwd(), opts.dir) then
      if not get_tasks_file(vim.fn.getcwd(), opts.dir) then
        return false, "No .vscode/tasks.json file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    -- local tasks_file = vs_util.get_tasks_file(vim.fn.getcwd(), opts.dir)
    local tasks_file = get_tasks_file(vim.fn.getcwd(), opts.dir)
    local content = vs_util.load_tasks_file(assert(tasks_file))
    local global_defaults = {}
    for k, v in pairs(content) do
      if k ~= "version" and k ~= "tasks" then
        global_defaults[k] = v
      end
    end
    local os_key
    if files.is_windows then
      os_key = "windows"
    elseif files.is_mac then
      os_key = "osx"
    else
      os_key = "linux"
    end
    if content[os_key] then
      global_defaults = vim.tbl_deep_extend("force", global_defaults, content[os_key])
    end
    local ret = {}
    local precalculated_vars = variables.precalculate_vars()

    if content.tasks == nil then
      vim.notify("No 'tasks' key found in '.vscode/tasks.json'", vim.log.levels.WARN)
      cb({})
      return
    end

    for _, task in ipairs(content.tasks) do
      local defn = vim.tbl_deep_extend("force", global_defaults, task)
      defn = vim.tbl_deep_extend("force", defn, task[os_key] or {})
      local tmpl = vstemplate.convert_vscode_task(defn, precalculated_vars)
      if tmpl then
        table.insert(ret, tmpl)
      end
    end
    cb(ret)
  end,
  -- expose these for unit tests
  -- get_provider = get_provider,
  -- convert_vscode_task = convert_vscode_task,
  -- LAUNCH_CONFIG_KEY = LAUNCH_CONFIG_KEY,
}
