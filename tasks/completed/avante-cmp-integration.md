---
status: done
date: 2026-01-29
updated: 2026-10-05
priority: medium
category: ai-integration
---

# Avante + Blink.cmp MCP Integration

## Summary
Implemented full completion integration for Avante.nvim using blink.cmp with `blink-cmp-avante` plugin. This enables MCP prompts, tools, and resources as completions in Avante chat.

The sections below describe the original integration. The 2026-10-05 follow-up
at the end records the current config-only implementation and user acceptance;
the old `blink-cmp-avante` wiring is not the active completion provider.

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

## 2026-10-05 follow-up: lean MCP discovery and inline mentions

Status: done for this follow-up. The user confirmed "implementation seems to work
now" and requested committing related changes and logging completion on 2026-10-05.
This task was already in `completed/`, so its record is updated in place.

### Delivered

- [x] Default MCP context contains bounded discovery plus the existing approval-aware
      dispatchers, not all connected server/tool schemas.
- [x] `/server` inserts `@{server}`; `/server:tool` inserts `@{server:tool}`.
      Explicit references select only relevant schemas and combine without duplicates.
- [x] Completion replaces only the current slash token and preserves surrounding
      text, other lines, earlier mentions and cursor placement. No placeholder,
      extra instructions, auto-submit or tool execution is added.
- [x] MCP items bypass Avante's delayed whole-buffer completion cleanup.
      The optional picker uses an anchored edit; other commands delegate unchanged.
- [x] Existing custom tools, system instructions, MCP prompts and lazy startup remain intact.
- [x] User accepted the implementation, including the reported prompt replacement fix.

### Verification and evidence

Run from the main repository root, using the isolated worktree data namespace:

```sh
NVIM_APPNAME=nvimwt3a nvim --clean --headless -i NONE --cmd 'set rtp^=.' -l tests/test_avante_mcphub.lua
NVIM_APPNAME=nvimwt3a nvim --clean --headless -i NONE --cmd 'set rtp^=.' -l tests/test_avante_mcp_completion.lua
NVIM_APPNAME=nvimwt3a NVIM_MCP_TEST_PLUGIN_ROOT="$HOME/.local/share/nvim3_jelly_tinynvim/lazy" nvim --clean --headless -i NONE --cmd 'set rtp^=.' -l tests/test_avante_mcp_completion.lua
```

- 104 helper assertions and 56 inline-completion assertions passed (160 total).
- Completion regressions passed against both profiles' installed Avante/Blink
  revisions with real completion sources and Blink's text-edit engine.
- Coverage includes sequential/mixed/duplicate mentions, multiline and UTF-8 text,
  cursor positioning, immediate typing, stale entries, picker edits/cancellation,
  manual slash arguments and unchanged non-MCP command callbacks.
- Earlier attached-hub checks validated filtered catalogs and schema selection;
  they did not send a model request or execute an MCP tool.
- The last attached-hub retry was unavailable because port 37373 had no listener.
  No server was started/restarted or reconfigured by these checks.
- Provider-specific live model/tool round-trips and the broader integration
  checklist remain separate regression checks, not claims established by this sign-off.

### Current implementation

- [Avante config](lua/plugins/extra/myAi.lua)
- [Blink provider wiring](lua/plugins/extra/myEditor.lua)
- [Lean discovery and selected schemas](lua/utils/avante_mcphub.lua)
- [Inline completion adapter](lua/utils/avante_mcp_completion.lua)
- [Helper tests](tests/test_avante_mcphub.lua)
- [Inline completion tests](tests/test_avante_mcp_completion.lua)
- [Read-only attached-hub check](tests/test_avante_mcphub_live.lua)
- [Behavior and limitations](docs/memory/mcphub-nvim-integrations.md)
- [Broader MCPHub integration checks](tasks/review/mcphub_integration.md)

Installed plugin refs at verification: Avante `90a0e77`, blink.compat `2ed6d9a`,
blink.cmp `78336bc` (1.10.2). No plugin patch or version upgrade is required.
