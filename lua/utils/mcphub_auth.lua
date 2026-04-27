--- MCPHub OAuth storage utilities
--- Provides read/write/clear helpers for ~/.local/share/mcp-hub/oauth-storage.json.
---
--- Background: mcp-hub uses Dynamic Client Registration (DCR). When an upstream MCP
--- OAuth server resets its registry (e.g. pod restart), the stored client_id becomes
--- stale. The server then rejects auth attempts with "client ID not found in registry".
--- mcp-hub exposes no clear-auth API endpoint, so we manipulate the JSON file directly.
---
--- Workflow:
---   :MCPHubClearAuth           -- picker: select from servers with stored creds
---   :MCPHubClearAuth <url>     -- clear a specific server URL non-interactively
---   Then restart the server from :MCPHub UI (press R) to trigger fresh DCR.
---
--- See: docs/memory/mcphub.md
local M = {}

local LOG_TAG = "[mcphub_auth]"

-- ---------------------------------------------------------------------------
-- Paths
-- ---------------------------------------------------------------------------

--- Resolve the oauth-storage.json path respecting XDG_DATA_HOME.
---@return string
function M.storage_path()
  local xdg = vim.env.XDG_DATA_HOME or (vim.fn.expand "~" .. "/.local/share")
  return xdg .. "/mcp-hub/oauth-storage.json"
  -- ~/.local/share/mcp-hub/oauth-storage.json
end

-- ---------------------------------------------------------------------------
-- Read / Write
-- ---------------------------------------------------------------------------

--- Read and JSON-decode oauth-storage.json.
---@return table<string, {clientInfo: table|nil, tokens: table|nil, codeVerifier: string|nil}>
function M.read()
  local path = M.storage_path()
  local f = io.open(path, "r")
  if not f then
    return {}
  end
  local raw = f:read "*a"
  f:close()
  if not raw or raw == "" then
    return {}
  end
  local ok, decoded = pcall(vim.fn.json_decode, raw)
  if not ok or type(decoded) ~= "table" then
    vim.notify(LOG_TAG .. " failed to parse " .. path, vim.log.levels.WARN)
    return {}
  end
  return decoded
end

--- Write a table back to oauth-storage.json atomically (temp + rename).
--- Also writes a timestamped .bak.<ts> backup alongside the file.
---@param data table
---@return boolean ok, string? err
function M.write(data)
  local path = M.storage_path()
  local ok_enc, encoded = pcall(vim.fn.json_encode, data)
  if not ok_enc then
    return false, "json_encode failed: " .. tostring(encoded)
  end

  -- Pretty-print via jq if available, else use raw encode
  local pretty = encoded
  local jq = vim.fn.exepath "jq"
  if jq ~= "" then
    local handle = io.popen(string.format("echo %s | jq .", vim.fn.shellescape(encoded)))
    if handle then
      local out = handle:read "*a"
      handle:close()
      if out and out ~= "" then
        pretty = out
      end
    end
  end

  -- Backup existing file
  local bak = path .. ".bak." .. os.time()
  os.rename(path, bak)

  -- Atomic write via temp file
  local tmp = path .. ".tmp." .. os.time()
  local f, ferr = io.open(tmp, "w")
  if not f then
    -- Restore backup
    os.rename(bak, path)
    return false, "cannot open temp file: " .. tostring(ferr)
  end
  f:write(pretty)
  f:close()

  local ok_mv, mv_err = os.rename(tmp, path)
  if not ok_mv then
    -- Restore backup
    os.rename(bak, path)
    return false, "rename failed: " .. tostring(mv_err)
  end

  return true, nil
end

-- ---------------------------------------------------------------------------
-- Query helpers
-- ---------------------------------------------------------------------------

--- Return entries that have any stored credential (clientInfo or tokens non-null).
--- Each item has .url, .has_client (bool), .has_tokens (bool) for display.
---@return {url: string, has_client: boolean, has_tokens: boolean}[]
function M.list_authed()
  local data = M.read()
  local result = {}
  for url, entry in pairs(data) do
    local has_client = entry.clientInfo ~= nil and entry.clientInfo ~= vim.NIL
    local has_tokens = entry.tokens ~= nil and entry.tokens ~= vim.NIL
    if has_client or has_tokens then
      table.insert(result, { url = url, has_client = has_client, has_tokens = has_tokens })
    end
  end
  -- Sort for stable picker order
  table.sort(result, function(a, b)
    return a.url < b.url
  end)
  return result
end

--- Return all stored server URLs (authed or not), for tab-completion.
---@return string[]
function M.list_all_urls()
  local data = M.read()
  local urls = {}
  for url, _ in pairs(data) do
    table.insert(urls, url)
  end
  table.sort(urls)
  return urls
end

-- ---------------------------------------------------------------------------
-- Clear
-- ---------------------------------------------------------------------------

--- Reset a single server entry to all-null credentials.
---@param url string  The server URL key to clear (must exist in storage).
---@return boolean ok, string? err
function M.clear(url)
  local data = M.read()

  if data[url] == nil then
    return false, "URL not found in oauth-storage: " .. url
  end

  data[url] = { clientInfo = vim.NIL, tokens = vim.NIL, codeVerifier = vim.NIL }

  local ok, err = M.write(data)
  if not ok then
    return false, err
  end
  return true, nil
end

-- ---------------------------------------------------------------------------
-- High-level UI helpers (called from command / keymap)
-- ---------------------------------------------------------------------------

--- Clear a URL and emit a vim.notify result. Used for direct-arg command flow.
---@param url string
function M.clear_notify(url)
  local ok, err = M.clear(url)
  if ok then
    vim.notify(
      LOG_TAG .. " cleared OAuth for:\n  " .. url .. "\nRestart the server in :MCPHub (press R on the row) to re-auth.",
      vim.log.levels.INFO
    )
  else
    vim.notify(LOG_TAG .. " " .. tostring(err), vim.log.levels.ERROR)
  end
end

--- Find the 1-based line number of a URL key inside the raw JSON file.
--- Returns nil when the key cannot be located.
---@param path string  Absolute path to the JSON file.
---@param url  string  The server URL to search for.
---@return integer|nil
local function url_line_in_file(path, url)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local lnum = 0
  local needle = vim.pesc(url)
  for line in f:lines() do
    lnum = lnum + 1
    if line:find(needle) then
      f:close()
      return lnum
    end
  end
  f:close()
  return nil
end

--- Build picker items from current oauth-storage state.
--- Re-read from disk each call so picker:refresh() shows updated state.
---@return table[]
local function build_picker_items()
  local storage = M.storage_path()
  local items = {}
  for _, entry in ipairs(M.list_authed()) do
    local badges = (entry.has_client and "[client] " or "         ") .. (entry.has_tokens and "[tokens]" or "        ")
    local lnum = url_line_in_file(storage, entry.url) or 1
    table.insert(items, {
      text = badges .. "  " .. entry.url,
      file = storage,
      pos = { lnum, 0 },
      url = entry.url,
      has_client = entry.has_client,
      has_tokens = entry.has_tokens,
    })
  end
  return items
end

--- Open a Snacks picker listing authed servers with:
---   - JSON preview of oauth-storage.json, cursor on the hovered server
---   - <CR>   clear credentials and refresh the list (stays open)
---   - <a-e>  open oauth-storage.json in the editor at the server's line
function M.pick_and_clear()
  local authed = M.list_authed()
  if #authed == 0 then
    vim.notify(LOG_TAG .. " No servers with stored OAuth credentials found.", vim.log.levels.INFO)
    return
  end

  local storage = M.storage_path()

  Snacks.picker.pick {
    source = "mcphub_oauth",
    title = "MCPHub OAuth — <CR> clear · <M-e> edit file",
    -- finder is called on every picker:refresh() so the list updates after a clear
    finder = function(_opts, _ctx)
      return build_picker_items()
    end,
    format = "text",
    -- preview = "file" uses item.file + item.pos to show & scroll the JSON file
    preview = "file",
    layout = { preset = "default" },
    confirm = function(picker, item)
      if not item then
        return
      end
      M.clear_notify(item.url)
      -- Stay open; refresh so the cleared entry disappears from the list
      vim.defer_fn(function()
        picker:refresh()
      end, 50)
    end,
    win = {
      input = {
        keys = {
          ["<M-e>"] = {
            function()
              -- key callbacks receive snacks.win, not picker — fetch it by source
              local picker = (Snacks.picker.get { source = "mcphub_oauth" })[1]
              if not picker then
                return
              end
              local item = picker:current()
              if not item then
                return
              end
              local lnum = item.pos[1]
              local main = picker.main
              picker:close()
              vim.schedule(function()
                vim.api.nvim_set_current_win(main)
                vim.cmd("edit " .. vim.fn.fnameescape(storage))
                vim.api.nvim_win_set_cursor(0, { lnum, 0 })
                vim.cmd "normal! zz"
              end)
            end,
            mode = { "n", "i" },
            desc = "Open oauth-storage.json at this server",
          },
        },
      },
    },
  }
end

return M
