# MCPHub.nvim - Memory & Patterns

## Overview

MCPHub.nvim is an MCP (Model Context Protocol) client for Neovim that bridges AI chat plugins with external MCP servers.

- **GitHub**: https://github.com/ravitemer/mcphub.nvim
- **Documentation**: https://ravitemer.github.io/mcphub.nvim/

## Key Concepts

### Architecture
- **Bundled Binary**: Uses bundled Node.js (`bundled_build.lua`), no global install needed
- **Dual-layer Design**: Lua plugin + Node.js `mcp-hub` service
- **Port**: Default 37373 for internal MCPHub communication
- **Unified MCP Endpoint**: `http://localhost:37373/mcp` exposes all servers to other MCP clients

### Server Types
| Type | Transport | Example |
|------|-----------|---------|
| Streamable-HTTP | Primary remote | Modern MCP servers |
| SSE | HTTP Server-Sent Events | gitlab, calculon |
| stdio | Local process | glean, playwright |

## Command Reference

### Only One Command: `:MCPHub`

MCPHub provides **only one command** - `:MCPHub` which opens the UI. All functionality is accessed through the UI interface.

```vim
:MCPHub              " Open/toggle MCPHub UI (the ONLY command)
```

### UI Navigation Keys (Inside MCPHub Window)

| Key | Action | Description |
|-----|--------|-------------|
| `H` | Switch view | Go to Home/Main view |
| `M` | Switch view | Go to Marketplace |
| `C` | Switch view | Go to Config view |
| `L` | Switch view | Go to Logs view |
| `?` | Switch view | Go to Help view |
| `q` | Close | Close MCPHub window |
| `r` | Refresh | Refresh server capabilities |
| `R` | Restart | Restart mcp-hub process |

### Main View Keys (Server Management)

| Key | Action | Description |
|-----|--------|-------------|
| `l` / `<CR>` / `o` | Expand | Expand server to see tools/resources |
| `h` / `<Esc>` | Collapse | Collapse expanded server |
| `t` | Toggle | Enable/disable server |
| `a` | Auto-approve | Toggle auto-approve for server/tool |
| `ga` | Global auto-approve | Toggle `vim.g.mcphub_auto_approve` |
| `A` | Add server | Add new MCP server |
| `e` | Edit | Edit server configuration |
| `d` | Delete | Delete server (or kill workspace) |
| `gd` | Preview | Show system prompts preview |
| `gc` | Change directory | Change to workspace directory |

### Help View Keys

| Key | Action |
|-----|--------|
| `<Tab>` | Next tab |
| `<S-Tab>` | Previous tab |

Tabs: Welcome, Troubleshooting, Native Servers, Changelog

---

## Integration with AI Chat Plugins

### CodeCompanion Integration (Best Support)

**Setup in codecompanion.nvim**:
```lua
require("codecompanion").setup({
  extensions = {
    mcphub = {
      callback = "mcphub.extensions.codecompanion",
      opts = {
        make_tools = true,              -- @{server__tool} syntax
        show_server_tools_in_chat = true,
        make_vars = true,               -- #{mcp:resource} syntax
        make_slash_commands = true,     -- /mcp:prompt_name
        show_result_in_chat = true,
      }
    }
  }
})
```

**Usage Syntax**:
```
@{mcp}                    -- Universal: All MCP tools via use_mcp_tool
@{gitlab}                 -- Server group: All tools from gitlab server
@{gitlab__get_issue}      -- Individual tool: Specific tool
@{neovim__read_file}      -- Builtin neovim server tool
#{mcp:neovim://buffer}    -- Resource as variable
/mcp:code_review          -- MCP prompt as slash command
```

### Avante Integration

**Setup in avante.nvim**:
```lua
require("avante").setup({
  -- Dynamic system prompt with MCP server info
  system_prompt = function()
    local hub = require("mcphub").get_hub_instance()
    return hub and hub:get_active_servers_prompt() or ""
  end,
  -- Add MCP tools
  custom_tools = function()
    return {
      require("mcphub.extensions.avante").mcp_tool(),
    }
  end,
  -- Disable builtin tools if using MCP neovim server
  disabled_tools = {
    "list_files", "read_file", "create_file", -- etc
  },
})
```

**MCPHub config for Avante**:
```lua
require("mcphub").setup({
  extensions = {
    avante = {
      make_slash_commands = true,  -- /mcp:prompt_name
    }
  }
})
```

### CopilotChat Integration

**Setup in mcphub.nvim**:
```lua
require("mcphub").setup({
  extensions = {
    copilotchat = {
      enabled = true,
      convert_tools_to_functions = true,      -- @server__tool syntax
      convert_resources_to_functions = true,  -- @server__resource
      add_mcp_prefix = false,
    }
  }
})
```

**Usage**: Type `@` in CopilotChat to see available MCP functions.

---

## Builtin Native Servers

MCPHub includes two native servers that run directly in Neovim:

### `@neovim` Server
- **File operations**: read_file, write_file, edit_file, list_files, search_files
- **Terminal access**: bash command execution
- **LSP integration**: diagnostics, code actions
- **Buffer management**: current buffer content

### `@mcphub` Server
- **Server management**: start/stop servers, list capabilities
- **Documentation access**: plugin docs and changelog

---

## Auto-Approval System

### Priority Order
1. **Function**: Custom `auto_approve` function (if provided)
2. **Server-specific**: `autoApprove` field in servers.json
3. **Default**: Show confirmation dialog

### Configuration Examples

**Global auto-approve**:
```lua
require("mcphub").setup({
  auto_approve = true,  -- Sets vim.g.mcphub_auto_approve
})
```

**Function-based**:
```lua
require("mcphub").setup({
  auto_approve = function(params)
    -- params.server_name, params.tool_name, params.arguments
    -- params.action ("use_mcp_tool" or "access_mcp_resource")
    -- params.is_auto_approved_in_server

    -- Auto-approve read operations in current project
    if params.tool_name == "read_file" then
      local path = params.arguments.path or ""
      if path:match("^" .. vim.fn.getcwd()) then
        return true
      end
    end
    return false  -- Show confirmation
  end,
})
```

**Per-server in servers.json**:
```json
{
  "mcpServers": {
    "trusted-server": {
      "command": "npx",
      "args": ["trusted-mcp-server"],
      "autoApprove": true
    },
    "partially-trusted": {
      "command": "npx",
      "args": ["some-server"],
      "autoApprove": ["read_file", "list_files"]
    }
  }
}
```

---

## Workspace Configuration

MCPHub supports project-local configurations:

```lua
require("mcphub").setup({
  workspace = {
    enabled = true,
    look_for = { ".mcphub/servers.json", ".vscode/mcp.json", ".cursor/mcp.json" },
    reload_on_dir_changed = true,
    port_range = { min = 40000, max = 41000 },
  }
})
```

Project configs **override** global settings while preserving global servers.

---

## Common Issues & Solutions

### Issue: MCPHub not connecting to servers
**Symptoms**: Servers show as disconnected in UI
**Solution**:
```bash
# MCPHub manages its own mcp-hub process
# Check if it's running via the UI (L for logs)
# Or restart with R key in UI
```

### Issue: Environment variables not loaded
**Symptoms**: Servers requiring tokens fail to start
**Solution**:
```lua
-- Use global_env in setup
require("mcphub").setup({
  global_env = {
    "GITLAB_TOKEN",           -- Array style: uses os.getenv
    CUSTOM_VAR = "value",     -- Hash style: explicit value
  }
})
```

### Issue: Config file not found
**Symptoms**: MCPHub starts with no servers
**Solution**:
```lua
-- Use absolute path with expand
config = vim.fn.expand("~/dotfiles/claude/mcp-proxy/mcphub.json")
```

### Issue: Tool calls not working in CodeCompanion
**Symptoms**: `@{mcp}` doesn't list tools
**Solution**: Ensure CodeCompanion extension is properly configured:
```lua
-- In codecompanion.setup(), NOT in mcphub.setup()
extensions = {
  mcphub = {
    callback = "mcphub.extensions.codecompanion",
    opts = { make_tools = true, make_vars = true, make_slash_commands = true }
  }
}
```

---

## File Locations

| Purpose | Path |
|---------|------|
| Plugin Config | `lua/plugins/extra/myAi.lua` (MCPHub section) |
| Server Config | `~/dotfiles/claude/mcp-proxy/mcphub.json` |
| Management Script | `~/dotfiles/claude/mcp-proxy/start-mcphub.sh` |
| Logs | `~/dotfiles/claude/mcp-proxy/mcphub.log` |

---

## Performance Tips

1. **Lazy load MCPHub** - Use `cmd = "MCPHub"` for lazy loading
2. **Use SSE/Streamable-HTTP** - More efficient than stdio for remote servers
3. **Let LLM manage servers** - `auto_toggle_mcp_servers = true` starts servers on demand
4. **Shutdown delay** - `shutdown_delay = 5 * 60 * 1000` keeps hub running between sessions

---

## Security Notes

- Never commit tokens to mcphub.json
- Use `${ENV_VAR}` syntax for secrets in config
- Start with `auto_approve = false`
- Review tool calls before approving
- Use per-tool auto-approval for trusted operations only

---

## Key Clarification: MCPHub is a Router

### What MCPHub Does
- **Orchestration**: Manages multiple MCP servers
- **Routing**: Routes tool calls to appropriate server
- **UI**: Dashboard for configuration and testing
- **Authentication**: OAuth (PKCE), headers, API keys

### What MCPHub Does NOT Do
- Browser automation (delegated to Playwright MCP)
- File operations (delegated to builtin neovim server or filesystem MCP)
- External API calls (delegated to fetch MCP)

### Access Pattern
```
CodeCompanion/Avante/CopilotChat
         ↓
      MCPHub (Router)
         ↓
   ┌─────┼─────┐
   ↓     ↓     ↓
gitlab  glean  playwright
(SSE)  (stdio)  (stdio)
```

---

## References

- [MCPHub Documentation](https://ravitemer.github.io/mcphub.nvim/)
- [Configuration Guide](https://ravitemer.github.io/mcphub.nvim/configuration)
- [CodeCompanion Extension](https://ravitemer.github.io/mcphub.nvim/extensions/codecompanion)
- [Avante Extension](https://ravitemer.github.io/mcphub.nvim/extensions/avante)
- [CopilotChat Extension](https://ravitemer.github.io/mcphub.nvim/extensions/copilotchat)
- [Native Servers Guide](https://ravitemer.github.io/mcphub.nvim/mcp/native/index)
