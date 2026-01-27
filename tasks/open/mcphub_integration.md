# MCPHub Integration with AI Agents

## Metadata
- **Created**: 2025-01-27
- **Status**: open
- **Priority**: medium
- **Tags**: ai, mcp, codecompanion, avante, copilot

## Summary

Integrate MCPHub.nvim with existing AI agents (CodeCompanion, Avante, CopilotChat) to enable MCP tool access directly from Neovim.

## Current State

### MCPHub Setup
- **Config Location**: `~/dotfiles/claude/mcp-proxy/mcphub.json`
- **14 MCP Servers** configured (12 ready, 2 need tokens)
- **MCPHub Port**: 37373 (internal mcp-hub process)
- **Management**: `~/dotfiles/claude/mcp-proxy/start-mcphub.sh` (optional, MCPHub manages its own process)

### Current AI Plugins
| Plugin | Status | Provider | File |
|--------|--------|----------|------|
| CodeCompanion | Primary | Copilot | [lua/plugins/extra/codecompanion.lua](lua/plugins/extra/codecompanion.lua) |
| Avante | Enabled | Copilot | [lua/plugins/extra/avante.lua](lua/plugins/extra/avante.lua) |
| CopilotChat | Enabled | Copilot | [lua/plugins/extra/copilot-chat.lua](lua/plugins/extra/copilot-chat.lua) |
| MCPHub | Basic | N/A | [lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua) |

### Current MCPHub Config (Basic)
```lua
-- lua/plugins/extra/myAi.lua (MCPHub section)
{
    "ravitemer/mcphub.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "MCPHub",
    build = "bundled_build.lua",
    opts = {
        use_bundled_binary = true,
        config = vim.fn.expand "~/dotfiles/claude/mcp-proxy/mcphub.json",
        port = 37373,
    }
}
```

---

## Implementation Plan

### Phase 1: Update MCPHub Configuration
- [x] **1.1** Update MCPHub config in `myAi.lua` to use existing `~/dotfiles/claude/mcp-proxy/mcphub.json`
- [x] **1.2** Add extension configurations for all AI plugins
- [x] **1.3** Configure auto_approve settings (start with false for security)
- [x] **1.4** Add keymaps for MCPHub commands

### Phase 2: CodeCompanion Integration (Primary)
- [x] **2.1** Add MCPHub as dependency in codecompanion.lua
- [ ] **2.2** Add MCPHub extension config in codecompanion.lua (see Important Note below)
- [ ] **2.3** Test tool invocation with calculon, gitlab, glean

### Phase 3: Avante Integration
- [x] **3.1** Add MCPHub as dependency in avante.lua (commented out - optional)
- [ ] **3.2** Add system_prompt and custom_tools config in avante.lua
- [ ] **3.3** Test MCP tool usage in Avante chat

### Phase 4: CopilotChat Integration
- [x] **4.1** Add MCPHub as dependency in copilot-chat.lua (native MCP support)
- [ ] **4.2** Add copilotchat extension config in mcphub setup
- [ ] **4.3** Test integration with MCP servers

### Phase 5: Documentation & Polish
- [x] **5.1** Add memory doc at `docs/memory/mcphub.md`
- [x] **5.2** Update keymaps documentation
- [x] **5.3** Create quick reference for MCP commands

---

## Important: How Integration Actually Works

### MCPHub Only Has ONE Command

```vim
:MCPHub              " The ONLY command - opens/toggles the UI
```

All other functionality is accessed via:
1. **UI Keymaps** (inside MCPHub window)
2. **Chat Plugin Integration** (via extensions)

### CodeCompanion Integration (Requires Config in BOTH Places)

**1. In mcphub.setup() - already done:**
```lua
-- This enables MCPHub to provide tools to CodeCompanion
extensions = {
  avante = { make_slash_commands = true },
  -- Note: codecompanion extension is configured IN codecompanion.setup()
}
```

**2. In codecompanion.setup() - NEEDS TO BE ADDED:**
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

### Avante Integration (Requires Config in BOTH Places)

**1. In mcphub.setup():**
```lua
extensions = {
  avante = { make_slash_commands = true },
}
```

**2. In avante.setup():**
```lua
require("avante").setup({
  system_prompt = function()
    local hub = require("mcphub").get_hub_instance()
    return hub and hub:get_active_servers_prompt() or ""
  end,
  custom_tools = function()
    return { require("mcphub.extensions.avante").mcp_tool() }
  end,
})
```

### CopilotChat Integration (Config in mcphub.setup())

```lua
require("mcphub").setup({
  extensions = {
    copilotchat = {
      enabled = true,
      convert_tools_to_functions = true,
      convert_resources_to_functions = true,
    }
  }
})
```

---

## MCPHub UI Keymaps Reference

### Global Navigation (All Views)
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

### Main View (Server Management)
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

### Help View
| Key | Action |
|-----|--------|
| `<Tab>` | Next tab (Welcome, Troubleshooting, Native Servers, Changelog) |
| `<S-Tab>` | Previous tab |

---

## MCP Tool Usage in Chat Plugins

### CodeCompanion (when extension configured)
```
@{mcp}                    -- Universal: All MCP tools via use_mcp_tool
@{gitlab}                 -- Server group: All tools from gitlab server
@{gitlab__get_issue}      -- Individual tool: Specific tool
@{neovim__read_file}      -- Builtin neovim server tool
#{mcp:neovim://buffer}    -- Resource as variable
/mcp:code_review          -- MCP prompt as slash command
```

### Avante (when custom_tools configured)
```
/mcp:server_name:prompt_name    -- MCP prompt as slash command
```
Avante uses `use_mcp_tool` and `access_mcp_resource` internally.

### CopilotChat (when extension configured)
```
@server__tool              -- Type @ to see available MCP functions
#server__resource          -- Access resources
```

---

## MCP Servers Available

| Server | Type | Status | Use Case |
|--------|------|--------|----------|
| calculon-mcp | SSE | Ready | A/B experiment data |
| gitlab | SSE | Ready | GitLab operations |
| glean | stdio | Ready | Enterprise search |
| sourcegraph | SSE | Ready | Code search |
| atlassian-agoda | SSE | Ready | Jira/Confluence |
| devportal | SSE | Ready | Developer Portal |
| grafana | SSE | Ready | Monitoring metrics |
| drone | SSE | Ready | CI/CD pipelines |
| figma | SSE | Ready | Design system |
| superset | SSE | Ready | Analytics |
| playwright | stdio | Ready | Browser automation |
| playwright-mobile | stdio | Ready | Mobile testing |
| devstack | SSE | Needs Token | DevStack integration |
| mmb | stdio | Needs Token | MMB development |

### Builtin Native Servers (Always Available)
| Server | Tools |
|--------|-------|
| `@neovim` | read_file, write_file, edit_file, list_files, search_files, bash, diagnostics |
| `@mcphub` | server management, documentation access |

---

## Testing Checklist

### MCPHub Basic
- [ ] `:MCPHub` opens UI
- [ ] Press `H` to go to main view, servers are listed
- [ ] Press `l` on a server to expand tools/resources
- [ ] Press `t` to toggle server on/off
- [ ] Press `L` to view logs

### CodeCompanion + MCP
- [ ] Type `@{mcp}` in chat - should list tools
- [ ] Type `@{neovim}` - should show neovim server tools
- [ ] Type `/mcp:` - should show slash commands from MCP prompts
- [ ] Tool results appear in chat

### Avante + MCP
- [ ] `/mcp:` slash commands available
- [ ] Tool execution works via use_mcp_tool

### CopilotChat + MCP
- [ ] Type `@` to see MCP functions
- [ ] Tool calls work

---

## References

- [MCPHub.nvim GitHub](https://github.com/ravitemer/mcphub.nvim)
- [MCPHub Documentation](https://ravitemer.github.io/mcphub.nvim/)
- [CodeCompanion Extension Docs](https://ravitemer.github.io/mcphub.nvim/extensions/codecompanion)
- [Avante Extension Docs](https://ravitemer.github.io/mcphub.nvim/extensions/avante)
- [CopilotChat Extension Docs](https://ravitemer.github.io/mcphub.nvim/extensions/copilotchat)
- [Configuration Guide](https://ravitemer.github.io/mcphub.nvim/configuration)
- [Memory Doc](docs/memory/mcphub.md)

---

## Notes

- MCPHub uses bundled binary, no global Node.js needed
- Port 37373 is the default MCPHub port (not 5555/3000 - those are standalone MCPHUB server)
- Start with `auto_approve = false` for security
- MCPHub manages its own mcp-hub process, no need to start externally
- Extension configs go in DIFFERENT places depending on the plugin
- The `:MCPHub` command is the ONLY command - everything else is in the UI
