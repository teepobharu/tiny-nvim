---
title: "Investigate CodeCompanion chat title generation rules"
status: open
priority: medium
created: 2026-07-06
updated: 2026-07-06
category: "ai-tooling"
related:
  - [CodeCompanion config](lua/plugins/extra/myCodecomp.lua)
  - [CodeCompanion memory](docs/memory/codecompanion.md)
  - [Markdown prompt library memory](docs/memory/codecompanion-markdown-prompt-library.md)
---

## Objective

Understand the current CodeCompanion chat-title generation flow and determine whether saved chat titles can be made more relevant by injecting explicit title rules or instructions.

Target outcome: decide whether this should be solved by configuration, a small local override, an upstream feature request, or no change.

## Context

Example saved chat title:

```text
Commit Message Guidelines (1)
```

The chat content included CodeCompanion rules/context lines such as:

```text
> Context:
> - <rules>/Users/tharutaipree/.claude/CLAUDE.md</rules>
> - <rules>/Users/tharutaipree/.claude/RTK.md</rules>
> - <help>codecompanion-configuration-prompt-library</help>
> - <buf>Extras/Template/copilot-custom-prompts/codecompanion/BUTLER-mem.md</buf>
```

Question to answer: can title generation use rules/instructions like "prefer the user ask, ignore prompt-library/rules names, and avoid generic titles such as Commit Message Guidelines"?

## Current Logic Snapshot

Working hypothesis from local source inspection:

1. This config enables `ravitemer/codecompanion-history.nvim` in [myCodecomp.lua](lua/plugins/extra/myCodecomp.lua:634).
2. History title generation is enabled via `auto_generate_title = true`.
3. Title generation uses `title_generation_opts.adapter = DEFAULT_ADAPTER` and `model = AI_CONST.static_models.fast[1]`.
4. `refresh_every_n_prompts = 0`, so titles are generated only when there is no existing `chat.opts.title`; they are not refreshed as the topic changes.
5. `codecompanion-history.nvim` generates the initial title on `CodeCompanionChatSubmitted`.
6. The history title generator filters chat messages to user/assistant content and excludes messages tagged as references/context, then uses the first user message for the initial title.
7. The history extension prompt is hard-coded in `codecompanion-history.nvim/lua/codecompanion/_extensions/history/title_generator.lua` and asks for a max-5-word title.
8. CodeCompanion itself also ships `interactions.background.builtin.chat_make_title`, but the default background chat callbacks are disabled unless `interactions.background.chat.opts.enabled` is set true. This config appears to rely on the history extension for saved-chat titles.
9. CodeCompanion's built-in background title helper explicitly omits `RULES` and `SYSTEM_PROMPT_FROM_CONFIG` tags from title context. Need verify whether history title generation does the same for the example chat.

## Refined Understanding

There are at least four different "title" paths that can produce confusing results:

1. **Existing chat title path**: `Chat.new(args)` stores `args.title` as both `chat.title` and `chat.opts.title`. If a prompt-library or resume/fork path creates a chat with a title, history title generation will skip LLM generation because `TitleGenerator:should_generate()` sees `chat.opts.title`.
2. **History LLM title path**: if `chat.opts.title` is missing, `codecompanion-history.nvim` generates a title on `CodeCompanionChatSubmitted`. Initial generation uses the first relevant user message only. Refresh generation uses recent conversation, but refresh is disabled in this config with `refresh_every_n_prompts = 0`.
3. **Duplicate title path**: duplicating a saved chat appends ` (1)` when no replacement title is entered. This suffix is persisted in history storage.
4. **Buffer-name collision path**: `history/ui.lua` appends ` (1)`, ` (2)`, etc. when `nvim_buf_set_name()` fails because another buffer already has the same title. This suffix may only affect the buffer name/title display, not necessarily `chat.opts.title` or the saved history title.

This means `Commit Message Guidelines (1)` needs to be classified before changing behavior. The `Commit Message Guidelines` part might be an existing prompt-library/default title, an LLM-generated title, or a manual/previous title. The `(1)` part might be a persisted duplicate suffix or only a buffer-name collision suffix.

## Proposed Approach

- [ ] First classify the title source, before changing prompts:
  - [ ] Check `chat.opts.title`, `chat.title`, and the buffer name immediately after chat creation.
  - [ ] Check the saved history JSON for `title`.
  - [ ] Check whether the displayed `(1)` exists in saved history or only in the buffer name.
- [ ] Then decide the fix lane:
  - [ ] If prompt-library creates `chat.opts.title`, add an option/callback to clear or replace title before history generation.
  - [ ] If history LLM generates weak titles, add a local title prompt override or propose upstream `title_generation_opts.prompt/system_prompt`.
  - [ ] If duplicate/collision suffix is the visible issue, handle naming separately from title-generation prompt rules.
  - [ ] If rules/help/buffer context contaminates title input, filter context before title-generation prompt construction.
- [ ] Prefer a small local wrapper around history title generation if needed; avoid editing plugin source directly.

## Action Items

- [ ] Reproduce title generation with a fresh chat using the example prompt/rules context.
- [ ] Confirm whether `Commit Message Guidelines (1)` came from history auto-generation, prompt-library/default chat title, manual rename, or duplicate suffix behavior.
- [ ] Confirm whether `Commit Message Guidelines (1)` is persisted in history JSON or only shown as the Neovim buffer name.
- [ ] Trace the exact event flow: `CodeCompanionChatCreated` -> `CodeCompanionChatSubmitted` -> history `TitleGenerator:should_generate()` -> `TitleGenerator:generate()`.
- [ ] Inspect whether `chat.messages` includes `<rules>` context as plain user-visible content or as tagged/reference metadata that title generation filters out.
- [ ] Check whether `title_generation_opts.format_title` is enough for post-processing only, or whether a prompt override is required.
- [ ] Prototype a local override if needed, preferably in `lua/utils/` plus `lua/plugins/extra/myCodecomp.lua`, without patching upstream plugin files directly.
- [ ] Document final behavior and chosen approach in [CodeCompanion memory](docs/memory/codecompanion.md).

## Points to Confirm

- [ ] Confirm the desired title style: short task phrase, user-question summary, file/topic name, or project-scoped prefix.
- [ ] Confirm whether title generation should ignore `<rules>`, `<help>`, and `<buf>` context labels entirely.
- [ ] Confirm whether titles should be generated from the first user message only or refreshed after N user prompts.
- [ ] Confirm whether prompt-library chats should use the prompt name as a fallback title or always ask the LLM to summarize the actual user request.
- [ ] Confirm whether an existing prompt-library title should block auto-title generation, or whether auto-title should replace generic prompt names.
- [ ] Confirm whether duplicate titles should be allowed visually with `(1)` suffixes or replaced with unique content-based titles.
- [ ] Confirm whether a local monkey-patch is acceptable if the history extension does not expose a title prompt override.

## Implementation Plan

- [ ] Enable history logging temporarily and create a throwaway chat to capture title-generation timing and output.
- [ ] Add temporary diagnostics around title generation to print:
  - `chat.opts.title`
  - `chat.title`
  - `vim.api.nvim_buf_get_name(chat.bufnr)`
  - `chat.opts.save_id`
  - `chat.from_prompt_library`
  - filtered relevant message count
  - first user message excerpt
  - whether rules/context messages have `opts.tag`, `opts.reference`, or `opts.context_id`
- [ ] Inspect the saved history files:
  - `~/.local/share/nvimwt3a/codecompanion-history/index.json`
  - `~/.local/share/nvimwt3a/codecompanion-history/chats/<save_id>.json`
- [ ] Evaluate configuration-only options:
  - `title_generation_opts.adapter`
  - `title_generation_opts.model`
  - `title_generation_opts.refresh_every_n_prompts`
  - `title_generation_opts.format_title`
- [ ] If configuration is insufficient, prototype one of:
  - wrapper around history `TitleGenerator:generate()`
  - upstream option for `title_generation_opts.system_prompt` or `title_generation_opts.prompt`
  - switch to CodeCompanion built-in background `chat_make_title` only if it can coexist cleanly with history persistence
- [ ] Add verification steps and move this task to review after the current flow and feasibility are documented.

## Success Criteria

- Current title-generation owner is identified: CodeCompanion history extension vs CodeCompanion background interaction.
- The source of titles like `Commit Message Guidelines (1)` is explained.
- There is a clear answer on whether rules/instructions can influence generated titles today.
- A recommended implementation path is documented, including tradeoffs and affected files.

## Verification

### How to verify

Use the worktree profile first. Create a new CodeCompanion chat with prompt-library/rules context similar to the example, submit one message, and inspect the saved title and history file.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
:CodeCompanionChat
:CodeCompanionHistory
```

Optional source inspection:

```bash
rg -n "auto_generate_title|title_generation_opts|TitleGenerator|chat_make_title" \
  lua/plugins/extra/myCodecomp.lua \
  ~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion-history.nvim/lua \
  ~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/interactions/background
```

### Checklist

- [ ] Fresh chat gets a generated title after first submit.
- [ ] Title-generation log/diagnostics show which messages were used.
- [ ] Rules/help/buffer context either appears in title input or is confirmed filtered out.
- [ ] Title can be improved by config-only change, or a local override/upstream feature is identified.

## References

- [CodeCompanion history config](lua/plugins/extra/myCodecomp.lua:634)
- `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion-history.nvim/lua/codecompanion/_extensions/history/title_generator.lua`
- `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion-history.nvim/lua/codecompanion/_extensions/history/init.lua`
- `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/interactions/background/builtin/chat_make_title.lua`
- `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/config.lua`
