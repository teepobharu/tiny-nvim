# CodeCompanion + MCPHub Integration: MCP Server Discovery Issue

**Problem**: CodeCompanion logs "MCP server `slack` is not configured" when a markdown prompt frontmatter specifies `mcp_servers: [slack]`, even though the slack server is already authenticated and running in MCPHub.

---

## Root Cause Analysis

### The Core Issue

**CodeCompanion maintains its own internal MCP server registry (`config.mcp.servers`) that is COMPLETELY SEPARATE from MCPHub's server management.**

When you write `mcp_servers: [slack]` in a markdown prompt frontmatter, CodeCompanion:
1. Parses the frontmatter (✅ works correctly)
2. Calls `helpers.start_mcp_servers(chat, {"slack"})`
3. Looks up "slack" in **CodeCompanion's own config** (`config.mcp.servers`)
4. If not found there, it logs a warning and skips it

---

## Code Path: From Frontmatter to Warning

### 1. **Frontmatter Parsing** (`lua/codecompanion/actions/markdown.lua:67`)
```lua
mcp_servers = frontmatter.mcp_servers,  -- Extract from YAML frontmatter
```
- Uses TreeSitter YAML parser to extract `mcp_servers: [slack]` from markdown frontmatter
- Successfully creates a table of server names

### 2. **Chat Initialization** (`lua/codecompanion/interactions/chat/init.lua:606-607`)
```lua
elseif args.mcp_servers then
  helpers.start_mcp_servers(self, args.mcp_servers)  -- Call with ["slack"]
```
- Called during chat buffer setup when frontmatter is provided

### 3. **MCP Server Starting** (`lua/codecompanion/interactions/chat/helpers/init.lua:111-136`)
```lua
function M.start_mcp_servers(chat, server_names)
  local mcp = require("codecompanion.mcp")
  
  for _, name in ipairs(server_names) do
    local status = mcp.get_status()
    local server_status = status[name]
    
    if server_status and server_status.ready and server_status.tool_count > 0 then
      add_tools(name)  -- Server found, add tools
    else
      mcp.enable_server(name, {  -- Try to enable if not ready
        on_tools_loaded = function()
          add_tools(name)
        end,
      })
    end
  end
end
```

### 4. **The Warning** (`lua/codecompanion/mcp/init.lua:145-166`)
```lua
function M.enable_server(name, opts)
  opts = opts or {}
  
  local mcp_cfg = config.mcp
  local server_cfg = mcp_cfg.servers[name]  -- ⚠️ LOOKS IN CONFIG.MCP.SERVERS
  if not server_cfg then
    log:warn("MCP server `%s` is not configured", name)  -- LINE 151 - THE WARNING
    return false, string.format("MCP server not found: %s", name)
  end
  
  if not clients[name] then
    clients[name] = Client.new({ name = name, cfg = server_cfg })
  end
  
  if opts.on_tools_loaded then
    table.insert(clients[name].on_tools_loaded, opts.on_tools_loaded)
  end
  
  clients[name]:start()
  
  return true, true
end
```

**Line 151** is where the warning is logged: "MCP server `slack` is not configured"

---

## What "Configured" Means in CodeCompanion

In CodeCompanion's MCP system:
- **"Configured"** = present in `config.mcp.servers` table
- This is **CodeCompanion's internal config**, NOT MCPHub's config
- Default value: `config.mcp.servers = {}` (empty table, see `lua/codecompanion/config.lua:922`)

---

## The Missing Link: CodeCompanion ↔ MCPHub

### How MCPHub Integrates with CodeCompanion

MCPHub has an **extension for CodeCompanion** at:
```
~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/lua/mcphub/extensions/codecompanion/
```

Structure:
- **`init.lua`** — Extension setup entry point
- **`core.lua`** — MCP tool execution logic  
- **`tools.lua`** — Creates dynamic tool groups from MCPHub servers
- **`slash_commands.lua`** — Creates slash commands from MCP prompts
- **`variables.lua`** — Creates variables from MCP resources

### Current Integration Gap

The MCPHub extension **creates tools and variables** but **DOES NOT register servers in CodeCompanion's config.mcp.servers** registry.

This means:
- ✅ MCPHub tools show up in chat (as `@mcp`, `@server`, `@server__tool`)
- ✅ MCPHub resources show up as variables (as `#{mcp:resource}`)
- ✅ MCPHub prompts show up as slash commands (as `/mcp:prompt`)
- ❌ MCPHub servers are NOT available to CodeCompanion's `config.mcp.servers` registry
- ❌ Therefore, `mcp_servers: [slack]` in frontmatter **fails to find the server**

---

## How to Fix: Register MCPHub Servers in CodeCompanion Config

### Solution: Extend MCPHub's CodeCompanion Extension

Modify the MCPHub extension setup in `myAi.lua` to register MCPHub-managed servers into CodeCompanion's config after MCPHub initializes:

```lua
-- In lua/plugins/extra/myAi.lua (around line 555-569 where mcphub extension is configured)
extensions = {
  mcphub = {
    callback = "mcphub.extensions.codecompanion",
    opts = {
      make_tools = true,
      show_server_tools_in_chat = true,
      add_mcp_prefix_to_tool_names = false,
      make_vars = true,
      make_slash_commands = true,
      show_result_in_chat = true,
    },
  },
},
```

Add a setup hook after MCPHub loads to bridge the gap:

```lua
-- Create a post-setup hook to register MCPHub servers in CodeCompanion config
config_on_cc_setup = function()
  local ok, mcphub = pcall(require, "mcphub")
  if not ok then
    return  -- MCPHub not loaded yet
  end
  
  local cc_config = require("codecompanion.config")
  local hub = mcphub.get_hub_instance()
  
  if not hub then
    return  -- Hub not ready
  end
  
  -- Get MCPHub's configured servers
  local servers = hub:get_configured_servers()
  
  -- For each MCPHub server, create a stub entry in CodeCompanion's config
  for server_name, server_info in pairs(servers) do
    if not cc_config.mcp.servers[server_name] then
      cc_config.mcp.servers[server_name] = {
        cmd = {"mcphub-stub"},  -- Dummy command, actual execution via MCPHub
        opts = {
          mcphub_managed = true,
          server_name = server_name,
        },
      }
    end
  end
end
```

Then call this hook in the CodeCompanion setup callback:

```lua
config = function(_, options)
  require("codecompanion").setup(options)
  
  -- Register MCPHub servers in CodeCompanion config
  require("utils.my_codecompanion_mcphub_bridge").setup()
  
  -- ... rest of setup
end
```

---

## Current Behavior: Why It Partially Works

### What Works (via MCPHub Extension)
- `@mcp` — Always available (generic tool to call any MCPHub tool)
- `@slack` — Works if MCPHub extension creates it as a tool group
- `@slack__get_channels` — Works if MCPHub extension creates individual tools
- `#{mcp:slack_channel}` — Works if MCPHub creates resource variables
- `/mcp:create_reminder` — Works if MCPHub creates slash commands from prompts

### What Fails (via CodeCompanion's Native MCP Registry)
- `mcp_servers: [slack]` in frontmatter → Warning, server not added
- `/mcp` slash command (if enabled) → Can't toggle slack server
- `M.default_servers` auto-start → Doesn't include MCPHub servers

---

## Key Files & Line Numbers

| File | Lines | Purpose |
|------|-------|---------|
| `lua/codecompanion/mcp/init.lua` | 145-166 | `enable_server()` — **Where warning is logged (line 151)** |
| `lua/codecompanion/mcp/init.lua` | 214-231 | `get_status()` — Returns status from `config.mcp.servers` |
| `lua/codecompanion/interactions/chat/helpers/init.lua` | 111-136 | `start_mcp_servers()` — Entry point for frontmatter `mcp_servers` |
| `lua/codecompanion/interactions/chat/init.lua` | 606-607 | Chat init — Calls `start_mcp_servers()` with frontmatter servers |
| `lua/codecompanion/actions/markdown.lua` | 67 | Frontmatter parsing — Extracts `mcp_servers` from YAML |
| `lua/codecompanion/config.lua` | 921-928 | Default MCP config — `servers = {}` (always empty) |
| `lua/mcphub/extensions/codecompanion/init.lua` | 1-39 | MCPHub extension entry — **No server registry bridge** |

---

## Workaround: Use Generic MCPHub Tool

Until the bridge is implemented, use the always-available generic MCPHub tool:

Instead of relying on `mcp_servers: [slack]` in frontmatter, use:

```markdown
---
interaction: chat
name: My Prompt
mcp_servers: none  # Disable CodeCompanion's native MCP loading
---

## system
You can call MCP tools using the @{mcp} tool. Available: slack, github, etc.

## user
@{mcp} Call the slack get_channels tool and list all channels.
```

Or directly reference the tool if MCPHub extension created it:
```markdown
@{slack__get_channels}
```

---

## Summary

| Aspect | Detail |
|--------|--------|
| **Warning Line** | `lua/codecompanion/mcp/init.lua:151` |
| **Check That Fails** | `local server_cfg = mcp_cfg.servers[name]` (line 149) |
| **What "Configured" Means** | Present in `config.mcp.servers` (CodeCompanion's own registry) |
| **Why It Fails** | MCPHub servers are NOT registered in `config.mcp.servers` |
| **Root Cause** | MCPHub extension creates tools but doesn't bridge the server registry |
| **Fix Required** | Post-load hook to copy MCPHub server metadata into `config.mcp.servers` |
| **Workaround** | Use `@{mcp}` generic tool or `mcp_servers: none` + direct tool refs |

---

**Last Updated**: 2026-04-03
