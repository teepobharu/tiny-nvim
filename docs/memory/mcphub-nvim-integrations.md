# MCPHub - Neovim Chat Plugin Integrations

This document covers integrating MCPHub with Neovim chat plugins.

**Related:** [Main MCPHub Guide](mcphub.md) for architecture and CLI agent setup.

---

## Integration Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Neovim Chat Plugins                         │
├───────────────────┬───────────────────┬─────────────────────────┤
│   CodeCompanion   │      Avante       │      CopilotChat        │
│   (Best Support)  │   (Good Support)  │   (Basic Support)       │
└─────────┬─────────┴─────────┬─────────┴───────────┬─────────────┘
          │                   │                     │
          └───────────────────┴─────────────────────┘
                              │
                    mcphub.extensions.*
                              │
                              ▼
          ┌───────────────────────────────────────────┐
          │              mcphub.nvim                   │
          │  • Manages mcp-hub process                 │
          │  • Routes tool/resource calls              │
          │  • Provides system prompts                 │
          └───────────────────┬───────────────────────┘
                              │
               http://localhost:37373/mcp
                              │
                              ▼
          ┌───────────────────────────────────────────┐
          │               mcp-hub                      │
          │         (MCP Server Router)                │
          └───────────────────────────────────────────┘
```

---

## CodeCompanion Integration (Best Support)

CodeCompanion has the most comprehensive MCP integration.

### Configuration Location

**In `codecompanion.setup()`** - NOT in mcphub.setup():

```lua
-- lua/plugins/extra/codecompanion.lua
require("codecompanion").setup({
  extensions = {
    mcphub = {
      callback = "mcphub.extensions.codecompanion",
      opts = {
        -- Tools
        make_tools = true,                    -- Enable @{server__tool} syntax
        show_server_tools_in_chat = true,     -- Show in completion
        add_mcp_prefix_to_tool_names = false, -- Don't add mcp__ prefix
        show_result_in_chat = true,           -- Show results in buffer

        -- Resources
        make_vars = true,                     -- Enable #{mcp:resource} syntax

        -- Prompts
        make_slash_commands = true,           -- Enable /mcp:prompt_name
      }
    }
  }
})
```

### Tool Access Patterns

| Syntax | Description | Example |
|--------|-------------|---------|
| `@{mcp}` | Universal (all servers) | `@{mcp} What files exist?` |
| `@{server}` | Server group | `@{gitlab} List my issues` |
| `@{server__tool}` | Individual tool | `@{neovim__read_file} Show config` |
| `#{mcp:uri}` | Resource variable | `#{mcp:neovim://buffer}` |
| `/mcp:name` | Prompt slash command | `/mcp:code_review` |

### Usage Examples

```markdown
# Use universal MCP access (adds all servers to system prompt)
@{mcp} What MCP servers are available?

# Use server group (all GitLab tools)
@{gitlab} List my open merge requests

# Use specific tool
@{neovim__read_file} Show lua/plugins/extra/myAi.lua

# Use resource as context
#{mcp:neovim://diagnostics/buffer} Fix these issues

# Use MCP prompt
/mcp:code_review
```

### Custom Tool Groups

Define workflows combining MCP tools:

```lua
require("codecompanion").setup({
  strategies = {
    chat = {
      tools = {
        groups = {
          ["github_workflow"] = {
            description = "GitHub PR workflow",
            tools = {
              "neovim__read_file",
              "neovim__write_file",
              "github__list_issues",
              "github__create_pull_request",
            },
          },
        },
      },
    },
  },
  extensions = {
    mcphub = {
      callback = "mcphub.extensions.codecompanion",
      opts = { make_tools = true },
    }
  }
})
```

Use with: `@{github_workflow} Fix issue #123 and create a PR`

### `@{mcp_lean}` group

This config also adds a dedicated CodeCompanion group named `@{mcp_lean}`.

It mirrors the MCPHub lean proxy surface rather than exposing the full `/mcp`
tool catalog directly. The group is intended for lower-context discovery and
routing:

- `mcphub_list_servers` — list connected servers with tool counts
- `mcphub_list_tools` — inspect tools for a specific server
- `mcphub_call_tool` — execute one selected tool on a chosen server

Typical flow:

1. `@{mcp_lean}` list available servers
2. call `mcphub_list_tools` for the target server
3. call `mcphub_call_tool` with the exact server + tool name

This is different from:
- `@{mcp}` — generic MCP bridge tools with full server prompt injection
- `@{server}` — full direct server group created from connected MCP servers
- `@{server__tool}` — one concrete direct tool

---

## Avante Integration

Avante requires configuration in **both** mcphub.setup() and avante.setup().

### Configuration in mcphub.setup()

```lua
-- lua/plugins/extra/myAi.lua (MCPHub section)
require("mcphub").setup({
  extensions = {
    avante = {
      make_slash_commands = true,  -- Enable /mcp:server:prompt_name
    }
  }
})
```

### Configuration in avante.setup()

```lua
-- lua/plugins/extra/avante.lua
require("avante").setup({
  -- Dynamic system prompt with MCP server info
  system_prompt = function()
    local hub = require("mcphub").get_hub_instance()
    return hub and hub:get_active_servers_prompt() or ""
  end,

  -- Add MCP tools (use_mcp_tool and access_mcp_resource)
  custom_tools = function()
    return {
      require("mcphub.extensions.avante").mcp_tool(),
    }
  end,

  -- Optional: Disable Avante's builtin tools if using MCP neovim server
  disabled_tools = {
    "list_files", "search_files", "read_file",
    "create_file", "rename_file", "delete_file",
    "bash",
  },
})
```

### Usage

Avante uses two internal tools for MCP:
- `use_mcp_tool` - Execute any MCP tool
- `access_mcp_resource` - Access any MCP resource

**Slash commands** (requires blink.cmp):
```
/mcp:gitlab:code_review
/mcp:neovim:summarize_buffer
```

### Tool Conflict Note

Avante has builtin tools (file operations, bash). MCP's neovim server provides similar tools. Choose one:

**Option A:** Use MCP neovim server (disable Avante builtins)
```lua
disabled_tools = { "list_files", "read_file", "bash", ... }
```

**Option B:** Use Avante builtins (disable MCP neovim server)
- Toggle off in MCPHub UI with `t` key on neovim server

---

## CopilotChat Integration

CopilotChat configuration goes in **mcphub.setup()** only.

### Configuration

```lua
-- lua/plugins/extra/myAi.lua (MCPHub section)
require("mcphub").setup({
  extensions = {
    copilotchat = {
      enabled = true,
      convert_tools_to_functions = true,      -- Tools as @functions
      convert_resources_to_functions = true,  -- Resources as @functions
      add_mcp_prefix = false,                 -- Don't add mcp_ prefix
    }
  }
})
```

### Usage

MCP tools appear as CopilotChat functions:

```
@neovim__read_file Show the config file
@gitlab__get_issue Get issue #123
@neovim__Buffer Show current buffer content
```

Type `@` in CopilotChat to see available MCP functions.

---

## Feature Comparison

| Feature | CodeCompanion | Avante | CopilotChat |
|---------|---------------|--------|-------------|
| Universal MCP (`@{mcp}`) | ✅ | ✅ (via tool) | ❌ |
| Server groups (`@{server}`) | ✅ | ❌ | ❌ |
| Individual tools | ✅ `@{s__t}` | ✅ (via tool) | ✅ `@s__t` |
| Custom tool groups | ✅ | ❌ | ❌ |
| Resource variables | ✅ `#{mcp:}` | ✅ (via tool) | ✅ `#s__r` |
| Slash commands | ✅ `/mcp:` | ✅ `/mcp:s:p` | ❌ |
| Rich media | ✅ | ❓ | ❓ |
| Config location | codecompanion.setup | Both | mcphub.setup |

### Recommendation

- **CodeCompanion**: Best choice - most flexible, best tool discovery
- **Avante**: Good choice - dynamic system prompt, simple two-tool approach
- **CopilotChat**: Basic support - function-based access

---

## Builtin Native Servers

MCPHub includes two native servers always available:

### `@neovim` Server

| Tool | Description |
|------|-------------|
| `read_file` | Read file contents |
| `write_file` | Write to file |
| `edit_file` | Edit file with diff preview |
| `list_files` | List directory contents |
| `search_files` | Search file contents |
| `bash` | Execute shell commands |
| `diagnostics` | Get LSP diagnostics |

### `@mcphub` Server

| Tool | Description |
|------|-------------|
| Server management | Start/stop/toggle servers |
| Documentation | Access plugin docs |

---

## Current Configuration

### myAi.lua (MCPHub + CodeCompanion extension)

```lua
-- lua/plugins/extra/myAi.lua
return {
  -- MCPHub.nvim
  {
    "ravitemer/mcphub.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "MCPHub",
    build = "bundled_build.lua",
    opts = {
      use_bundled_binary = true,
      config = vim.fn.expand("~/dotfiles/ai/mcp/mcphub.json"),
      port = 37373,
      auto_approve = false,
      auto_toggle_mcp_servers = true,
      extensions = {
        avante = { make_slash_commands = true },
        -- copilotchat = { enabled = true, ... },  -- uncomment to enable
      },
    },
    keys = {
      { "<leader>ah", "<cmd>MCPHub<cr>", desc = "MCPHub" },
    },
  },

  -- CodeCompanion extension (add to codecompanion.lua instead)
  {
    "olimorris/codecompanion.nvim",
    extensions = {
      mcphub = {
        callback = "mcphub.extensions.codecompanion",
        opts = {
          make_tools = true,
          show_server_tools_in_chat = true,
          make_vars = true,
          make_slash_commands = true,
        },
      },
    },
  },
}
```

---

## Troubleshooting

### CodeCompanion: `@{mcp}` not showing tools

1. Verify mcphub.nvim is loaded: `:MCPHub`
2. Check extension is configured in `codecompanion.setup()`:
   ```lua
   extensions = {
     mcphub = {
       callback = "mcphub.extensions.codecompanion",
       opts = { make_tools = true }
     }
   }
   ```
3. Verify servers are running in MCPHub UI

### Avante: MCP tools not working

1. Verify `system_prompt` function is set
2. Verify `custom_tools` function is set
3. Check MCPHub logs (`:MCPHub` → `L`)

### CopilotChat: `@` not showing MCP functions

1. Verify extension enabled in mcphub.setup():
   ```lua
   extensions = {
     copilotchat = { enabled = true, convert_tools_to_functions = true }
   }
   ```
2. Restart CopilotChat after enabling
3. Refresh MCPHub (`:MCPHub` → `R`)

### Resources not accessible

- CodeCompanion: Ensure `make_vars = true`
- CopilotChat: Ensure `convert_resources_to_functions = true`
- Resources are always auto-approved (no toggle needed)

---

## References

- [CodeCompanion Extension](https://ravitemer.github.io/mcphub.nvim/extensions/codecompanion)
- [Avante Extension](https://ravitemer.github.io/mcphub.nvim/extensions/avante)
- [CopilotChat Extension](https://ravitemer.github.io/mcphub.nvim/extensions/copilotchat)
- [Native Servers Guide](https://ravitemer.github.io/mcphub.nvim/mcp/native/index)
- [Configuration Guide](https://ravitemer.github.io/mcphub.nvim/configuration)
