-- mcphub_agents.lua — CLI agent MCP-binding helper for mcphub.nvim patch 05
--
-- Wraps `<agent> mcp add|remove|list` (claude / codex / opencode) as async
-- vim.system calls. Returns simple {ok, stdout, stderr} tables; consumers
-- (the patch's render_agent_registry) re-render the row on completion.
--
-- Why a thin module instead of inline in the patch:
--   - keeps the patch diff small and reviewable
--   - reusable from user commands (:MCPHubAgentList) without touching plugin code
--   - lets tests (or :luafile) exercise the parser without :MCPHub running
--
-- Per-preset CLI shapes (confirmed via --help):
--   claude:   mcp add [--scope user|project] --transport sse <name> <url>
--             mcp remove [--scope user|project] <name>
--             mcp list  → "name: url (TRANSPORT) - status"
--   codex:    mcp add <name> --url <url>     (no --transport, no --scope)
--             mcp remove <name>
--             mcp list  → table with headers: Name Command Args Env Cwd Status Auth
--   opencode: no CLI add/remove → users must edit ~/.config/opencode/opencode.jsonc
--             mcp list  → boxed output: "●  ✓/○ <name>" + indented url line

local M = {}

local PRESETS = {
  claude = {
    command = "claude",
    config_path = function(profile, scope)
      if profile.config_path then
        return profile.config_path
      end
      if scope == "project" then
        return vim.fn.getcwd() .. "/.mcp.json"
      end
      if profile.config_dir then
        return profile.config_dir .. "/settings.json"
      end
      return "~/.claude.json"
    end,
  },
  codex = {
    command = "codex",
    config_path = function(profile, _)
      return profile.config_path or "~/.codex/config.toml"
    end,
  },
  opencode = {
    command = "opencode",
    config_path = function(profile, _)
      return profile.config_path or "~/.config/opencode/opencode.jsonc"
    end,
  },
}

---@class McphubAgents.Binding
---@field name string             registration name (e.g. "mcphub-lean")
---@field url string              full URL (e.g. "http://localhost:37373/mcp-lean")
---@field transport string        "SSE" | "HTTP" | "STDIO" | "?"
---@field status string           "connected" | "failed" | "auth" | "unknown"
---@field raw string              original line for debug / fallback render

---@class McphubAgents.Profile
---@field id string
---@field name string
---@field label string
---@field preset string
---@field command string
---@field config_dir string|nil
---@field config_path string|nil
---@field env table<string,string>|nil

---@param value string|table
---@return McphubAgents.Profile
function M.normalize_profile(value)
  if type(value) == "string" then
    value = { name = value }
  end
  value = type(value) == "table" and value or {}

  local preset = value.preset or value.name or value.id or "claude"
  local preset_cfg = PRESETS[preset] or {}
  local id = value.id or value.name or preset
  local command = value.command or preset_cfg.command or preset

  return {
    id = id,
    name = id,
    label = value.label or id,
    preset = preset,
    command = command,
    config_dir = value.config_dir and vim.fn.expand(value.config_dir) or nil,
    config_path = value.config_path and vim.fn.expand(value.config_path) or nil,
    env = value.env,
  }
end

---@param profile McphubAgents.Profile
---@return table<string,string>|nil
function M.env(profile)
  local env = vim.deepcopy(profile.env or {})
  if profile.preset == "claude" and profile.config_dir and profile.config_dir ~= "" then
    env.CLAUDE_CONFIG_DIR = profile.config_dir
  end
  return next(env) and env or nil
end

---Detect whether a CLI agent binary is available on PATH.
---@param agent string|table
---@return boolean
function M.is_available(agent)
  local profile = M.normalize_profile(agent)
  return vim.fn.executable(profile.command) == 1
end

---Return the config file path for a given agent + scope.
---Used by the `e` keymap to open config for editing.
---@param agent string|table
---@param scope "user"|"project"|nil
---@return string
function M.config_path(agent, scope)
  local profile = M.normalize_profile(agent)
  local preset = PRESETS[profile.preset]
  if not preset or not preset.config_path then
    return ""
  end
  return vim.fn.expand(preset.config_path(profile, scope))
end

-- ─────────────── parsers ────────────────────────────────────────────────────

---Parse one line of `claude mcp list` output.
---Format: `name: url (TRANSPORT) - status_text`
---Returns nil on header / blank / unmatched lines.
---@param line string
---@return McphubAgents.Binding|nil
function M.parse_claude_line(line)
  if not line or line == "" then
    return nil
  end
  -- Skip headers like "Checking MCP server health…"
  if line:match "^Checking" or line:match "^%s*$" then
    return nil
  end

  -- name: url (TRANSPORT) - status
  local name, url, transport, status =
    line:match "^([^:]+):%s+(.-)%s+%((%w+)%)%s+%-%s+(.+)$"
  if not name then
    return nil
  end

  local norm_status
  local s = status:lower()
  if s:find "connected" then
    norm_status = "connected"
  elseif s:find "fail" then
    norm_status = "failed"
  elseif s:find "auth" then
    norm_status = "auth"
  else
    norm_status = "unknown"
  end

  return {
    name = vim.trim(name),
    url = vim.trim(url),
    transport = transport,
    status = norm_status,
    raw = line,
  }
end

---Parse `codex mcp list` table output.
---Header: "Name  Command  Args  Env  Cwd  Status  Auth"
---Two sections (stdio + HTTP) separated by a blank line — both parsed.
---@param stdout string
---@return McphubAgents.Binding[]
function M.parse_codex_output(stdout)
  local bindings = {}
  local in_header = true
  for line in stdout:gmatch "[^\r\n]+" do
    if line:match "^%-%-%-" or line:match "^%s*$" then
      in_header = true -- blank line = new section header coming
    elseif in_header and line:match "^Name%s" then
      in_header = false -- this IS the header row; skip it
    elseif not in_header and line ~= "" then
      -- Split on 2+ spaces; first token = Name, last usable = Status
      local parts = {}
      for part in line:gmatch "%S[^%s]*" do
        table.insert(parts, part)
      end
      local name = parts[1]
      if name and name ~= "" then
        local raw_status = parts[#parts] or ""
        local norm_status
        if raw_status:lower():find "enabled" then
          norm_status = "connected"
        elseif raw_status:lower():find "disabled" then
          norm_status = "unknown"
        elseif raw_status:lower():find "fail" then
          norm_status = "failed"
        else
          norm_status = "unknown"
        end
        -- URL is in a dedicated column only for HTTP servers
        local url = ""
        for _, p in ipairs(parts) do
          if p:match "^https?://" then
            url = p
            break
          end
        end
        table.insert(bindings, { name = name, url = url, transport = "?", status = norm_status, raw = line })
      end
    end
  end
  return bindings
end

---Parse `opencode mcp list` boxed output.
---"●  ✓ name" → connected; "●  ○ name" → disabled.
---The next indented line carries the URL.
---@param stdout string
---@return McphubAgents.Binding[]
function M.parse_opencode_output(stdout)
  local bindings = {}
  local last_binding = nil
  for line in stdout:gmatch "[^\r\n]+" do
    -- strip ANSI escape codes
    local clean = line:gsub("\27%[[%d;]*m", "")
    -- connected: ●  ✓ name
    local name_conn = clean:match "%●%s+%✓%s+(%S+)"
    -- disabled: ●  ○ name
    local name_dis = clean:match "%●%s+%○%s+(%S+)"
    if name_conn then
      last_binding = { name = name_conn, url = "", transport = "?", status = "connected", raw = line }
      table.insert(bindings, last_binding)
    elseif name_dis then
      last_binding = { name = name_dis, url = "", transport = "?", status = "unknown", raw = line }
      table.insert(bindings, last_binding)
    elseif last_binding and clean:match "^%s+http" then
      -- indented URL line following the name line
      last_binding.url = vim.trim(clean)
    else
      -- other structural lines (headers, separators) — ignore
      last_binding = nil
    end
  end
  return bindings
end

-- ─────────────── public API ─────────────────────────────────────────────────

---Run `<agent> mcp list` async. on_done receives {ok, bindings, stdout, stderr}.
---@param agent string|table
---@param on_done fun(result: { ok: boolean, bindings: McphubAgents.Binding[], stdout: string, stderr: string })
function M.list(agent, on_done)
  local profile = M.normalize_profile(agent)
  if not M.is_available(profile) then
    on_done { ok = false, bindings = {}, stdout = "", stderr = profile.command .. " not on PATH" }
    return
  end

  vim.system({ profile.command, "mcp", "list" }, { text = true, env = M.env(profile) }, function(o)
    local stdout = o.stdout or ""
    local stderr = o.stderr or ""
    local bindings = {}
    if profile.preset == "claude" then
      for line in stdout:gmatch "[^\r\n]+" do
        local b = M.parse_claude_line(line)
        if b then
          table.insert(bindings, b)
        end
      end
    elseif profile.preset == "codex" then
      bindings = M.parse_codex_output(stdout)
    elseif profile.preset == "opencode" then
      bindings = M.parse_opencode_output(stdout)
    end
    vim.schedule(function()
      on_done { ok = o.code == 0, bindings = bindings, stdout = stdout, stderr = stderr }
    end)
  end)
end

---Register an MCP endpoint binding.
---CLI shape differs per agent:
---  claude:   mcp add [--scope <s>] --transport sse <name> <url>
---  codex:    mcp add <name> --url <url>
---  opencode: not supported via CLI → returns ok=false with guidance
---@param agent string|table
---@param name string
---@param url string
---@param scope "user"|"project"|nil
---@param on_done fun(result: { ok: boolean, stdout: string, stderr: string })
function M.register(agent, name, url, scope, on_done)
  local profile = M.normalize_profile(agent)
  if not M.is_available(profile) then
    on_done { ok = false, stdout = "", stderr = profile.command .. " not on PATH" }
    return
  end

  if profile.preset == "opencode" then
    on_done {
      ok = false,
      stdout = "",
      stderr = "opencode does not support 'mcp add' via CLI. Press 'e' to edit "
        .. M.config_path(profile, nil),
    }
    return
  end

  local cmd = { profile.command, "mcp", "add" }
  if profile.preset == "claude" then
    if scope then
      vim.list_extend(cmd, { "--scope", scope })
    end
    vim.list_extend(cmd, { "--transport", "sse", name, url })
  elseif profile.preset == "codex" then
    -- codex: mcp add <name> --url <url>  (no --transport, no --scope)
    vim.list_extend(cmd, { name, "--url", url })
  end

  vim.system(cmd, { text = true, env = M.env(profile) }, function(o)
    vim.schedule(function()
      on_done { ok = o.code == 0, stdout = o.stdout or "", stderr = o.stderr or "" }
    end)
  end)
end

---Remove a binding.
---@param agent string|table
---@param name string
---@param scope "user"|"project"|nil
---@param on_done fun(result: { ok: boolean, stdout: string, stderr: string })
function M.unregister(agent, name, scope, on_done)
  local profile = M.normalize_profile(agent)
  if not M.is_available(profile) then
    on_done { ok = false, stdout = "", stderr = profile.command .. " not on PATH" }
    return
  end

  if profile.preset == "opencode" then
    on_done {
      ok = false,
      stdout = "",
      stderr = "opencode does not support 'mcp remove' via CLI. Press 'e' to edit "
        .. M.config_path(profile, nil),
    }
    return
  end

  local cmd = { profile.command, "mcp", "remove" }
  if profile.preset == "claude" and scope then
    vim.list_extend(cmd, { "--scope", scope })
  end
  table.insert(cmd, name)

  vim.system(cmd, { text = true, env = M.env(profile) }, function(o)
    vim.schedule(function()
      on_done { ok = o.code == 0, stdout = o.stdout or "", stderr = o.stderr or "" }
    end)
  end)
end

---Toggle a binding from one URL target to another (remove then add).
---Used to flip between /mcp and /mcp-lean.
---@param agent string|table
---@param name string
---@param new_url string
---@param scope "user"|"project"|nil
---@param on_done fun(result: { ok: boolean, stdout: string, stderr: string })
function M.toggle(agent, name, new_url, scope, on_done)
  M.unregister(agent, name, scope, function(rm)
    -- ignore unregister failure (binding may not exist); proceed to add
    M.register(agent, name, new_url, scope, function(add)
      on_done {
        ok = add.ok,
        stdout = (rm.stdout or "") .. (add.stdout or ""),
        stderr = (rm.stderr or "") .. (add.stderr or ""),
      }
    end)
  end)
end

return M
