local M = {}

-- Active server state
local state = {
  server = nil,
  port = nil,
  sse_clients = {}, -- list of uv_tcp handles waiting for reload events
}

local ALLOWED_ROOTS = {} -- populated per-session by init

local MIME = {
  png = "image/png",
  jpg = "image/jpeg",
  jpeg = "image/jpeg",
  gif = "image/gif",
  svg = "image/svg+xml",
  webp = "image/webp",
  bmp = "image/bmp",
  ico = "image/x-icon",
  css = "text/css",
  js = "application/javascript",
  json = "text/plain; charset=utf-8",
  html = "text/html; charset=utf-8",
  md = "text/plain; charset=utf-8",
  markdown = "text/plain; charset=utf-8",
  txt = "text/plain; charset=utf-8",
  pdf = "application/pdf",
  -- text source files → plain text so browser previews instead of downloading
  lua = "text/plain; charset=utf-8",
  py = "text/plain; charset=utf-8",
  rb = "text/plain; charset=utf-8",
  go = "text/plain; charset=utf-8",
  rs = "text/plain; charset=utf-8",
  ts = "text/plain; charset=utf-8",
  tsx = "text/plain; charset=utf-8",
  jsx = "text/plain; charset=utf-8",
  yaml = "text/plain; charset=utf-8",
  yml = "text/plain; charset=utf-8",
  toml = "text/plain; charset=utf-8",
  sh = "text/plain; charset=utf-8",
  bash = "text/plain; charset=utf-8",
  zsh = "text/plain; charset=utf-8",
  fish = "text/plain; charset=utf-8",
  c = "text/plain; charset=utf-8",
  cs = "text/plain; charset=utf-8",
  cpp = "text/plain; charset=utf-8",
  h = "text/plain; charset=utf-8",
  hpp = "text/plain; charset=utf-8",
  java = "text/plain; charset=utf-8",
  kt = "text/plain; charset=utf-8",
  swift = "text/plain; charset=utf-8",
  php = "text/plain; charset=utf-8",
  sql = "text/plain; charset=utf-8",
  xml = "text/plain; charset=utf-8",
  scss = "text/plain; charset=utf-8",
  sass = "text/plain; charset=utf-8",
  log = "text/plain; charset=utf-8",
  conf = "text/plain; charset=utf-8",
  ini = "text/plain; charset=utf-8",
  env = "text/plain; charset=utf-8",
}

--- Security: reject paths with .. or outside allowed roots
local function is_safe_path(path)
  if path:find("%.%.", 1, true) then
    return false
  end
  for _, root in ipairs(ALLOWED_ROOTS) do
    if path:sub(1, #root) == root then
      return true
    end
  end
  return false
end

local function http_response(client, status, content_type, body)
  local header = string.format(
    "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n",
    status,
    content_type,
    #body
  )
  client:write(header .. body, function()
    client:close()
  end)
end

local function parse_query_param(query, key)
  if not query then
    return nil
  end
  local pattern = key .. "=([^&]+)"
  local val = query:match(pattern)
  if val then
    -- simple percent-decode
    val = val:gsub("%%(%x%x)", function(h)
      return string.char(tonumber(h, 16))
    end)
    val = val:gsub("+", " ")
  end
  return val
end

local function serve_md(client, path)
  if not path or not is_safe_path(path) then
    http_response(client, "403 Forbidden", "text/plain", "Forbidden")
    return
  end
  local f = io.open(path, "r")
  if not f then
    http_response(client, "404 Not Found", "text/plain", "Not found: " .. path)
    return
  end
  local body = f:read "*a"
  f:close()
  http_response(client, "200 OK", "text/plain; charset=utf-8", body)
end

local function serve_asset(client, path)
  if not path or path:sub(1, 1) ~= "/" then
    http_response(client, "400 Bad Request", "text/plain", "Need absolute path")
    return
  end
  if not is_safe_path(path) then
    http_response(client, "403 Forbidden", "text/plain", "Forbidden")
    return
  end
  local f = io.open(path, "rb")
  if not f then
    http_response(client, "404 Not Found", "text/plain", "Not found: " .. path)
    return
  end
  local body = f:read "*a"
  f:close()
  local ext = (path:match "%.([%w]+)$" or ""):lower()
  local mime = MIME[ext] or "application/octet-stream"
  http_response(client, "200 OK", mime, body)
end

local function serve_ls(client, path)
  if not path or not is_safe_path(path) then
    http_response(client, "403 Forbidden", "application/json", '{"error":"Forbidden"}')
    return
  end
  local handle = vim.uv.fs_scandir(path)
  if not handle then
    http_response(client, "404 Not Found", "application/json", '{"error":"Not found"}')
    return
  end
  local dirs, files = {}, {}
  while true do
    local name, ftype = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if name ~= "." and name ~= ".." and name:sub(1, 1) ~= "." then
      if ftype == "directory" then
        table.insert(dirs, name)
      else
        table.insert(files, name)
      end
    end
  end
  table.sort(dirs)
  table.sort(files)
  local function json_str(s)
    return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
  end
  local function json_arr(t)
    local parts = {}
    for _, v in ipairs(t) do table.insert(parts, json_str(v)) end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  local body = '{"dirs":' .. json_arr(dirs) .. ',"files":' .. json_arr(files) .. '}'
  http_response(client, "200 OK", "application/json; charset=utf-8", body)
end

local function html_escape(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

--- Serve a filesystem path: directory → simple HTML index; file → asset.
local function serve_path(client, path)
  if not is_safe_path(path) then
    http_response(client, "403 Forbidden", "text/plain", "Forbidden: " .. path)
    return
  end
  local stat = vim.uv.fs_stat(path)
  if not stat then
    http_response(client, "404 Not Found", "text/plain", "Not found: " .. path)
    return
  end
  if stat.type == "directory" then
    local handle = vim.uv.fs_scandir(path)
    if not handle then
      http_response(client, "500 Internal Server Error", "text/plain", "Cannot scan: " .. path)
      return
    end
    local dirs, files = {}, {}
    while true do
      local name, ftype = vim.uv.fs_scandir_next(handle)
      if not name then break end
      if name:sub(1, 1) ~= "." then
        if ftype == "directory" then table.insert(dirs, name) else table.insert(files, name) end
      end
    end
    table.sort(dirs)
    table.sort(files)
    local rows = {}
    local prefix = path:sub(-1) == "/" and path or (path .. "/")
    if path ~= "/" then
      local parent = path:match("^(.*)/[^/]+$") or "/"
      if parent == "" then parent = "/" end
      table.insert(rows, string.format('<li><a href="%s">..</a></li>', html_escape(parent)))
    end
    for _, n in ipairs(dirs) do
      table.insert(rows, string.format('<li><a href="%s%s/">%s/</a></li>', html_escape(prefix), html_escape(n), html_escape(n)))
    end
    for _, n in ipairs(files) do
      table.insert(rows, string.format('<li><a href="%s%s">%s</a></li>', html_escape(prefix), html_escape(n), html_escape(n)))
    end
    local body = string.format(
      '<!doctype html><meta charset="utf-8"><title>%s</title><style>body{font-family:ui-monospace,monospace;background:#0d1117;color:#c9d1d9;padding:24px}a{color:#58a6ff;text-decoration:none}a:hover{text-decoration:underline}h1{font-size:14px;color:#8b949e}ul{list-style:none;padding:0}li{padding:2px 0}</style><h1>Index of %s</h1><ul>%s</ul>',
      html_escape(path), html_escape(path), table.concat(rows, "")
    )
    http_response(client, "200 OK", "text/html; charset=utf-8", body)
    return
  end
  serve_asset(client, path)
end

--- Open a path with the OS default app (macOS: open, Linux: xdg-open).
--- Returns a small HTML page so the browser tab closes itself.
local function serve_open(client, path)
  if not path or path == "" then
    http_response(client, "400 Bad Request", "text/plain", "Missing path")
    return
  end
  -- no is_safe_path check here — intentionally allow external paths
  -- but sanitise: reject shell metacharacters to prevent injection
  if path:match('[`$;|&<>%(%){}%[%]]') then
    http_response(client, "400 Bad Request", "text/plain", "Invalid path characters")
    return
  end
  local cmd = vim.fn.has("mac") == 1 and "open" or vim.fn.has("unix") == 1 and "xdg-open" or nil
  if not cmd then
    http_response(client, "501 Not Implemented", "text/plain", "Unsupported platform")
    return
  end
  vim.schedule(function()
    vim.fn.jobstart({ cmd, path }, { detach = true })
  end)
  -- respond with a self-closing page so the browser tab doesn't linger
  local body = '<!doctype html><meta charset="utf-8"><script>window.close();history.back();</script><p>Opening&hellip;</p>'
  http_response(client, "200 OK", "text/html; charset=utf-8", body)
end

local function serve_sse(client)
  -- SSE: keep connection open, do NOT close after header
  local header = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nAccess-Control-Allow-Origin: *\r\nConnection: keep-alive\r\n\r\n"
  client:write(header)
  -- send a keep-alive comment immediately
  client:write(": connected\n\n")
  table.insert(state.sse_clients, client)
  -- clean up on disconnect
  client:read_start(function(_err, _data)
    if _err or _data == nil then
      for i, c in ipairs(state.sse_clients) do
        if c == client then
          table.remove(state.sse_clients, i)
          break
        end
      end
      pcall(function()
        client:close()
      end)
    end
  end)
end

--- Push reload event to all SSE clients
function M.broadcast_reload()
  local dead = {}
  for i, client in ipairs(state.sse_clients) do
    local ok, err = pcall(function()
      client:write("event: reload\ndata: 1\n\n")
    end)
    if not ok then
      dead[#dead + 1] = i
    end
  end
  -- remove dead clients in reverse
  for i = #dead, 1, -1 do
    table.remove(state.sse_clients, dead[i])
  end
end

local function handle_request(client, request)
  local method, path_qs = request:match("^(%u+) (/[^ ]*)")
  if not method then
    http_response(client, "400 Bad Request", "text/plain", "Bad Request")
    return
  end

  local path, query = path_qs:match("^([^?]*)%??(.*)")

  if path == "/" or path == "/index.html" then
    local tmpl = require "mdpreview.template"
    local html = tmpl.html(state.port, state.files, state.initial, state.roots)
    http_response(client, "200 OK", "text/html; charset=utf-8", html)
  elseif path == "/md" then
    local fpath = parse_query_param(query, "path")
    serve_md(client, fpath)
  elseif path == "/asset" then
    local fpath = parse_query_param(query, "path")
    serve_asset(client, fpath)
  elseif path == "/ls" then
    local fpath = parse_query_param(query, "path")
    serve_ls(client, fpath)
  elseif path == "/events" then
    serve_sse(client)
  elseif path == "/open" then
    local fpath = parse_query_param(query, "path")
    serve_open(client, fpath)
  elseif path:sub(1, 1) == "/" then
    -- fallback: treat path as a filesystem path (supports breadcrumb file:// fallback)
    serve_path(client, path)
  else
    http_response(client, "404 Not Found", "text/plain", "Not found")
  end
end

function M.start(files, initial, roots)
  if state.server then
    return state.port
  end

  ALLOWED_ROOTS = roots or {}
  state.files = files
  state.initial = initial
  state.roots = ALLOWED_ROOTS
  state.sse_clients = {}

  local server = vim.uv.new_tcp()
  server:bind("127.0.0.1", 0)
  server:listen(128, function(err)
    assert(not err, err)
    local client = vim.uv.new_tcp()
    server:accept(client)
    local buf = ""
    client:read_start(function(rerr, data)
      if rerr or not data then
        pcall(function()
          client:close()
        end)
        return
      end
      buf = buf .. data
      -- wait for end of HTTP headers
      if buf:find("\r\n\r\n", 1, true) then
        client:read_stop()
        vim.schedule(function()
          handle_request(client, buf)
        end)
      end
    end)
  end)

  local addr = server:getsockname()
  state.port = addr.port
  state.server = server

  return state.port
end

function M.stop()
  for _, c in ipairs(state.sse_clients) do
    pcall(function()
      c:close()
    end)
  end
  state.sse_clients = {}
  if state.server then
    state.server:close()
    state.server = nil
    state.port = nil
    state.files = nil
    state.initial = nil
  end
end

function M.is_running()
  return state.server ~= nil
end

function M.port()
  return state.port
end

return M
