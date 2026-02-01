---
status: done
date: 2026-01-29
priority: medium
category: ai-integration
---

# Avante + Blink.cmp MCP Integration

## Summary
Implemented full completion integration for Avante.nvim using blink.cmp with `blink-cmp-avante` plugin. This enables MCP prompts, tools, and resources as completions in Avante chat.

## Completed Tasks

### Phase 1: Core Integration Setup ✅
**File:** `lua/plugins/extra/myAi.lua`
- Added `blink-cmp-avante` dependency to blink.cmp configuration
- Configured Avante provider with blink.cmp
- Enables autocomplete for MCP prompts, tools, and resources

### Phase 2: Avante Configuration ✅
**File:** `lua/plugins/extra/avante.lua`
- Uncommented MCPHub dependency `{ "ravitemer/mcphub.nvim", optional = true }`
- Added `disabled_tools` configuration to prevent duplication:
  - File operations: list_files, search_files, read_file, create_file, rename_file, delete_file, create_dir, rename_dir, delete_dir
  - Terminal access: bash
  - All now handled by MCPHub's neovim server tools

### Phase 3: Verification ✅
- Reviewed blink.cmp sources in `lua/plugins/coding.lua`
- Confirmed no conflicts with existing completion sources
- Base sources: ["lsp", "path", "snippets", "buffer"]

## Features Enabled
- MCP prompt autocomplete in Avante chat (`/mcp:*`)
- MCP tool completions (`@server`, `@server__tool`)
- MCP resource completions (`#variable`)
- Fixed port 37373 for consistent CLI agent access
- Auto-toggle MCP servers enabled
- Manual approval workflow (auto_approve=false)

## Testing Checklist
- [ ] MCPHub server starts without errors
- [ ] Avante chat opens successfully  
- [ ] Blink.cmp shows completions in Avante chat
- [ ] MCP prompts appear in completions (`/mcp:*`)
- [ ] MCP tools appear in completions (`@server`)
- [ ] Tool execution shows confirmation dialogs
- [ ] No tool duplication from disabled_tools

## Files Modified
- `lua/plugins/extra/myAi.lua` - Added blink-cmp-avante integration
- `lua/plugins/extra/avante.lua` - Enabled MCPHub + disabled_tools

## References
- [Avante Integration Guide](https://ravitemer.github.io/mcphub.nvim/extensions/avante.html)
- [MCPHub Configuration](https://ravitemer.github.io/mcphub.nvim/configuration.html)
- [Kaiser-Yang/blink-cmp-avante](https://github.com/Kaiser-Yang/blink-cmp-avante)

## Next Steps
- Run tests to verify all features working
- Document any issues in `docs/memory/avante-mcphub.md`
- Consider adding score_offset tuning for completion priority
