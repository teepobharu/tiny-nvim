---
title: "Investigate CodeCompanion chat title generation rules"
status: completed
priority: medium
created: 2026-07-06
updated: 2026-08-30
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
9. CodeCompanion's built-in background title helper explicitly omits `RULES` and `SYSTEM_PROMPT_FROM_CONFIG` tags. The history extension independently excludes messages carrying `opts.tag`, `opts.reference`, or `opts.context_id` before constructing its prompt.

## Refined Understanding

There are at least four different "title" paths that can produce confusing results:

1. **Existing chat title path**: `Chat.new(args)` stores `args.title` as both `chat.title` and `chat.opts.title`. If a prompt-library or resume/fork path creates a chat with a title, history title generation will skip LLM generation because `TitleGenerator:should_generate()` sees `chat.opts.title`.
2. **History LLM title path**: if `chat.opts.title` is missing, `codecompanion-history.nvim` generates a title on `CodeCompanionChatSubmitted`. Initial generation uses the first relevant user message only. Refresh generation uses recent conversation, but refresh is disabled in this config with `refresh_every_n_prompts = 0`.
3. **Duplicate title path**: duplicating a saved chat appends ` (1)` when no replacement title is entered. This suffix is persisted in history storage.
4. **Buffer-name collision path**: `history/ui.lua` appends ` (1)`, ` (2)`, etc. when `nvim_buf_set_name()` fails because another buffer already has the same title. This suffix may only affect the buffer name/title display, not necessarily `chat.opts.title` or the saved history title.

This means `Commit Message Guidelines (1)` needs to be classified before changing behavior. The `Commit Message Guidelines` part might be an existing prompt-library/default title, an LLM-generated title, or a manual/previous title. The `(1)` part might be a persisted duplicate suffix or only a buffer-name collision suffix.

## Proposed Approach

- [x] First classify the possible title sources before changing prompts:
  - [ ] Check `chat.opts.title`, `chat.title`, and the buffer name immediately after chat creation.
  - [ ] Check the saved history JSON for `title`.
  - [ ] Check whether the displayed `(1)` exists in saved history or only in the buffer name.
- [x] Then decide the fix lane:
  - [ ] If prompt-library creates `chat.opts.title`, add an option/callback to clear or replace title before history generation.
  - [x] If history LLM generates weak titles, add a local `title_generation_opts.prompt` override.
  - [ ] If duplicate/collision suffix is the visible issue, handle naming separately from title-generation prompt rules.
  - [x] Confirm tagged rules/help/buffer context is filtered before prompt construction.
- [x] Keep the plugin checkout untouched by shipping the change through `lazy-local-patcher.nvim`.

## Action Items

- [ ] Reproduce title generation with a fresh chat using the example prompt/rules context.
- [ ] Confirm whether `Commit Message Guidelines (1)` came from history auto-generation, prompt-library/default chat title, manual rename, or duplicate suffix behavior.
- [ ] Confirm whether `Commit Message Guidelines (1)` is persisted in history JSON or only shown as the Neovim buffer name.
- [x] Trace the exact event flow: `CodeCompanionChatSubmitted` -> history `TitleGenerator:should_generate()` -> `TitleGenerator:generate()`.
- [x] Inspect how tagged/reference/context messages are excluded from the relevant-message set.
- [x] Confirm `title_generation_opts.format_title` is post-processing only and a prompt override is required.
- [x] Add the override as a local patch plus configuration in `myCodecomp.lua`, without editing the installed plugin checkout.
- [x] Document final behavior and the `(1)` diagnostic paths in [CodeCompanion memory](docs/memory/codecompanion.md).

## Points to Confirm

- [x] Use a concise task/outcome phrase of at most five words.
- [x] Ignore instruction/rule/help/buffer labels unless the user explicitly asks about them.
- [x] Keep first-submit generation and `refresh_every_n_prompts = 0`.
- [x] Preserve existing-title behavior; classify prompt-library titles separately if one bypasses generation.
- [x] Treat duplicate and buffer-collision suffixes as naming behavior, separate from the generation prompt.
- [x] Use the repository's local patch mechanism rather than a runtime monkey-patch.

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
- [x] Evaluate configuration-only options:
  - `title_generation_opts.adapter`
  - `title_generation_opts.model`
  - `title_generation_opts.refresh_every_n_prompts`
  - `title_generation_opts.format_title`
- [x] Configuration was insufficient; add:
  - local patch adding `title_generation_opts.prompt`
  - explicit title rules in `lua/plugins/extra/myCodecomp.lua`
- [x] Add verification steps and move this task to review after the current flow and feasibility are documented.

## Success Criteria

- Current title-generation owner is identified: CodeCompanion history extension vs CodeCompanion background interaction.
- The possible sources of `Commit Message Guidelines (1)` are explained; the exact historical instance remains a user-side live-data check.
- There is a clear answer on whether rules/instructions can influence generated titles today.
- A recommended implementation path is documented, including tradeoffs and affected files.

## Verification

### How to verify

Use the worktree profile first. Confirm the patch applies, then create a new CodeCompanion chat with prompt-library/rules context similar to the example, submit one message, and inspect the saved title and history file. The implementation pass intentionally did not call an external model or inspect live session data.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim

git -C ~/.local/share/nvimwt3a/lazy/codecompanion-history.nvim \
  apply --check --ignore-space-change \
  ~/.config/nvimwt3a/patches/codecompanion-history.nvim/01-title-prompt-v1.patch
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

- [x] Patch applies cleanly to the pinned `codecompanion-history.nvim` commit `bc1b4fe`.
- [x] Worktree profile loads the configured `title_generation_opts.prompt` without a Lua/config error.
- [x] The patched title generator passes the isolated v19 context regression
      test (17 assertions) with an adapter stub: top-level/nested metadata and
      context rows are excluded before both initial and refresh prompts.
- [ ] Fresh chat gets a generated title after first submit.
- [ ] Fresh title is at most five words and reflects the concrete user request.
- [ ] Rules/help/buffer or prompt-library labels do not become the title unless explicitly requested.
- [ ] Saved history JSON and the buffer name distinguish a persisted duplicate suffix from a buffer collision.
- [ ] Existing prompt-library titles still bypass generation; decide whether that behavior should remain a separate task.

## User Signoff

- [x] Accept the title-prompt implementation and close this task.
- [ ] Keep it open to change existing prompt-library title precedence.
- [ ] Return it for changes and record the failed live check below.

### Failed checks / follow-up

- None recorded.

## Review Feedback — 2026-07-27

**Issue**: Still getting generic titles derived from rule/agent names (e.g., "Neovim Config Agent Guide") instead of titles that describe the actual user request.

The patch and config override are in place but the LLM title prompt is not sufficiently filtering out rule/instruction context. The title generation is picking up the agent/rule name from the injected context rather than the user's actual question.

- [x] Strengthen the title generation prompt to explicitly exclude rule/agent/instruction names
- [x] Test the patched generator with `<rules>` and `<help>` context metadata;
      the adapter-stub regression proves only the user request reaches the
      initial and refresh prompts.
- [x] Confirm `TitleGenerator:relevant_messages()` no longer leaks tagged v19
      metadata/context into the prompt.
- [x] Run one user-owned actual-model smoke chat to evaluate the returned title's
      semantics; the automated test deliberately does not send an authenticated
      title request.

## Review Feedback — 2026-08-30

**Issue**: Two live saved chats produced weak titles that the previous filter
layer did not prevent:

1. `Chat Title Request` - a greeting-only chat (first real user message was
   `hi`). The model described the title-generation task itself instead of the
   (nonexistent) topic.
2. `File Operations Tool Access` - the user's first real message was
   `@{read_file} @{file_search} @{grep_search} @{files} #{buffer}` + `Hi`.
   CodeCompanion expands `@{tool}`/`@{group}`/`#{buffer}` references into
   prose inside the submitted user message (`Tools:replace`), so the message
   carried `the <tool> tool` fragments, the `files` group prompt ("I'm giving
   you access to ... tools to help you perform file operations"), and the
   buffer note ("file `path` (with buffer number: N)"). Those are a genuine
   user message (`visible=true`, no tag/context id) and legitimately pass the
   message filter; the model then titled the boilerplate.

### Root cause

- Case 1 is a degenerate-input failure: no topical content exists to title.
- Case 2 is a content-level failure: picker-expanded annotations dominate the
  only real user message, and the message-level filter cannot see inside
  message content.

### Fix (two layers, both amended into the v1 patch + config)

- [x] Layer 1 (patch, deterministic) in
      [01-title-prompt-v1.patch](patches/codecompanion-history.nvim/01-title-prompt-v1.patch):
      - Exclude hidden (`visible = false`) context lines even without a tag or
        context id (v19 sets `visible=false` on every injected context line).
      - New `strip_picker_annotations()` removes tool replacement text, tool-group
        prompts, and buffer notes from user message content. It reads the live
        `codecompanion.config.interactions.chat.tools` templates, so it follows
        config changes. It only replaces content when the remainder is trivial
        (empty or at most two words), so real requests that merely mention tools
        keep their full text.
- [x] Layer 2 (config, model-side fallback) in
      [myCodecomp.lua](lua/plugins/extra/myCodecomp.lua): the custom
      `title_generation_opts.prompt` now ignores tool-access boilerplate and
      attachment notes, includes a few-shot greeting example so greeting-only
      chats are titled naturally (for example "Greeting"), and forbids
      describing the title request itself (the source of `Chat Title Request`).

### Verification

- [x] Regression test extended to 25 assertions: hidden context lines, trivial
      remainder stripping, and the non-trivial keep-original guard are all
      covered with the adapter stub.
- [x] Actual-model A/B against the AGD proxy (`gpt-4.1-mini`, `temperature=0`)
      using the exact prompts emitted by the patched generator for the two real
      saved chats:
      - `Chat Title Request` -> `Casual Greeting`
      - `File Operations Tool Access` -> `Casual Greeting`
      - sanity check with a real request -> `Fix macOS Lazy Sync Error`
      Greeting-only chats are titled as greetings by the model (few-shot
      steers behavior, it does not force a fixed string); tool and rules
      boilerplate never becomes the topic.
- [x] Patch still applies cleanly to the pinned `bc1b4fe` and round-trips
      byte-identical to the live worktree diff.

## References

- [CodeCompanion history config](lua/plugins/extra/myCodecomp.lua:634)
- `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion-history.nvim/lua/codecompanion/_extensions/history/title_generator.lua`
- `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion-history.nvim/lua/codecompanion/_extensions/history/init.lua`
- `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/interactions/background/builtin/chat_make_title.lua`
- `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/config.lua`
