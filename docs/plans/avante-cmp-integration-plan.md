# Avante + Blink.cmp Integration Plan

## Overview
Setup full completion integration for Avante.nvim using blink.cmp with `blink-cmp-avante` plugin. This will enable MCP prompts as completions and provide a seamless AI chat completion experience.

## Current State
- ✅ `blink.cmp` installed and configured in `lua/plugins/coding.lua`
- ✅ `mcphub.nvim` configured in `lua/plugins/extra/myAi.lua`
- ✅ `avante.nvim` configured in `lua/plugins/extra/avante.lua`
- ❌ `blink-cmp-avante` NOT installed
- ❌ Avante completion provider NOT integrated with blink.cmp
- ❌ MCP tool conflicts NOT resolved

## Implementation Steps

### Phase 1: Core Integration Setup
**File:** `lua/plugins/extra/myAi.lua`

1. **Add Avante completion provider to myAi.lua**
   - Create new blink.cmp configuration entry for Avante
   - Add `Kaiser-Yang/blink-cmp-avante` as dependency
   - Configure the provider with proper options

2. **Configure MCP tool conflict resolution**
   - Disable Avante's built-in tools to prevent duplication with MCPHub's neovim server tools
   - Applied in `avante.lua` setup

### Phase 2: Avante Configuration Updates
**File:** `lua/plugins/extra/avante.lua`

1. **Add MCPHub dependency** (currently commented)
   - Uncomment `{ "ravitemer/mcphub.nvim", optional = true }`

2. **Configure disabled_tools** in Avante setup
   - Disable file operations (list_files, search_files, read_file, create_file, rename_file, delete_file, create_dir, rename_dir, delete_dir)
   - Disable bash terminal access
   - Prevents conflicts with MCPHub's neovim server tools

### Phase 3: Blink.cmp Configuration Enhancement
**File:** `lua/plugins/coding.lua`

1. **Review current blink.cmp sources**
   - Currently: `["lsp", "path", "snippets", "buffer"]`
   - Verify no conflicts with Avante completion

### Phase 4: Documentation
- Update `docs/memory/` with integration notes
- Document MCP prompt access patterns (@server, @server__tool)
- Record any issues discovered during testing

## Expected Behavior After Integration

### In Avante Chat
- Completion for MCP prompts: `/mcp:*` (slash commands)
- Completion for tools: `@` prefix (server tools and individual tools)
- Completion for resources: `#` prefix (variables)
- Blink.cmp integration provides autocomplete for these

### MCP Tool Access
- `/mcp:server_name:prompt_name` - MCP prompts as slash commands
- `@mcp`, `@server`, `@server__tool` - MCP tools
- `#mcp:resource` - MCP resources as variables

### Features
- Auto-approval disabled by default (review before execution)
- Auto-toggle MCP servers enabled
- CodeCompanion extension enabled for MCP tools
- CopilotChat extension enabled for tool conversion

## Configuration References

### Key Options in myAi.lua
```lua
-- MCPHub options
port = 37373                          -- Fixed port for CLI agent access
workspace = { enabled = false }       -- Disable workspace mode
auto_approve = false                  -- Manual review before tool execution
auto_toggle_mcp_servers = true        -- Auto start/stop servers

-- Avante extension
extensions = {
  avante = {
    make_slash_commands = true        -- Convert prompts to /slash commands
  }
}
```

### Key Options in avante.lua
```lua
-- Blink.cmp integration
dependencies = {
  "Kaiser-Yang/blink-cmp-avante"
}

-- Disable conflicting tools
disabled_tools = {
  "list_files", "search_files", "read_file",
  "create_file", "rename_file", "delete_file",
  "create_dir", "rename_dir", "delete_dir",
  "bash"
}
```

## Testing Checklist
- [ ] MCPHub starts without errors
- [ ] Avante chat opens successfully
- [ ] Blink.cmp shows completions in Avante chat
- [ ] MCP prompts appear in completions (`/mcp:*`)
- [ ] MCP tools appear in completions (`@server`)
- [ ] Tool execution shows confirmation dialogs (auto_approve=false)
- [ ] No tool duplication (Avante tools disabled)

## Links & Resources
- [Avante Integration Guide](https://ravitemer.github.io/mcphub.nvim/extensions/avante.html)
- [MCPHub Configuration](https://ravitemer.github.io/mcphub.nvim/configuration.html)
- [Blink.cmp Documentation](https://cmp.saghen.dev/)
- [Kaiser-Yang/blink-cmp-avante](https://github.com/Kaiser-Yang/blink-cmp-avante)

## Implementation Status
- [ ] Phase 1: Core Integration (myAi.lua updates)
- [ ] Phase 2: Avante Config (avante.lua updates)
- [ ] Phase 3: Blink.cmp Review (coding.lua verification)
- [ ] Phase 4: Testing & Documentation
