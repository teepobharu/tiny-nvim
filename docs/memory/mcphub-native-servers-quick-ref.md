# MCPHub Native Lua Servers - Quick Reference

Quick lookup for common patterns. See `mcphub-native-lua-servers.md` for full details.

## Registration

```lua
local mcphub = require("mcphub")

-- Add a tool (creates server if not exists)
mcphub.add_tool("myserver", {
  name = "tool_name",
  description = "What it does",
  inputSchema = { type = "object", properties = { ... } },
  handler = function(req, res)
    res:text("result"):send()
  end,
})

-- Add a resource
mcphub.add_resource("myserver", {
  uri = "scheme://static/resource",
  handler = function(req, res)
    res:text("content"):send()
  end,
})

-- Add a resource template
mcphub.add_resource_template("myserver", {
  uriTemplate = "scheme://{id}/content",
  handler = function(req, res)
    local id = req.params.id
    res:text("content for " .. id):send()
  end,
})

-- Add a prompt
mcphub.add_prompt("myserver", {
  name = "my_prompt",
  arguments = {
    { name = "param", description = "...", required = true },
  },
  handler = function(req, res)
    res:system():text("System message")
       :user():text("User message")
       :send()
  end,
})
```

## Response Methods (All Chainable)

### ToolResponse
```lua
res:text(string)
   :image(base64, mime)
   :audio(base64, mime)
   :resource({uri, text, mimeType})
   :error(message, details)
   :send()
```

### ResourceResponse
```lua
res:text(string, mime?)      -- mime defaults to "text/plain"
   :blob(binary, mime?)      -- mime defaults to "application/octet-stream"
   :image(binary, mime)
   :audio(binary, mime?)
   :error(message, details)
   :send()
```

### PromptResponse
```lua
res:system():text("system message")
   :user():text("user question")
   :llm():text("assistant response")
   :image(base64, mime)
   :blob(binary, mime)
   :audio(binary, mime)
   :resource(resource)
   :error(message, details)
   :send()
```

## Request Objects

```lua
-- In handler
function(req, res)
  -- ToolRequest / ResourceRequest / PromptRequest
  req.params           -- Arguments or template params (URL decoded)
  req.server           -- NativeServer instance
  req.editor_info      -- { bufnr, buf_name, cursor_pos, visual_selection, cwd }
  req.tool / req.resource / req.prompt -- Capability definition
end
```

## Async Patterns

### Sync
```lua
handler = function(req, res)
  res:text("result"):send()
end
```

### vim.schedule
```lua
handler = function(req, res)
  vim.schedule(function()
    res:text("async result"):send()
  end)
end
```

### vim.fn.jobstart (shell commands)
```lua
handler = function(req, res)
  local output = ""
  
  vim.fn.jobstart("command", {
    on_stdout = function(_, data)
      if data then output = output .. table.concat(data, "\n") end
    end,
    on_exit = function(_, code)
      if code == 0 then
        res:text(output):send()
      else
        res:error("Failed"):send()
      end
    end,
  })
  -- DON'T return or call res:send() here
end
```

### HTTP with curl
```lua
handler = function(req, res)
  local output = ""
  
  vim.fn.jobstart({ "curl", "-s", req.params.url }, {
    on_stdout = function(_, data)
      if data then output = output .. table.concat(data, "\n") end
    end,
    on_exit = function(_, code)
      res:text(output):send()
    end,
  })
end
```

## Neovim API in Handlers

```lua
-- Buffer info
local bufnr = req.editor_info.bufnr
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

-- File ops (sync, don't block)
local stat = vim.loop.fs_stat(path)
local ok = vim.loop.fs_access(path, "R")

-- Directory scan
local handle = vim.loop.fs_scandir(path)
while true do
  local name, type = vim.loop.fs_scandir_next(handle)
  if not name then break end
  -- process name, type
end

-- System info
local cwd = vim.loop.cwd()
local hostname = vim.loop.os_gethostname()
```

## Common Schemas

```lua
-- String property
{
  type = "string",
  description = "What is this?",
  default = "optional default",
  pattern = "^[a-z]+$",  -- regex
  minLength = 1,
  maxLength = 100,
}

-- Number
{
  type = "number",
  description = "...",
  minimum = 0,
  maximum = 100,
  default = 50,
}

-- Enum
{
  type = "string",
  enum = { "option1", "option2", "option3" },
  default = "option1",
}

-- Array
{
  type = "array",
  items = { type = "string" },
  minItems = 1,
  maxItems = 10,
}
```

## Error Handling

```lua
-- Simple error
return res:error("Something went wrong")

-- Error with details
return res:error("Failed to process", {
  code = 400,
  hint = "Check your input",
})

-- Validate inputs
if not req.params.name then
  return res:error("Parameter 'name' is required")
end

-- Catch exceptions (auto-wrapped in pcall)
if some_error then
  error("Will be caught and sent as error response")
end
```

## URL Template Parameters

```lua
-- Template: "file://{path}/lines/{start}/{end}"
-- URI: "file://home%2Fuser%2Ffile.txt/lines/1/10"
-- Result: req.params = {
--   path = "home/user/file.txt",  -- Auto-decoded
--   start = "1",
--   end = "10",
-- }

-- CRITICAL: Path separators MUST be %2F encoded
-- home%2Fuser%2Ffile.txt ✓ (correct)
-- home/user/file.txt ✗ (won't match template)
```

## Testing

In Neovim:
```vim
" View all servers
:MCPHub

" Check if registered
:lua print(require("mcphub").is_native_server("myserver"))

" Call a tool directly
:lua require("mcphub").is_native_server("myserver"):call_tool("tool_name", {arg="value"})
```

## Key Limits

- Timeout: 5 seconds default
- Async handlers: Can exceed 5s if using callbacks
- URL params: Must be URL-encoded (max 255 chars)
- Chain: All response methods return self for chaining

## Files for Reference

- Full API: `~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/lua/mcphub/native/init.lua`
- Request/Response: `lua/mcphub/native/utils/request.lua` + `response.lua`
- Examples: `lua/mcphub/native/neovim/terminal.lua` (jobstart), `files/init.lua` (vim.loop)

---

See `mcphub-native-lua-servers.md` for complete reference with all methods and detailed examples.
