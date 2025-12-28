--- Create custom command
---@param cmd string The command name
---@param func function The function to execute
---@param opt table The options
local function create_cmd(cmd, func, opt)
  opt = vim.tbl_extend("force", { desc = "my-lazy-ide " .. cmd }, opt or {})
  vim.api.nvim_create_user_command(cmd, func, opt)
end

---@class CommandCallback
---@field success? fun(): nil Callback when command succeeds
---@field fail? fun(error: string[]): nil Callback when command fails
---@field out? fun(job_id: integer, data: string[], event: string): nil Callback for stdout
---@field stderr? fun(job_id: integer, data: string[], event: string): nil Callback for stderr

---Execute a shell command asynchronously with callbacks
---@param command string[] The command to execute, as a list of arguments (e.g., {"ls", "-la"})
---@param callback? CommandCallback A table containing optional callback functions
local function run_command(command, callback)
  callback = callback or {}
  callback.success = callback.success or function() end
  callback.fail = callback.fail or function() end
  -- callback.out = callback.out or false
  -- callback.stderr = callback.stderr or false

  local last_error = nil
  print("running command: ", vim.inspect(command))
  vim.fn.jobstart(command, {
    on_stdout = callback.out or function(_, data, _)
      print("[stdout]", vim.inspect(data))
    end or nil,
    on_stderr = callback.stderr or function(_, data, _)
      print("[stderr]", vim.inspect(data))
      local errfilter = vim.tbl_filter(function(value) return value ~= "" end, data)
      last_error = (#errfilter > 0) and errfilter or last_error
    end or nil,
    on_exit = function(_, _, _)
      print("on_exit last error:", vim.inspect(last_error))
      if last_error then
        callback.fail(last_error)
      else
        callback.success()
      end
    end,
    detach = true,
  })
end

local function quickCommandRunCurrentFile()
  vim.api.nvim_buf_set_mark(0, "<", 1, 0, {})
  local last_line = vim.fn.line("$")
  local last_line_text = vim.api.nvim_buf_get_lines(0, last_line - 1, last_line, false)[1] or ""
  local last_col = math.max(0, #last_line_text - 1)
  vim.api.nvim_buf_set_mark(0, ">", last_line, last_col, {})
  vim.cmd("'<,'>QuickCodeRunner")
end

return {
  create_cmd = create_cmd,
  run_command = run_command,
  quickCommandRunCurrentFile = quickCommandRunCurrentFile,
}
