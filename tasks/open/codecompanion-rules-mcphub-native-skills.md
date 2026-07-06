---
title: "CodeCompanion rules and MCPHub native Agent Skills catalog"
status: open
priority: high
created: 2026-07-06
updated: 2026-07-07
refs:
  - eba3b42f [tag:v19.17.0] @2026-06-21 13:17:38 +0100 chore(main): release 19.17.0 (#3161)
  - 163b3ad [tag:v6.2.0-dirty] @2025-07-31 07:52:38 +0000 chore(release): v6.2.0
related:
  - [CodeCompanion config](lua/plugins/extra/myCodecomp.lua)
  - [MCPHub config](lua/plugins/extra/myAi.lua)
  - [CodeCompanion prompt gotchas](docs/memory/codecompanion-prompt-library-gotchas.md)
  - [MCPHub memory](docs/memory/mcphub.md)
  - [Superseded prompt-library skills task](tasks/open/codecompanion-markdown-prompts-skills.md)
---

## Objective

Implement a robust Agent Skills workflow for CodeCompanion without using
`prompt_library.markdown.dirs` as the skill catalog.

The target design is:

- Use CodeCompanion `rules` only for passive user/project instructions, following
  Codex-style `AGENTS.override.md` precedence where possible.
- Build a smart autoload group that keeps the builtin default rules available
  for manual use, but avoids duplicated symlinked or identical instruction
  files in automatic chat context.
- Use an MCPHub native `skills` server for active, progressive skill discovery:
  list a small skill catalog first, then load full `SKILL.md` content only after
  a skill is explicitly selected.
- Keep `prompt_library` for actual reusable prompts/actions, not raw Agent
  Skills directories.

## Context

The previous idea was to point CodeCompanion `prompt_library.markdown.dirs` at
`~/dotfiles/ai/agents/skills/` or use a `skills_loader.lua` bridge. That should
not be the primary implementation now.

Reasons:

- Agent Skills files are `skill-name/SKILL.md` documents with Agent Skills
  frontmatter such as `name`, `description`, `version`, and `tags`.
- CodeCompanion markdown prompt files expect prompt frontmatter such as `name`
  and `interaction`, plus body sections like `## user` and `## system`.
- Pointing `prompt_library` at the skills root would scan unrelated reference
  files and nested skill support files, which is noisy and fragile.
- Loading all skills as prompt context defeats progressive disclosure and can
  waste context before the model knows which skill is needed.

The active CodeCompanion MCPHub extension is already configured to expose MCPHub
tools, resources, and prompts:

- [lua/plugins/extra/myCodecomp.lua:648-660](lua/plugins/extra/myCodecomp.lua)
  enables `make_tools`, `make_vars`, and `make_slash_commands`.
- [lua/plugins/extra/myCodecomp.lua:664-668](lua/plugins/extra/myCodecomp.lua)
  currently keeps markdown prompt loading pointed at a prompt directory, not the
  skills root.
- [lua/plugins/extra/myAi.lua:433-456](lua/plugins/extra/myAi.lua) is the
  MCPHub setup hook where `opts.native_servers.skills` should be wired before
  `require("mcphub").setup(opts)`.
- [lua/plugins/extra/myAi.lua:487-488](lua/plugins/extra/myAi.lua) has
  `auto_toggle_mcp_servers = true`, which makes disabled servers visible but
  does not automatically start them unless the model calls the correct MCPHub
  toggle tool.

## Current Behavior To Fix

### Rules

CodeCompanion's default rules behavior can attach multiple matching instruction
files. If both `AGENTS.md` and `CLAUDE.md` exist, both may be attached. The
desired behavior is Codex-compatible project discovery plus user-level shared
guidance:

- User-level guidance should prefer
  `~/dotfiles/ai/agents/AGENTS.override.md`, then
  `~/dotfiles/ai/agents/AGENTS.md`, and should ensure RTK guidance is included
  when not already imported by the selected user file.
- Additional user fallbacks should be considered in order:
  `~/.claude`, `~/.codex`, then `~/.pi`.
- Project-level guidance should follow Codex-style hierarchy: start at the
  project root, walk down to current working directory, and select at most one
  instruction file per directory.
- Per directory, prefer `AGENTS.override.md`, then `AGENTS.md`, then
  `CLAUDE.md` as a compatibility fallback.
- If selected files are symlinks to each other or have identical content, keep
  only the highest-priority occurrence.

Rules are passive context/instructions. They are useful for project-wide
guidance, not for a 70+ item skill catalog.

### Codex AGENTS.md Discovery Pattern

Official Codex behavior to mirror where it fits CodeCompanion:

- Global scope: Codex home defaults to `~/.codex`, or `CODEX_HOME` when set.
  It reads `AGENTS.override.md` if present, otherwise `AGENTS.md`, and uses only
  the first non-empty file at that level.
- Project scope: from project root, usually the Git root, down to current working
  directory, Codex checks each directory for `AGENTS.override.md`, then
  `AGENTS.md`, then configured fallback names.
- Merge order: files are concatenated from root down, so more specific nested
  guidance appears later and wins by instruction precedence.
- Codex skips empty files and applies a combined byte limit.

CodeCompanion does not implement this hierarchy natively; this task should add a
small compatibility layer that generates one CodeCompanion rules group with the
right ordered file list.

### Skills

Skills should be discoverable through a small catalog and loaded on demand.
The chat should not receive all `SKILL.md` bodies by default.

### MCP Tool Reliability

Existing GKG prompt work showed models sometimes emit malformed MCPHub calls,
for example missing `server_name` and `action` for `toggle_mcp_server`. Any
skills MCP prompt/tool instructions should use explicit schemas and examples,
similar to the guardrails documented in
[docs/memory/codecompanion-prompt-library-gotchas.md](docs/memory/codecompanion-prompt-library-gotchas.md).

### Chat Title Generation

Prefer patching `ravitemer/codecompanion-history.nvim` for chat title
generation. Upstream is idle and the installed commit matches remote `main`, so
the local patch conflict risk is low.

- Do **not** enable CodeCompanion core
  `interactions.background.chat.opts.enabled` for title generation while
  history auto title is enabled.
- Keep history lifecycle and persistence intact:
  `CodeCompanionChatSubmitted`, `chat.opts.title`, save chat/index, refresh
  count, and picker integration.
- Patch the title generator at
  `codecompanion-history.nvim/lua/codecompanion/_extensions/history/title_generator.lua`.
- Reuse CodeCompanion core title filtering/formatting from
  `codecompanion.interactions.background.builtin.chat_make_title.format_messages`
  so rules and config system prompts are ignored consistently.
- Treat a custom background action as fallback only. If used, it must set
  `chat.opts.title`, call `chat:set_title(title)`, and then
  `require("codecompanion").extensions.history.save_chat(chat)`, with history
  auto title disabled.

## Proposed Implementation Actions

- [ ] Add a smart CodeCompanion rules utility, for example
  `lua/utils/codecompanion_smart_rules.lua`, that builds an ordered,
  deduplicated list of user and project instruction files.
- [ ] Add CodeCompanion `rules` configuration in
  [lua/plugins/extra/myCodecomp.lua](lua/plugins/extra/myCodecomp.lua) that
  autoloads a generated `smart_default` group while preserving builtin
  `default` for manual `/rules default` use.
- [ ] Support `AGENTS.override.md` before `AGENTS.md` at user and project
  scopes.
- [ ] Walk project directories from Git root to current working directory,
  selecting at most one file per directory.
- [ ] Deduplicate selected rule files by symlink/realpath and by content hash,
  keeping the earlier, higher-priority candidate.
- [ ] Do not point `prompt_library.markdown.dirs` at
  `~/dotfiles/ai/agents/skills/`. Leave it for real CodeCompanion prompts only.
- [ ] Add a small utility module, for example
  `lua/utils/mcphub_skills.lua`, that scans
  `/Users/tharutaipree/dotfiles/ai/agents/skills` for `*/SKILL.md`.
- [ ] Prefer configuration-based MCPHub native server registration by adding a
  `skills` entry to `opts.native_servers` before
  `require("mcphub").setup(opts)` in
  [lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua).
- [ ] Keep incremental MCPHub registration as a fallback only. If used, put
  `mcphub.add_server`, `mcphub.add_tool`, `mcphub.add_resource_template`, and
  `mcphub.add_prompt` calls in a separate module required after
  `require("mcphub").setup(opts)`, and guard against duplicate capability
  registration on reload.
- [ ] Expose native MCP tools:
  `list_skills`, `activate_skill`, and `read_skill_file`.
- [ ] Add a read-only resource template such as
  `skill://{name}/{path}` only after path traversal checks are implemented.
- [ ] Optionally expose a native MCP prompt such as `/mcp:skills:use_skill`
  once the tool flow works reliably and CodeCompanion shows it as a slash
  command.
- [ ] Add docs to `docs/memory/codecompanion.md` or a dedicated memory doc such
  as `docs/memory/codecompanion-skills.md`.

## Suggested Code Shape

### CodeCompanion smart rules autoload

Keep CodeCompanion's builtin `default` group available, but do not autoload it.
Autoload one generated group instead:

```lua
rules = {
  smart_default = {
    description = "Codex-style user/project instructions with dedupe",
    files = {},
  },
  opts = {
    chat = {
      enabled = true,
      autoload = function()
        require("utils.codecompanion_smart_rules").refresh("smart_default")
        return "smart_default"
      end,
    },
  },
}
```

Suggested utility behavior:

```lua
-- Pseudocode only; implement as tested Lua in lua/utils/codecompanion_smart_rules.lua.
local user_roots = {
  vim.fn.expand("~/dotfiles/ai/agents"),
  vim.fn.expand("~/.claude"),
  vim.fn.expand("~/.codex"),
  vim.fn.expand("~/.pi"),
}

-- User scope: first non-empty selected file wins per root family/order.
-- Prefer AGENTS.override.md, then AGENTS.md.
-- For ~/.claude compatibility, also allow CLAUDE.md after AGENTS candidates.

-- Project scope: build directories from git root to cwd.
-- Per directory, choose the first non-empty existing file in:
-- AGENTS.override.md, AGENTS.md, CLAUDE.md.

-- Deduplicate after candidate selection:
-- 1. realpath key when available, so CLAUDE.md -> AGENTS.md collapses.
-- 2. content hash key, so copied identical files collapse.
-- Keep the earliest candidate because the candidate list is already priority ordered.
```

Use the `claude` parser for `AGENTS*.md` and `CLAUDE*.md` so `@RTK.md` imports
continue to work. Add RTK explicitly only when no selected user-level file
already imports or duplicates it.

### MCPHub native skills server

Prefer configuration-based registration because the skills server is a stable
set of capabilities with dynamic handlers, not a runtime-mutated tool list. Add
the server schema to `opts.native_servers` before MCPHub setup:

```lua
opts.native_servers = vim.tbl_deep_extend("force", opts.native_servers or {}, {
  skills = require("utils.mcphub_skills").server {
    root = vim.fn.expand("~/dotfiles/ai/agents/skills"),
  },
})

require("mcphub").setup(opts)
```

Use incremental registration only if the implementation truly needs post-setup
mutation:

```lua
require("mcphub").setup(opts)
require("utils.mcphub_skills").register_incremental {
  root = vim.fn.expand("~/dotfiles/ai/agents/skills"),
}
```

If the incremental path is used, `register_incremental` must be idempotent. The
installed MCPHub native API returns an existing server on duplicate server
registration, but `add_tool` and similar calls append capabilities to an
existing server, so repeated sourcing can create duplicate tools unless guarded.

Suggested server schema shape:

```lua
return {
  name = "skills",
  displayName = "Agent Skills",
  capabilities = {
    tools = {
      -- list_skills, activate_skill, read_skill_file
    },
    resources = {},
    resourceTemplates = {
      -- optional skill://{name}/{path}
    },
    prompts = {
      -- optional use_skill
    },
  },
}
```

Suggested native tools:

- `list_skills`: returns `name`, `description`, `path`, `tags`, and optional
  `compatibility`, with `query` and `limit` inputs.
- `activate_skill`: takes `name` or `path`, returns the full `SKILL.md` content
  plus a short instruction to follow referenced files only when needed.
- `read_skill_file`: takes `name` plus a relative file path, validates that the
  resolved path stays under that skill directory, and returns the file content.

Native handler contract to follow:

- Tool handlers receive `handler = function(req, res)` and should read validated
  inputs from `req.params`, not from ad hoc argument names.
- Successful tool/resource handlers must finish with `res:text(...):send()` or
  another response builder plus `:send()`.
- `res:error(message, details)` auto-sends error responses; do not chain
  `:send()` after errors.
- Return catalog data from `list_skills` as JSON text with
  `res:text(json, "application/json"):send()`.
- Return full `SKILL.md` bodies as markdown text, and referenced support files
  as text with an appropriate MIME type when obvious.
- Keep tool schemas narrow and explicit so CodeCompanion/MCPHub calls use
  `server_name`, `tool_name`, and `tool_input` reliably through `@{mcp}`.

Suggested input schemas:

```lua
list_skills = {
  type = "object",
  properties = {
    query = { type = "string", description = "Optional text search" },
    limit = { type = "integer", description = "Maximum results to return" },
  },
}

activate_skill = {
  type = "object",
  properties = {
    name = { type = "string", description = "Skill name from list_skills" },
  },
  required = { "name" },
}

read_skill_file = {
  type = "object",
  properties = {
    name = { type = "string", description = "Skill name from list_skills" },
    path = { type = "string", description = "Relative path inside the skill" },
  },
  required = { "name", "path" },
}
```

Resource template guidance:

- Add `skill://{name}/{path}` only after `read_skill_file` is safe.
- Normalize and resolve the requested path, reject absolute paths, `..`, and
  symlink escapes outside the selected skill directory.
- Prefer resources for known files after skill activation, not for broad
  discovery. Tools remain the primary discovery path.

Prompt guidance:

- Use an MCP prompt only as a convenience wrapper, not as the core skill
  activation mechanism.
- Suggested prompt name: `use_skill`, surfaced by CodeCompanion as something
  like `/mcp:skills:use_skill`.
- Prompt handler should emit a user instruction to list/select/activate a skill
  and may add a short LLM scaffold response with `res:user():text(...)`,
  `res:llm():text(...)`, then `:send()`.

Suggested model-facing usage:

```md
@{skills}
Find the best skill for addressing GitLab MR comments, activate it, then follow it.
```

Fallback usage through the static MCPHub group:

```md
@{mcp}
Use `use_mcp_tool` with:
{ "server_name": "skills", "tool_name": "list_skills", "tool_input": { "query": "gitlab review comments" } }

Then call:
{ "server_name": "skills", "tool_name": "activate_skill", "tool_input": { "name": "<chosen_skill>" } }
```

## Tools vs Prompts vs Resources

Use tools first:

- Tools are model-callable actions. They are the best fit for `list_skills`,
  `activate_skill`, and `read_skill_file`.
- Prompts are user-invoked slash commands. They are useful for a curated command
  like `/mcp:skills:use_skill`, but should not be the only way the model can
  select a skill.
- Resources are read-only context handles. They are useful for attaching known
  files, but less useful for discovery unless paired with a resource template.
- Native MCPHub servers run in Neovim's Lua runtime, so the `skills` server
  should not require a separate Node/Python process or an external MCP server
  entry in `mcphub.json`.
- Native handlers can inspect `req.caller` and `req.editor_info`, but the
  initial skills implementation should avoid plugin-specific behavior unless it
  is needed for a concrete workflow.

With the current CodeCompanion MCPHub extension settings, the chat should see
MCPHub-native skills capabilities when they are exposed by MCPHub and attached
to the chat. Do not rely on fully automatic model discovery:

- Use `@{skills}` when the native server is connected and registered as a
  dynamic CodeCompanion tool group.
- Use `@{mcp}` when reliability matters, because it is the static MCPHub bridge
  group and can call `use_mcp_tool` by `server_name`, `tool_name`, and
  `tool_input`.
- Use slash commands only for explicit user actions, not autonomous skill
  selection.

## Success Criteria

- CodeCompanion chat autoloads a Codex-style ordered rule chain:
  preferred user guidance first, then project files from root to current working
  directory.
- `AGENTS.override.md` wins over `AGENTS.md` in the same user/project
  directory.
- Project `AGENTS.md` wins over project `CLAUDE.md` in the same directory.
- Symlinked duplicates and identical-content duplicates are attached once.
- RTK guidance is present once when available.
- `prompt_library.markdown.dirs` remains limited to real CodeCompanion prompt
  directories and does not scan `~/dotfiles/ai/agents/skills`.
- MCPHub exposes a native `skills` server visible through CodeCompanion.
- The `skills` server is registered through `opts.native_servers` unless a
  specific implementation constraint requires incremental registration.
- Native handlers follow MCPHub's documented `req.params` and chainable
  `res:*():send()` response API.
- The model can list skills, activate exactly one relevant skill, and read
  directly referenced skill files without preloading the entire skills tree.
- The skills server rejects unsafe relative paths such as `../secret`.
- Re-sourcing the MCPHub config does not create duplicate `skills` tools,
  prompts, resources, or resource templates.
- The GKG prompt still works and does not regress from the MCPHub tool-call
  guardrails.

## Verification

### How to verify

Use the worktree Neovim profile. Test one repo that has both `AGENTS.md` and
`CLAUDE.md`, then test a repo with only `CLAUDE.md` if available.

Start MCPHub and CodeCompanion, then verify both the passive rules behavior and
the active skills MCP workflow.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
" Inspect CodeCompanion rules behavior after opening chat.
:CodeCompanionChat

" Open MCPHub and verify the native skills server is registered.
:MCPHub

" Open CodeCompanion action/chat UI and check MCP tool exposure.
:CodeCompanionActions
```

Manual chat smoke tests:

```md
@{mcp}
Call `use_mcp_tool` with:
{ "server_name": "skills", "tool_name": "list_skills", "tool_input": { "query": "gitlab comments", "limit": 5 } }
```

```md
@{mcp}
Call `use_mcp_tool` with:
{ "server_name": "skills", "tool_name": "activate_skill", "tool_input": { "name": "gitlab-address-comments" } }
```

### Checklist

- [ ] User guidance attaches from `~/dotfiles/ai/agents/AGENTS.md` when no
  higher-priority user override exists.
- [ ] `AGENTS.override.md` wins over `AGENTS.md` in the same directory.
- [ ] A project `CLAUDE.md -> AGENTS.md` symlink is attached only once.
- [ ] A copied file with identical content is attached only once.
- [ ] Project rule files are attached from Git root down to current working
  directory.
- [ ] In a project directory with both `AGENTS.md` and `CLAUDE.md`, only
  `AGENTS.md` is selected.
- [ ] In a project directory with only `CLAUDE.md`, `CLAUDE.md` is selected.
- [ ] In a repo with no project instruction files, CodeCompanion opens chat
  without rule-file errors and still attaches available user guidance.
- [ ] `:MCPHub` shows the native `skills` server.
- [ ] The native `skills` server appears under MCPHub native servers without a
  separate `mcphub.json` external server entry.
- [ ] `skills` is wired through `opts.native_servers` before
  `require("mcphub").setup(opts)`, or an explicit note explains why the
  incremental API path was required.
- [ ] Re-sourcing the plugin config or restarting Neovim does not duplicate
  `list_skills`, `activate_skill`, `read_skill_file`, prompts, or resource
  templates in `:MCPHub`.
- [ ] CodeCompanion can call `skills.list_skills` through `@{mcp}`.
- [ ] CodeCompanion can activate one skill and receives the full selected
  `SKILL.md`.
- [ ] `read_skill_file` can read a referenced file inside a skill directory.
- [ ] `read_skill_file` rejects path traversal outside the selected skill.
- [ ] `list_skills` returns JSON text with `application/json` MIME type.
- [ ] Tool handlers use `req.params` and success responses end with `:send()`.
- [ ] Tool errors use `res:error(...)` and do not require `:send()`.
- [ ] Optional `skill://{name}/{path}` resource template works only for safe
  relative paths inside the selected skill directory.
- [ ] Optional `/mcp:skills:use_skill` prompt appears only after the direct tool
  flow is stable.
- [ ] Existing GKG prompt can still call MCPHub/GKG with the explicit
  `server_name`, `tool_name`, and `tool_input` shape.
- [ ] Rules are omitted from the generated chat title prompt.
- [ ] Chat title persists in the history index after submission.
- [ ] No duplicate title requests occur when history auto title is enabled.
- [ ] CodeCompanion upgrade compatibility for the history title patch is
  checked against the installed `main`-matching commit.

## References

- [CodeCompanion rules docs](https://codecompanion.olimorris.dev/configuration/rules)
- [CodeCompanion prompt library docs](https://codecompanion.olimorris.dev/configuration/prompt-library)
- [CodeCompanion MCP docs](https://codecompanion.olimorris.dev/model-context-protocol)
- [Codex AGENTS.md discovery docs](https://developers.openai.com/codex/guides/agents-md#how-codex-discovers-guidance)
- [MCPHub native servers docs](https://ravitemer.github.io/mcphub.nvim/mcp/native/index.html)
- [MCPHub native prompts docs](https://ravitemer.github.io/mcphub.nvim/mcp/native/prompts.html)
- [Agent Skills specification](https://agentskills.io/specification)
- [Agent Skills client implementation guide](https://agentskills.io/client-implementation/adding-skills-support)
- [Agent Skills path standardization discussion](https://github.com/agentskills/agentskills/issues/15)
- [Claude Code .agents/skills discussion](https://github.com/anthropics/claude-code/issues/16345)
