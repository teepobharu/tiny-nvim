---
title: "CodeCompanion markdown prompts with skills_loader from extra dirs"
status: open
priority: medium
created: 2026-05-17
updated: 2026-05-17
related:
  - [CC config (worktree)](lua/plugins/extra/codecompanion.lua)
  - [CC config (main)](lua/plugins/extra/codecompanion.lua)
  - [Prompts dir](~/Personal/mynotes/Extras/Template/copilot-custom-prompts/codecompanion/)
  - [CC actions dispatch](~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/actions/init.lua)
  - [CC markdown parser](~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/actions/markdown.lua)
  - [Memory doc](docs/memory/codecompanion-markdown-prompts.md)
---

## Objective

Enable CodeCompanion to load markdown prompts from an external directory (`~/Personal/mynotes/.../codecompanion/`) via `prompt_library.markdown.dirs`, with a shared `skills_loader.lua` that injects agent skill content into prompts via `${skills_loader.key}` placeholders. POC with `Review_verify_research.prompt.md`.

## Context

CodeCompanion supports markdown prompts with YAML frontmatter (`name`, `interaction` required). The `prompt_library.markdown.dirs` config scans external dirs for `.md` files and adds them to `:CodeCompanionActions`. Sibling `.lua` files are loaded on demand when prompts contain dot-notation placeholders like `${skills_loader.foo}`.

### Source-verified dispatch flow

1. `:CodeCompanionActions` → `actions/init.lua:56 set_items()`
2. Lua prompt_library entries processed first (line 77-81), `markdown` key filtered out by name
3. `config.prompt_library.markdown.dirs` iterated (line 85-92), each dir scanned via `markdown.load_from_dir()`
4. `.md` files parsed: frontmatter (YAML treesitter) + body (`## system`/`## user` sections)
5. On item selection → `actions/init.lua:124 resolve()` → `markdown.resolve_placeholders()`
6. Placeholder `${skills_loader.foo}` → dot-prefix `skills_loader` → `dofile("skills_loader.lua")` in prompt's dir → table lookup

### How `${...}` placeholders work

Placeholders use the syntax `${<luafile>.<key>}` and are resolved at **chat-start time**, not at load time.

- `<luafile>` = the Lua file basename (no `.lua`) in the same directory as the prompt
- `<key>` = a key in the table returned by that Lua file
- Example: `${skills_loader.glab_mr_reviewer_summary}` → runs `dofile("skills_loader.lua")` in the prompt's dir, then returns `result["glab_mr_reviewer_summary"]`
- The resolved string replaces the placeholder inline in the prompt content before sending to the LLM
- **Each `dofile()` call re-executes the Lua file** (no cross-session cache), so file reads happen on every prompt selection
- If the key is missing from the returned table, the placeholder is left as-is (literal `${...}` text appears in the chat)
- Dot notation is required: `${foo.bar}` works; `${foobar}` does NOT trigger the file-loader mechanism

### Critical findings from code review

| Finding | Impact | Mitigation |
|---------|--------|------------|
| **Cache persists per-session** (`_cached_actions` at `actions/init.lua:8`) | Editing `.md`/`.lua` files won't update palette until cache cleared | Must call `:lua require("codecompanion.actions").refresh_cache(require("codecompanion.utils.context").get(0))` or restart nvim |
| **`@{tool}` is VS Code syntax, not CC** | Current body `@{read_file}` etc. renders as literal text, not tool invocation | Remove VS Code syntax; use frontmatter `tools:` for CC tool attachment |
| **glab-mr-reviewer SKILL.md is 43KB** | Injecting full SKILL.md into system prompt overwhelms context | Create trimmed summary or extract only relevant sections |
| **Frontmatter requires `name` + `interaction`** | Files without valid frontmatter silently skipped (warn logged) | Ensure all prompts have proper frontmatter — `goal:` alone is NOT enough |
| **`prompt_library.markdown` key safe** | Lua resolver filters `name == "markdown"` explicitly (`prompt_library.lua:19-24`) | No action needed — intentional design |
| **dofile() re-executes on each chat-start** | skills_loader.lua I/O runs every time prompt is selected (no cross-session cache) | Acceptable for small number of skills; file reads are fast |
| **Frontmatter is NOT included in chat content** | `parse_prompt` passes full file to treesitter, but `chat.scm` query only captures children of `## heading` (`atx_h2_marker`) sections — everything before the first `##` is ignored | No action needed — by design. Body content before any `##` is also silently dropped. |
| **Body content must be under `## system` or `## user` headings** | Text outside these sections (e.g. under `# h1` headings or bare paragraphs) is captured by the `content` query but assigned to whichever `current_role` was last set — or dropped if no role was set yet | Wrap all content under `## user` or `## system` sections |

## Implementation Plan

- [ ] **Step 1**: Add `markdown.dirs` to `lua/plugins/extra/codecompanion.lua` opts
  ```lua
  prompt_library = {
    markdown = {
      dirs = {
        vim.fn.expand("~/Personal/mynotes/Extras/Template/copilot-custom-prompts/codecompanion"),
      },
    },
    -- existing prompts...
  },
  ```
  Note: `markdown` key goes inside `prompt_library` alongside existing prompt entries. Lazy deep-merges opts tables.

- [ ] **Step 2**: Create `skills_loader.lua` in the prompts dir
  File: `~/Personal/mynotes/Extras/Template/copilot-custom-prompts/codecompanion/skills_loader.lua`
  - Returns table of `key = string` pairs
  - Each value reads a trimmed/summarized skill file (NOT raw 43KB SKILL.md)
  - For `glab_mr_reviewer`: extract only the "Usage" and core workflow sections (~2-3KB)
  - For `gitlab_address_comments`: full SKILL.md is fine (5KB)

- [ ] **Step 3**: Rewrite `Review_verify_research.prompt.md` with proper frontmatter
  - Add `name`, `interaction: chat`, `description`
  - Add `tools:` list based on what CC actually supports (e.g. `cmd_runner`, `editor`, `files`)
  - Replace VS Code `@{tool}` syntax with natural language instructions
  - Add `${skills_loader.glab_mr_reviewer}` and `${skills_loader.gitlab_address_comments}` placeholders in system section

- [ ] **Step 4**: Smoke test in worktree profile
  - `:CodeCompanionActions` shows "Review & Verify Research"
  - Selecting it opens chat with skill content in system message
  - Tools listed in frontmatter are available
  - Cache refresh works after edits

- [ ] **Step 5**: Write memory doc `docs/memory/codecompanion-markdown-prompts.md`
  - Placeholder mechanism (dot-notation requirement)
  - Cache behavior and refresh command
  - Difference between `${...}` placeholders and CC tools
  - skills_loader pattern

## Success Criteria

- `Review_verify_research` prompt appears in `:CodeCompanionActions` palette
- Selecting it injects skill content (verified in chat system message)
- Pattern is repeatable for additional prompts without config changes
- No existing prompts/keymaps regress

## Verification

### How to verify

Start worktree nvim profile. Open any buffer, trigger actions palette, select the new prompt.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
" Check prompt appears in palette
:CodeCompanionActions

" After selecting 'Review & Verify Research', check system message content
" in the chat buffer — should contain skill text, not ${...} placeholders

" After editing skills_loader.lua, clear cache and re-check
:lua require("codecompanion.actions").refresh_cache(require("codecompanion.utils.context").get(0))
:CodeCompanionActions
```

### Checklist

- [ ] "Review & Verify Research" visible in `:CodeCompanionActions`
- [ ] Selecting it opens chat with injected skill content (no raw `${...}` in message)
- [ ] No `@{read_file}` literal text in the chat message
- [ ] Existing CC prompts (explain, review, refactor, etc.) still work
- [ ] Cache refresh command works without restart
- [ ] Other `.md` files now with frontmatter (`projects_mmbweb_test.md`, `sla-experiment-create.md`, `logql_inject_userid_into_urlquery.md`) load without WARN

## References

- [CC markdown prompt feature PR](https://github.com/olimorris/codecompanion.nvim/issues/2471)
- [CC actions dispatch](~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/actions/init.lua)
- [CC markdown parser + placeholder resolver](~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/actions/markdown.lua)
- [Existing with-opts.md example](~/Personal/mynotes/Extras/Template/copilot-custom-prompts/codecompanion/with-opts.md)
