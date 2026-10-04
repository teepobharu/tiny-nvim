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

### Configuration in avante.setup() (local lean helper)

```lua
-- lua/plugins/extra/myAi.lua (single canonical Avante spec)
local opts = {
  -- Optional: Disable Avante's builtin tools if using MCP neovim server
  disabled_tools = {
    "list_files", "search_files", "read_file",
    "create_file", "rename_file", "delete_file",
    "bash",
  },
}
local bridge = require("utils.avante_mcphub")
bridge.extend_opts(opts, { aliases = {} })
require("avante").setup(opts)
bridge.install_slash_commands()
```

### Usage

Avante uses two internal tools for MCP:
- `use_mcp_tool` - Execute any MCP tool
- `access_mcp_resource` - Access any MCP resource

The active configuration in `lua/plugins/extra/myAi.lua` now delegates this wiring
to `lua/utils/avante_mcphub.lua`. It merges existing custom tools/system instructions
rather than replacing them. MCPHub's `make_slash_commands` only exposes **prompts**;
registering `mcp_tool()` makes tools available to the model, not to input completion.

The local helper uses **on-demand discovery**, not `get_active_servers_prompt()`:
only `mcphub_list_servers`, `mcphub_list_tools`, `use_mcp_tool`, and
`access_mcp_resource` are registered initially. Existing Avante tools remain intact.
Server discovery returns names/counts. Tool discovery returns concise metadata
(10 per page, maximum 25); `include_schema=true` retrieves full schemas and relevant
server instructions. `tool_name` selects one exact tool. All discovery and selection
use `hub:get_tools()` (connected servers with capability filters applied). Dispatch
rechecks availability and delegates to MCPHub's existing approval-aware tool.

The lean backend at `/mcp-lean` offers the same discovery/dispatch concept, but the
local fork currently uses GET/SSE plus `/messages-lean`, not Streamable HTTP POST at
`/mcp-lean`. The Avante helper reuses its already-connected MCPHub client/public API
rather than adding a second SSE transport or bypassing Neovim's approval UI.

`/server` now inserts `@{server}`: all available tool schemas from that server are
supplied in the system prompt. `/server:tool` inserts `@{server:tool}`: only that
tool's schema is supplied. References can be typed directly; `@{server__tool}` is
also accepted. `/tools:pick:server` preserves the optional one-tool picker.
Selecting any command only fills input; it never calls tools or auto-submits.
MCP completion replaces **only the slash token at the cursor**, preserving text
before/after it, other lines and earlier references. Multiple selections may be
combined in one prompt, e.g. `Compare @{tavily} with @{ag-slack:read_tool}`; their
schemas are combined without duplicates. No extra instruction text or placeholder
is inserted. The cursor lands immediately after the inserted reference.
Actual server names are used by default; set
`aliases = { slack = "<exact-server-name>" }` in `extend_opts` for explicit aliases.
Never guess among similarly named Slack servers.

Unlike CodeCompanion's native selected function tools, Avante keeps generic
dispatchers and supplies selected JSON schemas as reference context. References
apply to the latest user request, not globally or permanently across chat tabs.
A plain follow-up returns to lean discovery. Tool results/previous messages still
remain in chat history; this does not erase context already sent in an old chat.
Plain "use Tavily" does not attach every Tavily schema: the model discovers the
server/tool on demand, gets the required schema, then calls `use_mcp_tool`.
This is context selection, not a security sandbox; a model can discover other
connected tools. Disabled/hidden tools stay unavailable and normal approval applies.

CodeCompanion remains unchanged: `@{server}` registers that server's selected native
function schemas; `@{server__tool}` registers one. These attachments persist in its
chat until removed. Its universal `@{mcp}` is the broad-catalog/dispatcher exception.

Existing slash commands and MCP prompts survive refreshes. Colliding names and
names starting with `mcp` use a `tools:` prefix; MCPHub owns/removes the `mcp*`
namespace during prompt refresh. Sparse command arrays must be compacted before
appending entries, otherwise `ipairs` completion silently misses later commands.
Tool/server/state events coalesce refreshes and never load Avante during hub startup.
Unavailable tools are checked again when selecting a stale completion.

The `avante_commands` blink provider in `lua/plugins/extra/myEditor.lua` wraps
`blink.compat.source` with `lua/utils/avante_mcp_completion.lua`. Our MCP items
use narrow UTF-8 text edits and skip upstream command execution; all other Avante
commands (including existing MCP prompt commands) still delegate unchanged.
This matters because upstream `cmp_avante.commands:execute()` captures the full
input and schedules a global `gsub` rewrite after 100ms. Merely changing our
callback would still allow that cleanup to overwrite newer typing/completions.
The optional picker uses an extmark to replace its one command token after
selection; unrelated edits are retained, and an edited token is not overwritten.
Manual slash submission restores its arguments to Avante's cleared input without
auto-submitting. No Avante/MCPHub plugin patch is needed for this fix.

Tests (from the main repository root):
```sh
NVIM_APPNAME=nvimwt3a nvim --clean --headless --cmd 'set rtp^=.' -l tests/test_avante_mcphub.lua
NVIM_APPNAME=nvimwt3a nvim --clean --headless -i NONE --cmd 'set rtp^=.' -l tests/test_avante_mcp_completion.lua
NVIM_APPNAME=nvimwt3a MCP_HUB_SERVER_URL=http://127.0.0.1:37373 nvim --clean --headless -i NONE --cmd 'set rtp^=.' -l tests/test_avante_mcphub_live.lua
```
The first test uses mocked catalogs. The second uses a synthetic input/catalog
with real installed Avante completion, blink.compat and Blink's text-edit engine.
It covers sequential/mixed/duplicate selections, cursor positioning, multiline
and UTF-8 text, delayed-typing safety, stale entries, picker edit/cancel behavior,
manual slash arguments and unchanged non-MCP command delegation.
The third attaches to an existing hub and reads catalog metadata only; none of
these checks executes an MCP tool or sends a model request.
Set `NVIM_MCP_TEST_PLUGIN_ROOT` to test another profile's installed plugin revisions
while keeping the clean worktree data namespace. Hub readiness can precede the
server capability snapshot, so the live check waits for the test server's tools.

Validation (2026-10-04): 104 isolated assertions passed. Attached checks passed
with both worktree and main installed plugins, using the clean worktree namespace,
with 418 filtered tools. Initial MCP prompt: 1,028 bytes versus
577,602 bytes for the old full-catalog prompt; one selected Tavily tool: 3,031 bytes.
These measure only the MCP prompt portion, not total Avante context/tokens.
Earlier approval-aware metadata execution passed on 2026-10-03. No hub settings,
plugin patches, lockfile or blink version changed for the lean refactor.
Inline-completion regression checks (56 assertions) also passed with both worktree and main
installed plugin revisions in the clean worktree namespace. A fresh attached-hub
check during the inline fix could not run: no server was listening on port 37373;
the fix did not start/restart a hub or change its settings.

User sign-off (2026-10-05): the implementation now works in the user's session,
including the prompt-preservation fix. Logged in
[the completed Avante task](tasks/completed/avante-cmp-integration.md).
The optional live-provider regression checks below remain useful; this sign-off
does not establish every model/tool combination.

User verification after restarting the Neovim client (no hub restart needed):
- [ ] In a **new** Avante chat, submit `use tavily search openai news`: expect discovery,
      schema retrieval and the normal MCPHub confirmation before execution.
- [ ] `/tavily` fills a compact server reference; `/tavily:<actual-tool-name>` selects
      one tool; `/tools:pick:tavily` opens the explicit picker. Completion never submits.
- [ ] Write text before/after the cursor, complete `/tavily`, then add a second
      `/server:tool` reference. Both references and all original text should remain;
      typing immediately after acceptance should not disappear after a delay.
- [ ] A subsequent request without a reference returns to discovery-only MCP context;
      switching chat tabs/new chats does not carry an implicit selected server.
- [ ] Existing `/mcp:server:prompt` commands/resources still work. Check a full model
      round-trip with the preferred provider; no model response was verified for this refactor.

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
| Universal MCP (`@{mcp}`) | ✅ broad catalog | On-demand discovery + dispatcher, no broad catalog | ❌ |
| Server groups (`@{server}`) | ✅ native functions | ✅ selected schema context (local helper) | ❌ |
| Individual tools | ✅ `@{s__t}` native function | ✅ `@{s:t}` schema context (local helper) | ✅ `@s__t` |
| Custom tool groups | ✅ | ❌ | ❌ |
| Resource variables | ✅ `#{mcp:}` | ✅ (via tool) | ✅ `#s__r` |
| Slash commands | ✅ `/mcp:` | ✅ `/mcp:s:p` | ❌ |
| Rich media | ✅ | ❓ | ❓ |
| Config location | codecompanion.setup | Both | mcphub.setup |

### Recommendation

- **CodeCompanion**: Best choice - most flexible, best tool discovery
- **Avante**: Lean discovery by default; explicit references add only relevant schemas, with the existing approval-aware dispatcher
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
