---
title: "Add instruction files for AI agents in MCPHub config"
status: review
priority: medium
created: 2026-07-10
updated: 2026-07-24
refs:
  - 163b3ad [tag:v6.2.0] @2025-07-31 chore(release): v6.2.0
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
2. **mcp-hub backend `custom_instructions` handling** — A read-only audit on 2026-07-19 confirmed that raw `/mcp` and `/mcp-lean` clients do not receive mcphub.nvim `custom_instructions`. The backend creates MCP SDK servers with capabilities only, and no backend `instructions` handling exists under `src/`.
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

## Implementation (2026-07-19)

Implemented the Neovim-side feature as
[`06-instruction-files_v1.patch`](patches/mcphub.nvim/06-instruction-files_v1.patch),
applied after the existing five grouped MCPHub patches against pinned
mcphub.nvim `v6.2.0` (`163b3ad`).

- Adds and validates `custom_instructions.files` plus optional positive-integer
  `max_bytes`. File-backed configs default to 8192 bytes per server; legacy
  inline-only configs remain uncapped unless a limit is explicitly set.
- Expands `~`/environment references and resolves relative paths from the active
  server config's directory.
- Merges inline `text` first, then readable files in declaration order. The
  combined body and separators share the per-server byte budget, so inline text
  has deterministic priority.
- Warns and skips missing/unreadable files without crashing. Warnings are
  deduplicated by server/path plus stable failure signature, while file contents
  are cached by path plus size/mtime/inode.
- Keeps existing server token estimates compatible because the UI estimator
  already calls the enhanced `prompt.server_to_text()` path.
- Fixes the existing inline rendering path so literal percent signs in instruction
  text are not interpreted as `string.format` directives.

Automated coverage lives in
[`test_mcphub_instruction_files.lua`](tests/test_mcphub_instruction_files.lua)
with repository fixtures under
[`tests/fixtures/mcphub-instructions/`](tests/fixtures/mcphub-instructions/).

### Scope boundary / deferred decisions

- No live `~/dotfiles/ai/mcp/mcphub.json` entries or external instruction
  documents were changed. Phase 5 remains an explicit user migration decision.
- This client patch affects `hub:get_active_servers_prompt()` consumers (the
  current CodeCompanion extension plus MCPHub guide/preview output) and MCPHub
  UI token estimates. It does not change the mcp-hub backend or automatically
  inject instructions into raw `/mcp` clients. The read-only backend audit
  confirmed this boundary: `/mcp` and `/mcp-lean` construct capability-only SDK
  servers and expose tools/resources/prompts without initialization
  instructions. Backend parity therefore needs a separate design decision for
  endpoint semantics, file watching/reload behavior, byte caps, reconnects,
  and private-document exposure. The already-dirty backend checkout was left
  untouched.

## Success Criteria

- [x] `custom_instructions.files` is recognized and validated by mcphub.nvim
- [x] File contents are loaded and appended to server prompts in deterministic order
- [x] Token estimates include file content through `server_to_text()`
- [x] Existing inline instructions continue to work, including literal `%` text
- [x] Missing files are logged but do not crash prompt generation
- [ ] Live server configs are migrated to external instruction documents (user decision)
- [ ] Raw external `/mcp` clients receive file instructions (requires backend investigation/change)

## Verification

### How to verify

Use the isolated `nvimwt3a` profile. First verify that its MCPHub checkout is at
the pinned commit, restore only that checkout, and reapply the six sorted local
patches. This targeted command never invokes Lazy and verifies that
`lazy-lock.json` is unchanged. Then run the headless fixture against the patched
checkout. Interactive checks require the user to deliberately add a `files`
entry to a chosen test server config; the implementation does not mutate the
live external config automatically.

### Commands

```bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
plugin_root="$HOME/.local/share/nvimwt3a/lazy/mcphub.nvim"
pinned_commit="163b3ad0caa3987e04e5b1d89bb89d230686d17b"
lock_before="$(git -C "$repo_root" hash-object lazy-lock.json)"

test "$(git -C "$plugin_root" rev-parse HEAD)" = "$pinned_commit"
git -C "$plugin_root" restore -- .
for patch in "$repo_root"/patches/mcphub.nvim/*.patch; do
  git -C "$plugin_root" apply --check --ignore-space-change "$patch"
  git -C "$plugin_root" apply --ignore-space-change "$patch"
done
git -C "$plugin_root" diff --check
test "$(git -C "$repo_root" hash-object lazy-lock.json)" = "$lock_before"
```

```bash
MCPHUB_PLUGIN_ROOT="$HOME/.local/share/nvimwt3a/lazy/mcphub.nvim" \
  NVIM_APPNAME=nvimwt3a \
  nvim --headless -u NONE -i NONE -l tests/test_mcphub_instruction_files.lua
```

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
:MCPHub
" After adding files to a chosen test server, inspect the generated prompt:
:lua print(require("mcphub").get_hub_instance():get_active_servers_prompt(false, false))
```

### Checklist

- [ ] The pinned-checkout command applies all six MCPHub patches without an
      apply error and leaves `lazy-lock.json` unchanged
- [ ] The headless fixture prints `ok - mcphub instruction files (53 assertions)`
- [ ] A test server with inline `text` and two `files` renders inline text first, followed by both files
- [ ] A relative file resolves from the defining config directory even when Neovim's CWD differs
- [ ] A missing file produces a warning while the remaining server prompt still renders
- [ ] Lowering `max_bytes` stays within the byte count, preserves valid UTF-8, and produces a warning
- [ ] A file-only instruction config shows as configured in the expanded section and server-row icon
- [ ] The server row token estimate increases when a non-empty instruction file is enabled
- [ ] A server without `files` continues to render inline `text` only

### Agent verification evidence (2026-07-24)

- [x] Fresh detached worktree at `163b3ad` accepted patches `01 -> 02 -> 03 -> 04 -> 05 -> 06` sequentially
- [x] `git diff --check` passed after the full patch stack
- [x] `luac -p` passed for `prompt.lua`, `renderer.lua`, `validation.lua`, and `types.lua`
- [x] Isolated Neovim headless fixture passed all 53 assertions

## User sign-off

- [ ] Accept the implementation and close this task
- [ ] Keep it open for live config/document migration
- [ ] Keep it open for raw `/mcp` backend support
- [ ] Return it for implementation changes (note the failed checklist item)

## References

- [AGENTS.md official site](https://agents.md) — Cross-tool standard
- [Claude Code Memory docs](https://code.claude.com/docs/en/memory.md) — CLAUDE.md spec
- [OpenAI Codex AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md)
- [MCPHub Config File docs](https://ravitemer.github.io/mcphub.nvim/mcp/servers_json.html)
- Research brief: `/tmp/mcphub-research-1.md` — full research output from this session
- [MCPHub prompt.lua source](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/prompt.lua)
- [MCPHub config_manager.lua source](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/config_manager.lua)
