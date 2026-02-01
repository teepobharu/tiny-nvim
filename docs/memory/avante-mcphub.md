# Avante + MCPHub Integration Notes

## Overview
Avante.nvim integrated with MCPHub for MCP tool/resource access and blink.cmp for completion support.

## Configuration Details

### MCPHub Integration
**Location:** `lua/plugins/extra/myAi.lua`

Key settings:
- **Port:** 37373 (fixed for CLI agent access)
- **Workspace mode:** disabled (consistent port per directory)
- **Auto-approve:** false (manual review before tool execution)
- **Auto-toggle servers:** true (automatically start/stop MCP servers)

Extensions:
- `avante.make_slash_commands = true` - Converts MCP prompts to /slash commands

### Avante Configuration
**Location:** `lua/plugins/extra/avante.lua`

Disabled tools (handled by MCPHub neovim server):
```lua
disabled_tools = {
  -- File operations
  "list_files", "search_files", "read_file",
  "create_file", "rename_file", "delete_file",
  "create_dir", "rename_dir", "delete_dir",
  -- Terminal access
  "bash",
}
```

### Blink.cmp Integration
**Location:** `lua/plugins/extra/myAi.lua`

Added provider configuration:
```lua
{
  "saghen/blink.cmp",
  dependencies = { "Kaiser-Yang/blink-cmp-avante" },
  opts = {
    sources = {
      providers = {
        avante = {
          name = "Avante",
          module = "blink-cmp-avante",
        }
      }
    }
  }
}
```

## Usage Patterns

### MCP Prompts (Slash Commands)
```
/mcp:server_name:prompt_name
```
Autocomplete available in Avante chat for discovered MCP prompts.

### MCP Tools
```
@mcp              - All tools
@server           - All tools from a server
@server__tool     - Specific tool
```

### MCP Resources (Variables)
```
#mcp:resource     - Access as variable
```

## Known Issues & Solutions

### Issue: Tool Duplication
**Symptom:** Same file operation or bash command appears twice
**Solution:** Ensure `disabled_tools` in Avante config includes all MCPHub-provided tools
**Status:** ✅ Resolved - disabled_tools configured

### Issue: Port Conflicts
**Symptom:** MCPHub fails to start on port 37373
**Solution:** Check for existing process: `lsof -i :37373`
**Workspace mode:** Must be disabled to maintain fixed port

### Issue: Completion Not Appearing
**Symptom:** No Avante completions in chat
**Solution:** 
1. Verify `Kaiser-Yang/blink-cmp-avante` is installed
2. Check MCPHub server status: `:MCPHub`
3. Ensure Avante is using blink.cmp (not native completion)

## Testing Commands

```vim
" Open Avante chat
:AvanteAsk

" Check MCPHub status
:MCPHub

" Verify blink.cmp is active
:set completeopt
```

## References
- [MCPHub Avante Extension](https://ravitemer.github.io/mcphub.nvim/extensions/avante.html)
- [Tool Conflicts Resolution](https://ravitemer.github.io/mcphub.nvim/extensions/avante.html#tool-conflicts)
- [blink-cmp-avante GitHub](https://github.com/Kaiser-Yang/blink-cmp-avante)
