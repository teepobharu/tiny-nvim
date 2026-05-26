-- MCP Inspector lifecycle manager for :MCPHub endpoints panel.
-- Owns the npx job; exposes start/stop/open/config_path.
local M = {}

M.UI_PORT = 6274
M.PROXY_PORT = 6277
M._job_id = nil
M._auth_token = nil
M._running_auth_token = nil

function M.config_path()
  return vim.fn.expand("~/.config/mcp-inspector/config.json")
end

function M.token_path()
  return vim.fn.expand("~/.config/mcp-inspector/proxy-token")
end

local function trim(value)
  return vim.trim(value or "")
end

local function query_encode(value)
  return tostring(value):gsub("[^%w%-%._~]", function(char)
    return string.format("%%%02X", string.byte(char))
  end)
end

local function generate_token()
  local token = trim(vim.fn.system({ "openssl", "rand", "-hex", "32" }))
  if vim.v.shell_error == 0 and token ~= "" then
    return token
  end

  token = trim(vim.fn.system({ "xxd", "-p", "-l", "32", "/dev/urandom" }))
  if vim.v.shell_error == 0 and token ~= "" then
    return token:gsub("%s+", "")
  end

  return vim.fn.sha256(table.concat({
    tostring(vim.loop.hrtime()),
    tostring(vim.fn.getpid()),
    tostring(vim.fn.localtime()),
    tostring(vim.fn.rand()),
  }, ":"))
end

function M.proxy_auth_token()
  local env_token = trim(vim.env.MCP_PROXY_AUTH_TOKEN)
  if env_token ~= "" then
    M._auth_token = env_token
    return M._auth_token
  end

  if M._auth_token and M._auth_token ~= "" then
    return M._auth_token
  end

  local path = M.token_path()
  if vim.fn.filereadable(path) == 1 then
    local lines = vim.fn.readfile(path, "", 1)
    local file_token = trim(lines[1])
    if file_token ~= "" then
      M._auth_token = file_token
      return M._auth_token
    end
  end

  M._auth_token = generate_token()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile({ M._auth_token }, path)
  pcall(vim.fn.setfperm, path, "rw-------")
  return M._auth_token
end

function M.is_running()
  if not M._job_id then
    return false
  end
  -- jobwait returns -1 when the job is still running
  if vim.fn.jobwait({ M._job_id }, 0)[1] == -1 then
    return true
  end
  M._job_id = nil
  M._running_auth_token = nil
  return false
end

-- Start the inspector. Calls on_ready() once the UI port is detected in stdout,
-- with a 4s fallback in case the ready-line is missed.
function M.start(on_ready)
  if M.is_running() then
    if on_ready then
      on_ready()
    end
    return
  end

  local auth_token = M.proxy_auth_token()
  local env = vim.fn.environ()
  env.MCP_PROXY_AUTH_TOKEN = auth_token
  env.MCP_AUTO_OPEN_ENABLED = "false"
  env.CLIENT_PORT = tostring(M.UI_PORT)
  env.SERVER_PORT = tostring(M.PROXY_PORT)

  M._job_id = vim.fn.jobstart({ "npx", "@modelcontextprotocol/inspector", "-y" }, {
    env = env,
    on_stdout = function(_, data)
      for _, l in ipairs(data or {}) do
        if l:find(tostring(M.UI_PORT), 1, true) and on_ready then
          vim.schedule(on_ready)
          on_ready = nil
        end
      end
    end,
    on_stderr = function(_, data)
      -- stderr also carries startup lines; check here too
      for _, l in ipairs(data or {}) do
        if l:find(tostring(M.UI_PORT), 1, true) and on_ready then
          vim.schedule(on_ready)
          on_ready = nil
        end
      end
    end,
    on_exit = function()
      M._job_id = nil
      M._running_auth_token = nil
    end,
  })
  if M._job_id <= 0 then
    M._job_id = nil
    M._running_auth_token = nil
    vim.notify("Failed to start MCP Inspector", vim.log.levels.ERROR)
    return
  end
  M._running_auth_token = auth_token

  -- 4s fallback
  vim.defer_fn(function()
    if on_ready then
      on_ready()
      on_ready = nil
    end
  end, 4000)
end

function M.stop()
  if not M.is_running() then
    vim.notify("MCP Inspector not running", vim.log.levels.INFO)
    return
  end
  vim.fn.jobstop(M._job_id)
  M._job_id = nil
  M._running_auth_token = nil
  vim.notify("MCP Inspector stopped", vim.log.levels.INFO)
end

-- Build the browser URL for a given transport + server URL.
function M.url(transport, server_url)
  local auth_token = M.is_running() and M._running_auth_token or M.proxy_auth_token()
  local params = {
    "transport=" .. query_encode(transport),
    "serverUrl=" .. query_encode(server_url),
    "MCP_PROXY_AUTH_TOKEN=" .. query_encode(auth_token),
  }
  if M.PROXY_PORT ~= 6277 then
    table.insert(params, "MCP_PROXY_PORT=" .. query_encode(M.PROXY_PORT))
  end
  return string.format("http://localhost:%d/?%s", M.UI_PORT, table.concat(params, "&"))
end

-- Start the inspector (or reuse running) then open the browser.
function M.open(transport, server_url)
  local target_url = M.url(transport, server_url)
  M.start(function()
    vim.ui.open(target_url)
  end)
end

return M
