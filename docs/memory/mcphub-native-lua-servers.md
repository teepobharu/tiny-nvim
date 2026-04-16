# MCPHub Native Lua Servers - Complete API Reference

**Research Date**: April 4, 2026  
**MCPHub Version**: 6.2.0 (installed)  
**Plugin Location**: `~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/`

---

## Overview

MCPHub's native Lua servers allow you to write MCP (Model Communication Protocol) servers directly in Lua that run within Neovim. Unlike external MCP servers (Node, Python, etc.), native servers have zero latency overhead and full access to Neovim APIs.

### Key Facts
- **Runs in-process** within Neovim (Lua VM)
- **No external processes** required
- **Full Neovim API access** (`vim.api.*`, `vim.loop.*`, etc.)
- **Async support** via `vim.schedule()` and `vim.fn.jobstart()`
- **Supports 4 capability types**: Tools, Resources, Resource Templates, Prompts

---

## Registration Methods

### Method 1: Configuration-Based (Setup)

Define servers in your MCPHub setup config:

```lua
require("mcphub").setup({
  native_servers = {
    weather = {
      name = "weather",
      displayName = "Weather Server",
      capabilities = {
        tools = { ... },
        resources = { ... },
        resourceTemplates = { ... },
        prompts = { ... },
      },
    },
  },
})
```

**Source**: `lua/mcphub/native/init.lua:189-207` (`Native.setup()`)

### Method 2: API-Based (Runtime)

Register servers incrementally after setup:

```lua
local mcphub = require("mcphub")

-- Create server and add a tool (server auto-created if not exists)
mcphub.add_tool("weather", {
  name = "get_weather",
  handler = function(req, res) ... end,
})

-- Add a resource to existing server
mcphub.add_resource("weather", {
  uri = "weather://current/london",
  handler = function(req, res) ... end,
})

-- Add a resource template
mcphub.add_resource_template("weather", {
  uriTemplate = "weather://current/{city}",
  handler = function(req, res) ... end,
})

-- Add a prompt
mcphub.add_prompt("weather", {
  name = "get_forecast",
  handler = function(req, res) ... end,
})
```

**Source**: `lua/mcphub/native/init.lua:70-187` (API functions)

---

## Complete Native Server API

### Request Objects

#### 1. ToolRequest

**Properties** (from `lua/mcphub/native/utils/request.lua`):

```lua
---@class ToolRequest
---@field params table Tool arguments (validated against inputSchema)
---@field tool MCPTool Complete tool definition
---@field server NativeServer Server instance
---@field caller table Additional context from caller
---@field editor_info EditorInfo Current editor state
```

**Editor Info Structure**:
```lua
{
  bufnr = number,           -- Current buffer number
  buf_name = string,        -- Buffer file path
  buf_filetype = string,    -- File type (ft)
  cursor_pos = {row, col},  -- Cursor position (1-indexed)
  visual_selection = {
    mode = string,          -- "v", "V", "^V"
    start_row = number,
    start_col = number,
    end_row = number,
    end_col = number,
    text = string,
  },
  cwd = string,             -- Current working directory
}
```

#### 2. ResourceRequest

**Properties**:

```lua
---@class ResourceRequest
---@field params table<string, string> Template parameters from URI
---@field uri string Complete requested URI
---@field uriTemplate string|nil Original template pattern if from template
---@field resource MCPResource|MCPResourceTemplate Complete resource definition
---@field server NativeServer Server instance
---@field caller table Additional context from caller
---@field editor_info EditorInfo Current editor state
```

**Example - URI Template Matching**:
```lua
-- Template: "file://{path}/lines"
-- URI: "file://home%2Fuser%2Ffile.txt/lines"
-- Result: req.params = { path = "home/user/file.txt" }
-- NOTE: Path separators MUST be URL-encoded (%2F for /)
```

**Source**: `lua/mcphub/native/utils/server.lua:68-96` (extract_params function)

#### 3. PromptRequest

**Properties**:

```lua
---@class PromptRequest
---@field params table<string, string> Template parameters from prompt arguments
---@field prompt MCPPrompt Complete prompt definition
---@field server NativeServer Server instance
---@field caller table Additional context from caller
---@field editor_info EditorInfo Current editor state
```

---

### Response Objects

All response objects have these common methods:

#### BaseResponse (inherited by all)

```lua
---@class BaseResponse
---@field output_handler function|nil Async callback handler
---@field result table Response data
---@field send fun(self: BaseResponse, result?: table): table Send response (async safe)
---@field error fun(self: BaseResponse, message: string, details?: table): table Send error
```

#### ToolResponse

**Methods**:

```lua
---@class ToolResponse : BaseResponse
---@field result { content: MCPContent[] }

-- Add text content (chainable)
res:text(text: string): ToolResponse

-- Add image content (chainable)
res:image(data: string, mime: string): ToolResponse

-- Add audio content (chainable)
res:audio(data: string, mime?: string): ToolResponse

-- Add resource reference (chainable)
res:resource(resource: MCPResourceContent): ToolResponse

-- Send error response
res:error(message: string, details?: table): table

-- Send the response (required at end)
res:send(result?: table): table
```

**MCPContent Structure**:
```lua
{
  type = "text" | "image" | "audio" | "resource",
  text? = string,  -- For "text" type
  data? = string,  -- For "image"/"audio" (base64 encoded)
  mimeType? = string,
  resource? = {    -- For "resource" type
    uri = string,
    text? = string,
    blob? = string,
    mimeType = string,
  },
}
```

**Example**:
```lua
handler = function(req, res)
  res:text("Status: OK")
     :text("\nDetails: ...")
     :send()
end
```

**Source**: `lua/mcphub/native/utils/response.lua:34-113` (ToolResponse class)

#### ResourceResponse

**Methods**:

```lua
---@class ResourceResponse : BaseResponse
---@field result { contents: MCPResourceContent[] }

-- Add text content (chainable, mime defaults to "text/plain")
res:text(text: string, mime?: string): ResourceResponse

-- Add binary content (chainable, mime defaults to "application/octet-stream")
res:blob(data: string, mime?: string): ResourceResponse

-- Add image binary (chainable, mime defaults to "image/png")
res:image(data: string, mime: string): ResourceResponse

-- Add audio binary (chainable, mime defaults to "audio/mp3")
res:audio(data: string, mime?: string): ResourceResponse

-- Send error
res:error(message: string, details?: table): table

-- Send the response (required at end)
res:send(result?: table): table
```

**Example**:
```lua
handler = function(req, res)
  local content = "File content here..."
  res:text(content, "text/plain"):send()
end
```

**Source**: `lua/mcphub/native/utils/response.lua:115-184` (ResourceResponse class)

#### PromptResponse

**Methods**:

```lua
---@class PromptResponse : BaseResponse
---@field result { messages: MCPMessage[] }
---@field current_role string User role state ("user", "assistant", "system")

-- Set role to "user"
res:user(): PromptResponse

-- Set role to "assistant"
res:llm(): PromptResponse

-- Set role to "system"
res:system(): PromptResponse

-- Add text message with current role (chainable)
res:text(text: string): PromptResponse

-- Add image message (chainable)
res:image(data: string, mime?: string): PromptResponse

-- Add blob/binary message (chainable)
res:blob(data: string, mime?: string): PromptResponse

-- Add audio message (chainable)
res:audio(data: string, mime?: string): PromptResponse

-- Add resource message (chainable)
res:resource(resource: MCPResourceContent): PromptResponse

-- Send error
res:error(message: string, details?: table): table

-- Send the response
res:send(result?: table): table
```

**MCPMessage Structure**:
```lua
{
  role = "user" | "assistant" | "system",
  content = {
    type = "text" | "image" | "blob" | "audio" | "resource",
    text? = string,
    data? = string,
    mimeType? = string,
    resource? = { ... },
  },
}
```

**Example**:
```lua
handler = function(req, res)
  res:system():text("You are a helpful assistant")
     :user():text("Hello!")
     :llm():text("Hi there!")
     :send()
end
```

**Source**: `lua/mcphub/native/utils/response.lua:186-285` (PromptResponse class)

---

## Capability Definitions

### Tools

```lua
---@class MCPTool
---@field name string Tool identifier (required)
---@field description string|fun():string Tool description (optional, can be function)
---@field inputSchema? table|fun():table JSON Schema for validation (optional, can be function)
---@field handler fun(req: ToolRequest, res: ToolResponse): nil | table (required)
---@field needs_confirmation_window? boolean Whether to show confirmation UI (optional)
```

**Minimal Tool**:
```lua
{
  name = "hello",
  handler = function(req, res)
    return res:text("Hello world"):send()
  end,
}
```

**Tool with Schema**:
```lua
{
  name = "greet",
  description = "Greet someone by name",
  inputSchema = {
    type = "object",
    properties = {
      name = {
        type = "string",
        description = "Person's name",
      },
      age = {
        type = "number",
        description = "Person's age",
      },
    },
    required = { "name" },
  },
  handler = function(req, res)
    local greeting = string.format("Hello %s!", req.params.name)
    if req.params.age then
      greeting = greeting .. " You are " .. req.params.age .. " years old."
    end
    return res:text(greeting):send()
  end,
}
```

**Source**: `lua/mcphub/native/utils/server.lua:7-12` (MCPTool class)

### Resources (Static)

```lua
---@class MCPResource
---@field name? string Resource identifier
---@field description? string|fun():string Resource description
---@field mimeType? string MIME type (e.g., "text/plain")
---@field uri string Static URI (required)
---@field handler fun(req: ResourceRequest, res: ResourceResponse): nil | table (required)
```

**Minimal Resource**:
```lua
{
  uri = "example://greeting",
  handler = function(req, res)
    return res:text("Hello"):send()
  end,
}
```

**Named Resource**:
```lua
{
  name = "london_weather",
  description = "Current London weather",
  uri = "weather://current/london",
  mimeType = "text/plain",
  handler = function(req, res)
    return res:text("London: 22°C", "text/plain"):send()
  end,
}
```

**Source**: `lua/mcphub/native/utils/server.lua:14-19` (MCPResource class)

### Resource Templates

```lua
---@class MCPResourceTemplate
---@field name? string Template identifier
---@field description? string|fun():string Template description
---@field mimeType? string Default MIME type
---@field uriTemplate string URI with {params} (required)
---@field handler fun(req: ResourceRequest, res: ResourceResponse): nil | table (required)
```

**Minimal Template**:
```lua
{
  uriTemplate = "users://{id}",
  handler = function(req, res)
    return res:text("User " .. req.params.id):send()
  end,
}
```

**URL Encoding in Templates**:
```
Template: "file://{path}/lines/{start}/{end}"
URI: "file://home%2Fuser%2Fdocs%2Ffile.txt/lines/1/10"
Result: req.params = {
  path = "home/user/docs/file.txt",
  start = "1",
  end = "10",
}
```

**Source**: `lua/mcphub/native/utils/server.lua:33-38` (MCPResourceTemplate class)

### Prompts

```lua
---@class MCPPromptArgument
---@field name string Argument name (required)
---@field description? string Argument description
---@field required? boolean Whether argument is required
---@field default? string Default value

---@class MCPPrompt
---@field name? string Prompt identifier
---@field description? string|fun():string Prompt description
---@field arguments? MCPPromptArgument[]|fun():MCPPromptArgument[] Arguments list
---@field handler? fun(req: PromptRequest, res: PromptResponse): nil | table (required)
```

**Minimal Prompt**:
```lua
{
  name = "guide",
  handler = function(req, res)
    res:system():text("You are helpful")
    res:send()
  end,
}
```

**Source**: `lua/mcphub/native/utils/server.lua:21-31` (MCPPrompt classes)

---

## Async Operations

### Synchronous Handlers

Default - handler runs synchronously, response sent immediately:

```lua
handler = function(req, res)
  res:text("Result"):send()
  -- Don't return anything, send() handles response
end
```

### Asynchronous Handlers

Use `vim.schedule()` for async operations within handlers:

```lua
handler = function(req, res)
  vim.schedule(function()
    -- Runs asynchronously on main Neovim loop
    res:text("Async result"):send()
  end)
  -- Don't return, don't call send() here
end
```

### Shell Command Execution (vim.fn.jobstart)

**Real Example from MCPHub** (`lua/mcphub/native/neovim/terminal.lua:114-187`):

```lua
handler = function(req, res)
  local command = req.params.command
  local cwd = req.params.cwd
  local output = ""
  local stderr_output = ""

  local options = {
    cwd = cwd,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            output = output .. line .. "\n"
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            stderr_output = stderr_output .. line .. "\n"
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      local result = ""
      result = result .. "Command: " .. command .. "\n"
      result = result .. "Exit Code: " .. exit_code .. "\n"
      if output ~= "" then
        result = result .. "Output:\n" .. output
      end
      if stderr_output ~= "" then
        result = result .. "Error Output:\n" .. stderr_output
      end
      res:text(result):send()
    end,
  }

  local job_id = vim.fn.jobstart(command, options)
  if job_id <= 0 then
    return res:error("Failed to start command")
  end
  -- Don't send() here, let on_exit handle it
end
```

**Key Points**:
- `vim.fn.jobstart(cmd, options)` starts async process
- `on_stdout`, `on_stderr`, `on_exit` callbacks receive updates
- Data is table of lines: `{ "line1", "line2", ... }`
- **Never return or send() from handler** - let callbacks handle response
- job_id: `>0` = success, `0` = invalid args, `-1` = not executable

### vim.loop (libuv) for File Operations

MCPHub uses `vim.loop` for synchronous file operations (doesn't block event loop):

```lua
-- File stats
local stat = vim.loop.fs_stat(path)
-- Returns: { type, size, mtime, ... }

-- Directory scanning
local handle = vim.loop.fs_scandir(path)
local name, type = vim.loop.fs_scandir_next(handle)
-- type: "file", "directory", etc.

-- File access check
local ok = vim.loop.fs_access(path, "R")  -- "R", "W", "X"

-- Get cwd
local cwd = vim.loop.cwd()

-- System info
local hostname = vim.loop.os_gethostname()
local cpu_info = vim.loop.cpu_info()
local mem = vim.loop.get_total_memory()
```

### HTTP Requests - No Built-in Support

MCPHub **does NOT provide built-in HTTP helpers**. For HTTP requests, use:

**Option 1: vim.fn.jobstart with curl**
```lua
handler = function(req, res)
  local url = req.params.url
  local output = ""

  vim.fn.jobstart({ "curl", "-s", url }, {
    on_stdout = function(_, data)
      if data then output = output .. table.concat(data, "\n") end
    end,
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        res:text(output):send()
      else
        res:error("HTTP request failed"):send()
      end
    end,
  })
end
```

**Option 2: plenary.curl (if available)**
```lua
local curl = require("plenary.curl")

handler = function(req, res)
  curl.get(req.params.url, {
    callback = vim.schedule_wrap(function(result)
      if result.status == 200 then
        res:text(result.body):send()
      else
        res:error("HTTP error"):send()
      end
    end),
  })
end
```

---

## Handler Timeout

**Default Timeout**: 5 seconds (defined in `lua/mcphub/native/utils/server.lua:60`)

Sync handlers block until response sent. Async handlers can exceed timeout if they properly use callbacks.

---

## Complete Working Example

```lua
local mcphub = require("mcphub")

mcphub.add_server("myserver", {
  displayName = "My Custom Server",
  capabilities = {},
})

-- Simple tool
mcphub.add_tool("myserver", {
  name = "greet",
  description = "Greet someone",
  inputSchema = {
    type = "object",
    properties = {
      name = { type = "string" },
    },
    required = { "name" },
  },
  handler = function(req, res)
    res:text("Hello " .. req.params.name):send()
  end,
})

-- Dynamic resource
mcphub.add_resource_template("myserver", {
  uriTemplate = "buffer://{num}",
  handler = function(req, res)
    local bufnr = tonumber(req.params.num)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    res:text(table.concat(lines, "\n")):send()
  end,
})

-- Async tool
mcphub.add_tool("myserver", {
  name = "async_task",
  handler = function(req, res)
    vim.fn.jobstart({ "bash", "-c", "sleep 2 && echo Done" }, {
      on_exit = function(_, code)
        res:text("Completed with code " .. code):send()
      end,
    })
  end,
})
```

---

## Key Source Files

| File | Purpose |
|------|---------|
| `lua/mcphub/native/init.lua` | Main API |
| `lua/mcphub/native/utils/server.lua` | Server/request handler logic |
| `lua/mcphub/native/utils/request.lua` | Request object classes |
| `lua/mcphub/native/utils/response.lua` | Response object classes |
| `lua/mcphub/native/neovim/terminal.lua` | vim.fn.jobstart examples |

---

## Last Updated

April 4, 2026 - Based on MCPHub v6.2.0 source

