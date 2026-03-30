---
title: "Verify CodeCompanion inline adapter/model behavior and debug instrumentation"
status: review
priority: high
created: 2026-03-28
updated: 2026-03-28
refs:
  - af7f1042a424e17ab49cef93442f33a55d514de6 [tag:v19.6.0] @2026-03-18 22:43:09 +0000 chore(main): release 19.6.0 (#2900)
related:
  - [CodeCompanion config](lua/plugins/extra/myAi.lua)
  - [Inline debug demo module](lua/utils/my_codecompanion_inline_debug_demo.lua)
  - [CodeCompanion memory](docs/memory/codecompanion.md)
---

## Objective

Cross-check whether inline supports `adapter=` + `model=` in the prompt, add explicit debug instrumentation, and provide a reproducible verification flow.

## Context

Cross-check against installed CodeCompanion `v19.6.0` shows:

- Inline docs mention `adapter=*` for `:CodeCompanion` and do not document inline `model=*`. (which is not seem to support)
- Inline parser only parses `adapter=` in `codecompanion/interactions/inline/init.lua` (`parse_special_syntax`).
- Chat explicitly parses `adapter=`, `model=`, and `command=` in `codecompanion/commands/init.lua` (`CodeCompanionChat` command).

Implication:

- `:CodeCompanion adapter=openai_agd model=notexisting ...` does **not** validate or apply `model` by default in inline; `model=...` is treated as prompt text unless patched.

## Desired behavior
Make sure leader-A-M want behavior to be same as running inline like vim command and 
It should just work in the active buffer to show inline hunk suggestion.
Do not want to open chat when select the model to be used inline 
Do not open the chat buffer and insert selected code and prompt into chat buffer 

Sample desire output should be like when I do this
1. visual select focus code 
2. type Codecompanion and prompt 
3. yield :'<,'>Codecompanion prompt 
4. hit enter
5. wat a while 
6. saw hunk changes in active buffer
7. accept with g1 key



## Try check

```lua
-- __AUTO_GENERATED_PRINT_VAR_START__


print([==[ require("codecompanion.config"):]==], vim.inspect(require("codecompanion.config").config.adapters.http))

require("codecompanion").setup(vim.tbl_deep_extend("keep", { opts = { log_level = "DEBUG" } }, { opts = require("codecompanion.config").config) }

```
:CodeCompanion adapter=openai_agd model=notexisting fix bad sh code

:CodeCompanionChat adapter=openai_agd model=claude-3-5-haiku fix bad sh code

run below to see model not actually work
:CodeCompanion adapter=openai_agd model=echohelloand fix bad sh code


Trim log files date < 1month period

Format: 
```log
Output data:
data: {"choices":[{"index":0,"content_filter_offsets":{"check_offset":69257,"start_offset":69364,"end_offset":69465},"content_filter_results":{"hate":{"filtered":false,"severity":"safe"},"self_harm":{"filtered":false,"severity":"safe"},"sexual":{"filtered":false,"severity":"safe"},"violence":{"filtered":false,"severity":"safe"}},"delta":{"content":" "}}],"created":1765206224,"id":"chatcmpl-CkX44PlOf1yCHNAGfuiISLTft58DV","model":"gpt-4.1-2025-04-14","system_fingerprint":"fp_ffd5ba9d2e"}
[DEBUG] 2025-12-08 22:03:54
Output data:
data: {"choices":[{"index":0,"content_filter_offsets":{"check_offset":69257,"start_offset":69364,"end_offset":69465},"content_filter_results":{"hate":{"filtered":false,"severity":"safe"},"self_harm":{"filtered":false,"severity":"safe"},"sexual":{"filtered":false,"severity":"safe"},"violence":{"filtered":false,"severity":"safe"}},"delta":{"content":"0"}}],"created":1765206224,"id":"chatcmpl-CkX44PlOf1yCHNAGfuiISLTft58DV","model":"gpt-4.1-2025-04-14","system_fingerprint":"fp_ffd5ba9d2e"}
[DEBUG] 2025-12-08 22:03:54
```

```sh
your_log_file= /Users/tharutaipree/.local/state/nvim3_jelly_tinynvim/codecompanion.log
your_log_file_2= /Users/tharutaipree/.local/state/nvim3_jelly_tinynvim/codecompanion2.log

awk '/^\[DEBUG/,/^\[WARNING/ { if (!/\[ERROR\]/) next } { print }' $your_log_file > $your_log_file_2
$your_log_file > $your_log_file_2
awk '/^\[DEBUG\]/ {p=0} /^\[ERROR\]/ || /^\[WARNING\]/ || /^\[INFO\]/ {p=1} p' 



```
return
```sh
listItemArray=(
  "item1"
  "item2"
  "item3"
)

for item in "${listItemArray[@]}"; do
  echo "$item"
done
```


## Implementation Plan

- [x] Verify docs + source behavior for inline and chat parsing.
- [x] Add temporary demo patch to support inline `model=` parsing and to log adapter/model at runtime.
- [x] Add explicit status command for quick debug confirmation.
- [x] Stash demo code changes so they can be reapplied safely.
- [x] Leave this task file with strategy, commands, and expected outcomes.

## Success Criteria

- Source-level cross-check is documented and reproducible.
- A debug log captures inline request events with adapter/model.
- Inline prompt with `model=...` updates the adapter model for that request in the demo patch.
- User can reapply all demo code changes from a named stash entry.

## Verification

> **REQUIRED** before moving to `completed`. Apply the stash first, then follow this checklist.

### How to verify

1. Reapply the demo stash.
2. Open Neovim with your target profile.
3. Confirm patch status command reports active.
4. Run inline with explicit `adapter=` + `model=...`.
5. Inspect debug log to confirm parsed/used model.

### Commands

```bash
# 1) Reapply ONLY the demo patch files from stash
git restore --source='stash@{0}' --worktree --staged -- \
  lua/plugins/extra/myAi.lua \
  lua/utils/my_codecompanion_inline_debug_demo.lua

# 2) Open Neovim (worktree profile recommended)
NVIM_APPNAME=nvimwt3a nvim
```

```vim
" 3) Confirm patch and log path
:CodeCompanionInlineDebugStatus

" 4) Trigger inline with explicit adapter + model
:'<,'>CodeCompanion adapter=openai_agd refactor this function
```

```bash
# 5) Inspect debug log
tail -n 80 ~/.local/state/$NVIM_APPNAME/codecompanion-inline-debug.log
```

### Checklist

- [ ] `:CodeCompanionInlineDebugStatus` reports `inline model override patch active=true`.
- [ ] Debug log contains `[InlineModelOverride] adapter=openai_agd model=notexisting`.
- [ ] Debug log contains request lifecycle lines (`CodeCompanionRequestStarted` / `Finished`) with adapter/model metadata.
- [ ] Inline command no longer leaves `model=notexisting` in the natural-language prompt content (model token is consumed by parser).
- [ ] Behavior is understood: provider may still accept/fallback/reject unknown models, but request-side model override is visible in debug log.

## References

- Stash containing demo patch: `stash@{0}` (`demo(codecompanion): inline model override + debug instrumentation`)
- Reapply only these paths from stash: `lua/plugins/extra/myAi.lua`, `lua/utils/my_codecompanion_inline_debug_demo.lua`
- `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/interactions/inline/init.lua` (`parse_special_syntax`)
- `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/commands/init.lua` (`CodeCompanionChat` argument parsing)
- `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/doc/usage/inline.md` (inline adapter usage)
