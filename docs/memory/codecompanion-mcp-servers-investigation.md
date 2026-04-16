# CodeCompanion v19.7: MCP Servers in Markdown Prompts — Complete Investigation

## Overview

Very thorough investigation of CodeCompanion v19.7's handling of `mcp_servers` in markdown prompt frontmatter when a prompt is TRIGGERED (selected from action palette).

**Main Finding**: ✅ **NO DISCONNECTS** — `mcp_servers` field successfully flows from YAML frontmatter through action palette, Interactions, and into Chat creation, triggering `start_mcp_servers()` correctly.

---

## Documentation Files

### 1. **codecompanion-mcp_servers-FINDINGS.md** (Start Here!)
- **Purpose**: Executive summary and key findings
- **Length**: 8.5K
- **Content**:
  - Main finding with evidence table
  - 7-stage flow overview
  - Critical conditional logic (lines 603-614)
  - Truth table for `mcp_servers` values
  - Gotchas and solutions
  - Testing steps
  - Conclusion

**Read this first** for a 10-minute overview.

---

### 2. **codecompanion-mcp_servers-flow-analysis.md** (Detailed Technical)
- **Purpose**: Complete detailed analysis with code excerpts
- **Length**: 14K
- **Content**:
  - Stage 1: Markdown parsing (lines 47-75)
  - Stage 2: Action palette caching (lines 13-26, 56-96)
  - Stage 3: User selection & deep copy (lines 124-134)
  - Stage 4: Interactions creation (lines 59-67, 108-192)
  - Stage 5: Chat creation conditional (lines 603-614)
  - Stage 6: MCP server startup (lines 111-136)
  - Helper functions analysis
  - No disconnects proof
  - Potential gotchas (empty arrays, ACP adapters, etc.)

**Read this for** detailed understanding of each stage with code snippets.

---

### 3. **codecompanion-mcp_servers-code-trace.md** (Code Reference)
- **Purpose**: Complete code path with exact line numbers
- **Length**: 13K
- **Content**:
  - Exact code for all 7 stages with line numbers
  - Helper function definitions
  - Critical section (lines 603-614) reproduced
  - Stage 7 server startup code
  - Complete flow summary table (13 rows, all decision points)
  - All critical points highlighted

**Read this for** precise code references and complete flow table.

---

### 4. **codecompanion-mcp_servers-quick-ref.md** (Quick Reference)
- **Purpose**: Quick visual reference and testing guide
- **Length**: 8.1K
- **Content**:
  - Visual ASCII flow diagram
  - Key file & line reference table
  - Markdown frontmatter examples (✅ WORKS / ❌ GOTCHA)
  - Conditional truth table
  - Adapter type gotcha
  - Testing checklist

**Read this for** quick lookups and testing guidance.

---

## Files Analyzed

### Source Files
```
1. lua/codecompanion/actions/markdown.lua         (347 lines)
   - parse_file() : Lines 47-75
   - parse_frontmatter() : Lines 80-140

2. lua/codecompanion/actions/init.lua             (168 lines)
   - insert_prompts() : Lines 13-26
   - Actions.set_items() : Lines 56-96
   - Actions.resolve() : Lines 124-134

3. lua/codecompanion/interactions/init.lua        (333 lines)
   - get_mcp_servers() : Lines 24-29
   - Interactions.new() : Lines 59-67
   - Interactions:chat() : Lines 108-192

4. lua/codecompanion/interactions/chat/init.lua   (1910 lines)
   - Chat.new() : Lines 377-653
   - Critical conditional : Lines 603-614

5. lua/codecompanion/interactions/chat/helpers/init.lua (330 lines)
   - mcp_servers_to_add_to_chat() : Lines 96-105
   - start_mcp_servers() : Lines 111-136
```

---

## Key Code Locations

### Critical Line Numbers

| Component | File | Lines | Key Code |
|-----------|------|-------|----------|
| Extract from YAML | `markdown.lua` | 66 | `mcp_servers = frontmatter.mcp_servers` |
| Cache in palette | `actions/init.lua` | 23 | `table.insert(_cached_actions, prompt)` |
| Deep copy | `actions/init.lua` | 125 | `item = vim.deepcopy(item)` |
| Pass to Interactions | `actions/init.lua` | 131 | `selected = item` |
| Store in Interactions | `interactions/init.lua` | 65 | `selected = args.selected` |
| Extract for chat | `interactions/init.lua` | 155 | `mcp_servers = get_mcp_servers(...)` |
| Check truthiness | `chat/init.lua` | 606 | `elseif args.mcp_servers then` |
| Call startup | `chat/init.lua` | 607 | `helpers.start_mcp_servers(...)` |
| Enable server | `helpers/init.lua` | 129 | `mcp.enable_server(name, ...)` |

---

## The Flow in One Sentence

```
markdown.parse_file(66) → actions/init insert_prompts(23) → 
Actions.resolve(131) → Interactions:chat(155) → 
Chat.new(607) → helpers.start_mcp_servers(129)
```

---

## Key Findings Summary

### ✅ Flow is Complete
1. YAML frontmatter `mcp_servers: [slack]` → extracted as table
2. Action palette caches prompt WITH `mcp_servers` intact
3. User selection deep copies item → passes to Interactions
4. Interactions stores entire item as `self.selected`
5. `Interactions:chat()` extracts `mcp_servers` via simple accessor
6. `Chat.new()` receives as `args.mcp_servers`
7. Conditional at line 606 checks truthiness
8. If truthy → line 607 calls `start_mcp_servers()`
9. Server is enabled and tools added to chat

### ✅ No Fields Lost
- `markdown.lua:66` → Extracts `mcp_servers`
- `actions/init.lua:23` → Inserts prompt with ALL fields
- No stripping, no filtering, no loss of data

### ✅ Conditional Logic Correct
- `if args.mcp_servers == "none"` → Skip MCP (line 604)
- `elseif args.mcp_servers` → Start MCP (line 606-607)
- `else` → Use config defaults (line 608-612)

---

## Test Markdown Prompt

```yaml
---
name: "Test Slack MCP"
interaction: chat
mcp_servers: [slack]
description: "Chat with Slack access"
---

# System
You are a helpful assistant with access to Slack workspace.

# User
List my recent Slack messages.
```

**Expected**: When selected from action palette, Slack MCP server starts and tools are added to chat.

---

## Gotchas to Know

### 1. Empty Array Gotcha
```yaml
mcp_servers: []  # ❌ GOTCHA: This is truthy but loops 0 times
```
**Solution**: Use `mcp_servers: none` instead

### 2. ACP Adapter
Line 603 check: `if self.adapter.type ~= "acp"`
**Impact**: MCP servers skipped for ACP adapters (intentional)

### 3. Already Running
Server status checked at line 123-124
**Impact**: Tools added immediately if server already running

---

## Quick Reference Commands

```lua
-- Check if it's working
:MCPHub  " Check if Slack server is active

-- Check adapter type
:LspInfo  " View adapter information

-- Create test prompt
~/.config/nvim3_jelly_tinynvim/prompts/test-slack.md

-- Test flow
:CodeCompanionActions  " Open action palette
-- Select "Test Slack MCP"
-- Check :MCPHub for active servers
```

---

## Implementation Status

**CodeCompanion v19.7 Implementation**: ✅ **COMPLETE & CORRECT**

No changes needed. The feature works as designed.

---

## For Investigation

This investigation was conducted by:
1. Reading all 5 core source files completely
2. Tracing the exact flow of `mcp_servers` field
3. Analyzing conditional logic at each stage
4. Documenting all line numbers
5. Identifying potential gotchas
6. Creating reproducible test cases

**Scope**: Action palette → chat creation flow (not inline or background interactions)

---

## Document Map

```
codecompanion-mcp_servers-INDEX.md  ← YOU ARE HERE
├── codecompanion-mcp_servers-FINDINGS.md        (Start here - 5 min read)
├── codecompanion-mcp_servers-flow-analysis.md   (Detailed - 10 min read)
├── codecompanion-mcp_servers-code-trace.md      (Reference - lookup table)
└── codecompanion-mcp_servers-quick-ref.md       (Quick guide - testing)
```

**Recommended Reading Order**:
1. This INDEX (2 min) — Understand what you have
2. FINDINGS (5 min) — Get the main insights
3. QUICK-REF (3 min) — See the visual flow
4. FLOW-ANALYSIS (10 min) — Deep dive into each stage
5. CODE-TRACE (reference) — Lookup exact lines

---

## Statistics

| Metric | Value |
|--------|-------|
| Files analyzed | 5 |
| Functions traced | 7 |
| Critical decision points | 13 |
| Lines of documentation | 1,019 |
| Code excerpts included | 50+ |
| Line numbers referenced | 100+ |
| Gotchas identified | 3 |
| Testing steps | 6 |

---

## Related Neovim Config Files

- `~/dotfiles/lua/plugins/extra/myCodeCompanion.lua` — CodeCompanion config
- `~/dotfiles/lua/plugins/extra/myAi.lua` — MCPHub config
- `~/dotfiles/ai/mcp/mcphub.json` — MCP server definitions
- `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/` — Source code

---

## Conclusion

The `mcp_servers` field in markdown prompt frontmatter **is correctly handled throughout the entire flow** from YAML parsing through action palette selection to chat creation and MCP server startup.

**No implementation issues found. Feature works as designed.**

---

**Investigation Date**: 2026-04-03  
**CodeCompanion Version**: v19.7  
**Investigation Scope**: Action palette → chat creation flow  
**Status**: ✅ COMPLETE
