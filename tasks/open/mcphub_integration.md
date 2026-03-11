# MCPHub Integration with AI Agents

## Metadata

- **Created**: 2025-01-27
- **Updated**: 2025-01-29
- **Status**: open
- **Priority**: medium
- **Tags**: ai, mcp, codecompanion, avante, copilot

## Summary

Integrate MCPHub.nvim with Neovim AI agents and make the global MCP port available to CLI tools.

## Documentation

- [Main MCPHub Guide](docs/memory/mcphub.md) - Architecture, port persistence, CLI integration
- [Neovim Integrations](docs/memory/mcphub-nvim-integrations.md) - CodeCompanion, Avante, CopilotChat

---

## Current State

### Config Location

All MCPHub and CodeCompanion MCP extension config consolidated in: [lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua)

### MCPHub Setup

- **Config**: `~/dotfiles/ai/mcp/mcphub.json`
- **Port**: 37373 (fixed, workspace mode should be disabled)
- **14 MCP Servers** configured (12 ready, 2 need tokens)

### Port Persistence Model

```
mcphub.nvim starts mcp-hub → port 37373 available
Multiple nvim instances share same port
CLI agents (Claude, OpenCode, etc.) connect to same port
All clients disconnect → shutdown_delay timer
Timer expires → mcp-hub stops
```

**Key:** CLI agents work as long as mcp-hub is running (started by Neovim or standalone).

---

## Investigation Results (2025-01-29)

### Issue: Port 5555 not reachable, wrong port being used

**Symptoms:**
- MCPHub UI showed two hubs: `tharutaipree` (port 40927) and `mcp-proxy` (port 5555)
- Port 5555 not responding to curl
- Port 37373 not being used despite config

**Root Cause:**
- **Workspace mode** was enabled (default), creating per-directory hubs
- Dynamic port assignment from `port_range` (40000-41000) overrode configured port
- Stale hub entry for port 5555 (process already dead, just UI artifact)

**Fix Required:**
Add `workspace = { enabled = false }` to mcphub opts in myAi.lua:

```lua
opts = {
  port = 37373,
  workspace = {
    enabled = false,  -- Disable per-directory hubs for consistent CLI access
  },
  -- ...
}
```

**Verification after nvim restart:**
```bash
curl http://localhost:37373/health
```

### Port Collision Behavior

mcphub.nvim handles port conflicts gracefully:

| Port Status | Action |
|-------------|--------|
| Free | Starts new mcp-hub |
| Used by mcp-hub (same version) | Connects to existing (multi-instance) |
| Used by mcp-hub (different version) | Restarts hub |
| Used by other service | Error: "Port in use by non-MCP Hub server" |

**For CLI agents:** If mcp-hub isn't running, they get connection refused. Start Neovim first or run mcp-hub standalone.

### Server Customization Options (2025-01-29)

**Investigated:** How to customize tools, resources, and instructions per MCP server.

**MCPHub-specific config fields:**
```json
{
  "disabled": false,
  "disabled_tools": ["tool-name"],
  "disabled_resources": ["resource-name"],
  "autoApprove": true | ["tool1", "tool2"],
  "custom_instructions": {
    "disabled": false,
    "text": "Instructions for this server"
  }
}
```

**Key Findings:**
- **Custom instructions**: No default. Set via UI (persists to config) or directly in `mcphub.json`
- **UI persistence**: Yes - changes made in `:MCPHub` UI write back to config file
- **External agents**: Receive custom instructions via system prompt (`get_active_servers_prompt()`)
- **LLM control**: `toggle_mcp_server` tool on native `mcphub` server (controlled by `auto_toggle_mcp_servers`)

**Documentation:** See [Server Customization](docs/memory/mcphub.md#server-customization) section.

---

## Implementation Plan

### Phase 1: MCPHub Core Setup ✅

- [x] **1.1** Add config myAi.lua
- [x] **1.2** Point to `~/dotfiles/ai/mcp/mcphub.json`
- [x] **1.3** Add `<leader>ah` keymap for `:MCPHub`
- [x] **1.4** Disable workspace mode for consistent port (37373)

### Phase 2: CodeCompanion Integration ✅

- [x] **2.1** Add config myAi.lua
- [x] **2.2** Add MCPHub extension config
- [ ] **2.3** Test `@{mcp}`, `@{server}`, `@{server__tool}` syntax
- [ ] **2.4** Test `#{mcp:resource}` variables
- [ ] **2.5** Test `/mcp:prompt_name` slash commands

### Phase 3: Avante Integration

- [x] **3.1** Enable avante extension in mcphub.setup()
- [ ] **3.2** Add `system_prompt` function in [avante.lua](lua/plugins/extra/avante.lua)
- [ ] **3.3** Add `custom_tools` function
- [ ] **3.4** Test MCP tool usage

### Phase 4: CopilotChat Integration ✅

- [x] **4.1** Enable copilotchat extension in mcphub.setup()
- [ ] **4.2** Test `@server__tool` functions

### Phase 5: CLI Agent Integration

- [x] **5.1** Document CLI agent configs in [mcphub.md](docs/memory/mcphub.md)
- [ ] **5.2** Verify Claude Code can connect to :37373
- [ ] **5.3** Verify OpenCode can connect
- [ ] **5.4** Test persistence when Neovim closes

### Phase 6: Documentation ✅

- [x] **6.1** Create main guide: [docs/memory/mcphub.md](docs/memory/mcphub.md)
- [x] **6.2** Create integration guide: [docs/memory/mcphub-nvim-integrations.md](docs/memory/mcphub-nvim-integrations.md)
- [x] **6.3** Update [MCP-HUB-GUIDE.md](~/dotfiles/ai/mcp/MCP-HUB-GUIDE.md)
- [x] **6.4** Document server customization options

### Phase 7: Server Customization ✅ (Documented)

- [x] **7.1** Investigate custom_instructions persistence
- [x] **7.2** Investigate disabled_tools/resources
- [x] **7.3** Investigate autoApprove options
- [x] **7.4** Document how external agents access configs
- [ ] **7.5** Test custom instructions in UI
- [ ] **7.6** Test autoApprove behavior

---

## MCPHub UI Reference

### Command

```vim
:MCPHub              " Only command - opens UI
```

### Navigation Keys (Inside UI)

| Key | View        |
| --- | ----------- |
| `H` | Home/Main   |
| `M` | Marketplace |
| `C` | Config      |
| `L` | Logs        |
| `?` | Help        |
| `q` | Close       |
| `r` | Refresh     |
| `R` | Restart     |

### Main View Keys

| Key          | Action              |
| ------------ | ------------------- |
| `l` / `<CR>` | Expand server       |
| `h`          | Collapse            |
| `t`          | Toggle on/off       |
| `a`          | Auto-approve        |
| `ga`         | Global auto-approve |

---

## Testing Checklist

### MCPHub Basic

- [ ] `:MCPHub` opens UI
- [ ] Servers listed in main view (`H`)
- [ ] Can expand server with `l`
- [ ] Can toggle server with `t`
- [ ] Logs viewable with `L`

### CodeCompanion + MCP

- [ ] `@{mcp}` lists tools in chat
- [ ] `@{neovim}` shows neovim server tools
- [ ] `@{neovim__read_file}` works
- [ ] `/mcp:` shows slash commands

### CLI Agents

- [ ] `curl http://localhost:37373/health` works
- [ ] Claude Code can use MCP tools
- [ ] mcp-hub persists after Neovim closes (for `shutdown_delay`)

### Server Customization

- [ ] Edit custom instructions in UI
- [ ] Verify instructions persist to config file
- [ ] Test `autoApprove: true` skips confirmation
- [ ] Test `autoApprove: ["tool"]` for specific tools
- [ ] Test `disabled_tools` hides tools from LLMs
- [ ] Test `auto_toggle_mcp_servers` allows LLM to start servers

---

## Notes

- All config consolidated in [myAi.lua](lua/plugins/extra/myAi.lua)
- mcphub.nvim manages its own mcp-hub process (bundled binary)
- Port 37373 is fixed when workspace mode is disabled
- Must disable workspace mode for CLI agents to use consistent port
- `shutdown_delay` keeps mcp-hub running after last client
- For always-on access, run mcp-hub standalone or increase `shutdown_delay`
- Custom instructions persist to config file (UI changes are saved)
- External agents get custom instructions via system prompt injection
- `autoApprove` can be `true`, array of tool names, or omitted
- LLMs can toggle servers via `toggle_mcp_server` tool (controlled by `auto_toggle_mcp_servers`)
