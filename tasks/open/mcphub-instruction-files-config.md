---
title: "Add instruction files for AI agents in MCPHub config"
status: open
priority: medium
created: 2026-07-10
updated: 2026-07-10
refs: []
related:
  - [MCPHub Memory Doc](docs/memory/mcphub.md)
  - "MCPHub config: ~/dotfiles/ai/mcp/mcphub.json"
  - [myAi.lua Config](lua/plugins/extra/myAi.lua)
  - [prompt.lua (upstream)](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/prompt.lua)
  - [config_manager.lua (upstream)](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/config_manager.lua)
---

## Objective

Add instruction file references to MCPHub server configs so that per-server instructions can live in external markdown files instead of inline JSON text. This makes large instructions maintainable, diffable, and shareable across agents connecting via the `/mcp` endpoint.

## Research

### AI agent instruction file ecosystem

#### Claude Code
- **Project-level**: `./CLAUDE.md` or `./.claude/CLAUDE.md` — native per-repo instructions. CLAUDE.md is the official filename; Claude Code does **not** read AGENTS.md natively as of 2026-07. [Source](https://code.claude.com/docs/en/memory.md)
- **Global-level**: `~/.claude/CLAUDE.md` — user-wide instructions applied to all projects. [Source](https://code.claude.com/docs/en/memory.md)
- **Rules**: Supports topic-specific files scoped to file types or subdirectories via project rules.
- Claude Code reads CLAUDE.md, not AGENTS.md. A feature request to support AGENTS.md natively exists but is open. [Source](https://github.com/anthropics/claude-code/issues/34235)

#### Cursor
- **Project-level**: `.cursor/rules/*.mdc` — rules with YAML frontmatter for scoping (globs, activation mode: Always/Auto/Manual). [Source](https://cursor.com/docs/rules)
- **Legacy**: `.cursorrules` — single file at repo root, deprecated but still works.
- **Global-level**: User rules managed via Cursor UI (`.cursor/rules/` in user profile dir).
- **AGENTS.md**: Cursor now supports plain-markdown `AGENTS.md` as a supported alternative if you don't want frontmatter.
- **MCP config**: `~/.cursor/mcp.json` (user) and `./.cursor/mcp.json` (project).

#### OpenAI Codex CLI
- **Global-level**: `~/.codex/AGENTS.md` or `~/.codex/AGENTS.override.md` — user-wide instructions. AGENTS.override.md takes precedence over AGENTS.md at this level. [Source](https://developers.openai.com/codex/guides/agents-md)
- **Project-level**: `AGENTS.md` at project root, discovered by walking up from CWD to Git root. `AGENTS.override.md` takes precedence per-directory. [Source](https://developers.openai.com/codex/guides/agents-md)
- **Merge order**: Codex concatenates files from root down, joining with blank lines. Files closer to CWD override because they appear later. Combined size capped at `project_doc_max_bytes` (32 KiB default). [Source](https://developers.openai.com/codex/guides/agents-md)
- **Fallback filenames**: Configurable via `project_doc_fallback_filenames` in `~/.codex/config.toml`. [Source](https://developers.openai.com/codex/guides/agents-md)

#### OpenCode
- **Project-level**: `AGENTS.md` at project root, discovered by traversing up from CWD. [Source](https://opencode.ai/docs/rules/)
- **Global-level**: `~/.config/opencode/AGENTS.md` — user-wide instructions. [Source](https://opencode.ai/docs/rules/)
- **Claude Code compatibility**: Supports `CLAUDE.md` (project) and `~/.claude/CLAUDE.md` (global) as fallbacks, plus `~/.claude/skills/`. Can be disabled via `OPENCODE_DISABLE_CLAUDE_CODE=1`. [Source](https://opencode.ai/docs/rules/)
- **Precedence**: `AGENTS.md` > `CLAUDE.md` locally; `~/.config/opencode/AGENTS.md` > `~/.claude/CLAUDE.md` globally.
- **Custom instructions**: `instructions` field in `opencode.json` supports file paths (with glob patterns) and remote URLs. [Source](https://opencode.ai/docs/rules/)

#### Crush (Charmbracelet)
- **Config**: `crush.json` (project) and `~/.config/crush/crush.json` (global). [Source](https://github.com/charmbracelet/crush)
- **Context files**: Crush reads multiple context files at project root including: `.github/copilot-instructions.md`, `.cursorrules`, `.cursor/rules/`, `CLAUDE.md`, `CLAUDE.local.md`, `GEMINI.md`, `crush.md`, `crush.local.md`, `AGENTS.md`. All matching files are combined. [Source](https://charmbracelet-crush.mintlify.app/guides/context-files)
- **Custom context paths**: Configurable via `options.context_paths` in `crush.json`. [Source](https://charmbracelet-crush.mintlify.app/guides/context-files)

#### Gemini CLI
- **Project-level**: `GEMINI.md` (default) at project root. Configurable filename in `settings.json`. [Source](https://geminicli.com/docs/cli/gemini-md/)
- **Global-level**: `~/.gemini/settings.json` — user-wide settings. [Source](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/settings.md)

#### AGENTS.md (Cross-tool standard)
- AGENTS.md is an open format stewarded by the Agentic AI Foundation (Linux Foundation), used by 60k+ open-source projects. [Source](https://agents.md)
- Emerged collaboratively from OpenAI Codex, Cursor, Amp, Jules (Google), and Factory.
- Supports nested AGENTS.md in subprojects — agents read the nearest file in the directory tree.

### MCPHub `custom_instructions` implementation

#### Config schema (mcphub.json)

Each server in `mcphub.json` supports a `custom_instructions` object:

```json
"custom_instructions": {
  "disabled": false,
  "text": "When using GitLab tools: - Always check MR status before approving"
}
```

[Source](https://ravitemer.github.io/mcphub.nvim/mcp/servers_json.html)

#### Prompt generation flow

1. **Entry**: `hub:get_active_servers_prompt()` calls `prompt_utils.get_active_servers_prompt(servers)` — [`prompt.lua:~L232`](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/prompt.lua)
2. **Per-server**: `server_to_text(server)` is called for each connected server — [`prompt.lua:server_to_text()`](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/prompt.lua)
3. **Custom instructions injection**: Inside `server_to_text()`, custom instructions are loaded via `M.format_custom_instructions(server.name)` — [`prompt.lua`](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/prompt.lua)
4. **Config loading**: `format_custom_instructions()` calls `config_manager.get_server_config(server_name)` which reads from the cached `State.config_files_cache` (loaded from `mcphub.json`) — [`config_manager.lua`](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/config_manager.lua)
5. **Rendering**: Instructions are added after the server description but before the tools/resources sections in the prompt text.

#### Prompt helpers

`hub:generate_prompts()` returns a table with:
- `prompts.active_servers` — Lists active servers
- `prompts.use_mcp_tool` — Instructions for tool usage with example
- `prompts.access_mcp_resource` — Instructions for resource access with example

`hub:get_active_servers_prompt()` returns the full server list as prompt text. [Source](https://ravitemer.github.io/mcphub.nvim/other/api.html)

#### Token estimates

The token-count behavior now grouped into `patches/mcphub.nvim/03-main-ui_v1.patch` shows approximate token counts on connected server rows. Server counts estimate `mcphub.utils.prompt.server_to_text(server)` after applying `disabled_tools`, `removed_tools`, and env regex tool filters.

### Current gap

MCPHub's `custom_instructions.text` is inline text in the JSON config. There is no support for referencing external instruction files. Each agent has its own instruction files (CLAUDE.md, AGENTS.md, GEMINI.md, etc.) that are independent of MCPHub. These agent files guide general coding behavior, while MCPHub's `custom_instructions` guide how to use specific MCP server tools.

The gap creates problems for:

1. **Large instructions** — servers like `gitlab_mr`, `gitlab_upload`, `slack_official_bridge` have multi-paragraph instructions crammed into JSON strings
2. **Cross-agent sharing** — instruction files like `~/.agents/docs/mcphub/gitlab-instructions.md` cannot be referenced
3. **Maintainability** — editing JSON-escaped newlines is error-prone; no syntax highlighting, no git-friendly diffs
4. **Token management** — hard to estimate or cap instruction file sizes inline

### Relationship between server-level and agent-level instructions

| Layer | Scope | Purpose |
|-------|-------|---------|
| Agent AGENTS.md/CLAUDE.md | Global or project-wide | General coding behavior, repo conventions, build/test commands |
| MCPHub custom_instructions | Per-MCP-server | How to use a specific server's tools, channel IDs, test URLs, etc. |
| MCPHub instruction_files (proposed) | Per-MCP-server | Larger instruction docs for complex servers, shared across agents |

These layers are complementary. Agent-level files guide general coding; MCPHub instructions guide tool usage. The proposed `instruction_files` would allow MCPHub to bridge the gap for complex servers that need extensive documentation.

### Our current instruction files

| File | Purpose |
|------|---------|
| `~/dotfiles/ai/agents/AGENTS.md` | Shared AI instructions (global, all tools) |
| `~/.claude/settings.json` | Claude Code settings |
| `~/.codex/AGENTS.md` | Codex global instructions |
| `~/.config/opencode/agents/` | OpenCode agents |
| `~/.cursor/rules/shared.mdc` | Cursor shared rules |
| `~/.pi/agent/AGENTS.md` | pi global instructions |
| `~/dotfiles/.config/nvim3_jelly_tinynvim/AGENTS.md` | Neovim config instructions |
| `~/dotfiles/AGENTS.md` | Dotfiles repo instructions |

### Research gaps

1. **Exact line numbers in prompt.lua** — The installed v6.2.0 may differ from latest `main`. Compare with local install at `~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/lua/mcphub/utils/prompt.lua`.
2. **mcp-hub backend `custom_instructions` handling** — Whether the mcp-hub fork at `~/projects/mcp-hub` passes `custom_instructions` through the `/mcp` endpoint for external agents was not fully investigated.
3. **Token budget impact** — The exact token cost of loading additional instruction files was not quantified. A practical test with `hub:get_active_servers_prompt()` would be needed.
4. **File watching** — Whether mcp-hub's config file watcher would detect changes to referenced instruction files (not just `servers.json`) is unknown. A separate watcher or hash-based cache invalidation would likely be needed.

## Implementation Plan

### Phase 1: Extend mcphub.json schema for instruction files

Add a `files` array to `custom_instructions` that references external markdown files:

```json
"custom_instructions": {
  "disabled": false,
  "text": "Inline fallback or brief summary",
  "files": [
    "~/.agents/docs/mcphub/gitlab-instructions.md",
    "./docs/server-conventions.md"
  ]
}
```

### Phase 2: Patch prompt.lua to load instruction files

Modify `format_custom_instructions()` in `prompt.lua` to:

1. Check for `server_config.custom_instructions.files` array
2. For each path: expand `~` with `vim.fn.expand()`, resolve relative paths against config file directory
3. Read file contents, concatenate with blank line separators
4. Merge order: inline `text` first, then files appended after
5. Apply byte cap (configurable, default 8 KiB per server) with truncation warning
6. Cache file contents; invalidate on config change
7. Silently skip missing files with a warning log

### Phase 3: Patch validation.lua

Add schema validation for the new `files` array in `custom_instructions`.

### Phase 4: Update token_counts patch

The local [grouped main UI patch](patches/mcphub.nvim/03-main-ui_v1.patch) estimates token counts for `server_to_text()`. Update it to include file content sizes.

### Phase 5: Migrate existing large instructions

For servers with large inline `custom_instructions.text`, extract to `.md` files under `~/.agents/docs/mcphub/` and reference via `files`:

- `gitlab_mr` — extract to `~/.agents/docs/mcphub/gitlab_mr-instructions.md`
- `gitlab_upload` — extract to `~/.agents/docs/mcphub/gitlab_upload-instructions.md`
- `gitlab_mr_o` — extract to `~/.agents/docs/mcphub/gitlab_mr_o-instructions.md`
- `slack` servers — extract to `~/.agents/docs/mcphub/slack-instructions.md`
- `atlassian` — extract to `~/.agents/docs/mcphub/atlassian-instructions.md`

### Phase 6: Check mcp-hub backend support

Verify whether the mcp-hub fork at `~/projects/mcp-hub` passes `custom_instructions` through the `/mcp` endpoint for external agents (Claude Code, Codex, etc.). If not, the instruction files would only apply to Neovim-connected clients.

## Success Criteria

- `custom_instructions.files` array is recognized in `mcphub.json`
- File contents are loaded and appended to server prompts
- Token counts include file content sizes
- Existing inline instructions continue to work (backward compatible)
- Missing files are logged but don't crash prompt generation

## Verification

### How to verify

Restart Neovim, open MCPHub, check that servers with `files` references load without errors.

### Commands

```bash
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

```vim
:MCPHub
" Check a server with instruction files - should show expanded token count
:lua print(vim.inspect(require("mcphub").state:get("server_state")))
```

### Checklist

- [ ] Servers with `custom_instructions.files` load without errors
- [ ] Token counts on server rows reflect file content size
- [ ] `hub:get_active_servers_prompt()` includes file contents
- [ ] Missing files produce warning logs but don't crash
- [ ] Servers without `files` continue to work with inline `text` only

## References

- [AGENTS.md official site](https://agents.md) — Cross-tool standard
- [Claude Code Memory docs](https://code.claude.com/docs/en/memory.md) — CLAUDE.md spec
- [OpenAI Codex AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md)
- [MCPHub Config File docs](https://ravitemer.github.io/mcphub.nvim/mcp/servers_json.html)
- Research brief: `/tmp/mcphub-research-1.md` — full research output from this session
- [MCPHub prompt.lua source](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/prompt.lua)
- [MCPHub config_manager.lua source](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/config_manager.lua)
