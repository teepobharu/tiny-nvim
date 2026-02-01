# MCPHub Integration Investigation Summary

**Date**: 2026-01-28  
**Task**: Document MCPHub dependencies and integration patterns for CodeCompanion, Avante, and CopilotChat

## Investigation Sources

Three official MCPHub documentation pages were investigated:

1. [Avante Integration](https://ravitemer.github.io/mcphub.nvim/extensions/avante.html)
2. [CodeCompanion Integration](https://ravitemer.github.io/mcphub.nvim/extensions/codecompanion)
3. [CopilotChat Integration](https://ravitemer.github.io/mcphub.nvim/extensions/copilotchat.html)

## Key Findings

### 1. Configuration Location Patterns

| Plugin | MCPHub Config | Plugin Config | Notes |
|--------|---------------|---------------|-------|
| **CodeCompanion** | None needed | Extension in codecompanion.setup() | All config in one place |
| **Avante** | Extension options | system_prompt + custom_tools | Split config |
| **CopilotChat** | Extension options | None needed | All config in mcphub.setup() |

### 2. Tool Access Methods

**CodeCompanion** (Most Flexible):
- `@{mcp}` - Universal access (use_mcp_tool wrapper)
- `@{server}` - Server groups (all tools from a server)
- `@{server__tool}` - Individual tools
- Custom tool groups combining MCP + native tools

**Avante** (Simple Two-Tool):
- `use_mcp_tool` - Call any MCP tool
- `access_mcp_resource` - Access any MCP resource
- System prompt injection for server discovery

**CopilotChat** (Function-Based):
- `@server__tool` - Direct function calls
- `@server__resource` - Resources as functions
- `#server__resource` - Resources as variables

### 3. Dependencies Discovered

| Plugin | Hard Dependencies | Soft Dependencies | Notes |
|--------|-------------------|-------------------|-------|
| CodeCompanion | None | - | Extension callback only |
| Avante | None | blink.cmp for slash commands | Kaiser-Yang/blink-cmp-avante |
| CopilotChat | Function-calling support | - | Requires native function feature |

### 4. Auto-Approval Priority Order (Corrected)

The complete priority chain is:

1. **Function** - Custom `auto_approve` function (if provided)
2. **Server-specific** - `autoApprove` in servers.json OR per-tool toggle in UI
3. **Global** - `vim.g.mcphub_auto_approve` (toggled with `ga` in UI)
4. **Default** - Show confirmation dialog

**Key Discovery**: UI toggles (`a` on server/tool, `ga` for global) and servers.json are at same priority level.

### 5. Tool Conflict Management

**Problem**: Multiple sources provide similar tools:
- Avante builtin tools (file ops, bash)
- MCP neovim server tools (file ops, bash, LSP)
- CodeCompanion builtin tools

**Solutions**:
1. Avante: Disable builtin tools when using MCP neovim server
2. CodeCompanion: Use custom tool groups for selective inclusion
3. General: Toggle off MCP neovim server if preferring plugin-native tools

### 6. Resource Handling Differences

| Plugin | Variable Syntax | Function Syntax | Use Case |
|--------|----------------|-----------------|----------|
| CodeCompanion | `#{mcp:resource}` | ❌ | Context injection |
| Avante | Via tool call | Via tool call | Through access_mcp_resource |
| CopilotChat | `#server__resource` | `@server__resource` | Both patterns supported |

### 7. Rich Media Support

**CodeCompanion** explicitly supports rich media (🖼 images, etc.)  
**Avante** and **CopilotChat** - Not documented (❓)

## Documentation Updates Applied

### New Sections Added

1. **Integration Comparison Table** - Feature matrix for all three plugins
2. **When to Use Which** - Decision guide for choosing integration
3. **Tool Conflict Management** - How to handle overlapping functionality
4. **Expanded Auto-Approval** - Complete priority order with UI controls
5. **Integration-Specific Troubleshooting** - Per-plugin common issues

### Enhanced Existing Sections

1. **CodeCompanion Integration**:
   - Added all configuration options with comments
   - Documented universal/server/individual tool access patterns
   - Added custom tool groups example
   - Listed important notes about tool discovery

2. **Avante Integration**:
   - Added dependency notes (blink.cmp requirement)
   - Expanded disabled_tools list with comments
   - Documented dynamic system prompt behavior
   - Added tool conflict explanation

3. **CopilotChat Integration**:
   - Added function-calling dependency requirement
   - Documented resource dual-access (variable + function)
   - Added example workflow
   - Listed organizational benefits

### Auto-Approval Enhancements

- Added UI-based approval management instructions
- Documented function return values (true/false/string/nil)
- Added CodeCompanion auto_tool_mode integration example
- Listed all available function parameters
- Clarified resource auto-approval (always approved)

## Testing Recommendations

### Verification Checklist

- [ ] CodeCompanion `@{mcp}`, `@{server}`, `@{server__tool}` all work
- [ ] Avante calls `use_mcp_tool` and `access_mcp_resource`
- [ ] CopilotChat shows MCP functions on `@` completion
- [ ] Resource access works in each plugin
- [ ] Auto-approval toggles work (UI `a` and `ga` keys)
- [ ] Tool conflicts resolved (no duplicate functionality)
- [ ] Slash commands work (CodeCompanion, Avante with blink.cmp)

### Common Test Scenarios

1. **File Operations**: Read/write files through MCP neovim server
2. **LSP Integration**: Access diagnostics via resources
3. **GitHub Operations**: Test external MCP server tools
4. **Resource Variables**: Inject buffer content into prompts
5. **Auto-Approval**: Verify function-based approval logic

## References

- [MCPHub Main Docs](https://ravitemer.github.io/mcphub.nvim/)
- [Updated Memory Doc](docs/memory/mcphub.md)
- [MCP Hub Guide](mcp-proxy/MCP-HUB-GUIDE.md)

## Next Steps

1. ✅ Documentation updated with investigation findings
2. ⏭️ Test each integration pattern in practice
3. ⏭️ Document any discrepancies between docs and behavior
4. ⏭️ Consider which integration best fits workflow
5. ⏭️ Review tool conflict resolution strategy
