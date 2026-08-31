---
title: "Flexible per-model thinking control in CodeCompanion"
status: review
priority: medium
created: 2026-05-31
updated: 2026-08-27
refs:
  - eba3b42f86ed3831b1a473744e94a90d6dee4b6b [tag:v19.17.0] @2026-06-21 chore(main): release 19.17.0 (#3161)
related:
  - [Thinking controller](lua/utils/my_codecompanion_thinking.lua)
  - [AGD adapter factory](lua/utils/my_codecompanion_utils.lua)
  - [CodeCompanion config](lua/plugins/extra/myCodecomp.lua)
  - [Regression tests](tests/test_codecompanion_thinking.lua)
  - [Living memory](docs/memory/codecompanion.md)
---

## Objective

Provide optional, per-chat and per-model thinking control that works across models routed through the Agoda OpenAI-compatible proxy. It must support picker/command, editable YAML, and `/debug` changes without hard-blocking unknown models or erasing manual values.

## Why the previous implementation was replaced

CodeCompanion 19.17 has lifecycle details that made the original allowlist/gate unsafe:

- Function-valued schema `enabled` gates can permanently remove a field when settings are rendered.
- `Chat:change_model()` resets `chat.settings` to adapter defaults.
- Schema mapping does not remove an absent parameter, so a cleared effort can remain stale.
- Editable YAML is parsed after `on_submitted`; a submit callback must not rewrite settings before that parse.
- OpenAI chat-completions uses legacy flat handlers while Responses uses nested request handlers.
- Agoda metadata may report `thinkingCapability=None` while features still include `Thinking` (GPT-5.4).

The old `M.codecompanion_reasoning_models` allowlist and destructive sanitizer were removed. Capability remains advisory by default; exact endpoint/model/level probes may opt a route into strict validation while unknown models retain manual values.

## Implementation

- [x] Keep `reasoning_effort` (`openai_agd`) and `reasoning.effort` (`openai_responses_agd`) always present, optional, and unset by default; unknown models remain free-form while exact routes expose verified levels.
- [x] Clear inherited upstream `medium` defaults after adapter construction (Lua deep-merge cannot erase a parent value with `nil`).
- [x] Add `:CodeCompanionThinking`, `<leader>At`, inspect, refresh, custom values, explicit `none`, and clear/inherit.
- [x] Remember overrides per chat + adapter + model and restore them when returning to a model.
- [x] Capture same-model manual `/debug` and YAML changes while preventing model-only switches from carrying the source model's effort.
- [x] Synchronize toggle/reconcile changes to editable YAML and open debug snapshots, including while CodeCompanion temporarily locks the chat buffer.
- [x] Reset only the managed adapter parameter path before mapping to prevent stale flat/nested reasoning.
- [x] Normalize only the outgoing request copy for verified OpenAI sampling conflicts; do not mutate `chat.settings`.
- [x] Fetch detailed AGD model metadata asynchronously with a one-hour in-memory cache and static fallback hints.
- [x] Add runtime capability/profile registration and optional model-specific `request_transform` for future wire shapes.
- [x] Add isolated regression coverage for real CodeCompanion 19.17 chat lifecycle behavior.

## Agoda proxy findings (2026-07-12)

- GPT-5.4: `high`, `xhigh`, and `none` accepted; reasoning-token use changed for high/xhigh; `minimal` rejected. Non-default sampling conflicted with active effort.
- Claude Sonnet 5: flat `reasoning_effort=high` plus `temperature=0.42` and `top_p=0.8` returned HTTP 200. Acceptance is proven; effort-level differentiation was not observable in the small probe.
- Gemini 2.5 Flash: effort changed reported reasoning use. Gemini 3.5 Flash accepted the bare model ID; the preview alias failed.
- DeepSeek R1 is obligatory. o3 rejected `none`. Qwen 3.8 Chat Completions accepted `reasoning_effort=none|low|medium|xhigh` in the 2026-08-27 probe, but rejected `high` and `max`; its exact model rule hides and strips only those unsupported values.
- `/v1/responses` accepted `gpt-5.3-codex` with nested `reasoning.effort=low`.

These results guide warnings and request normalization. Unknown models and advisory capability records still pass explicit values through; strict exact-route rules reject and strip only verified-invalid values.

## Deferred follow-up

Model-selector preset entries are now generated through the shared thinking registry and apply an initial effort after model selection. Future families can extend the registry without adding adapter aliases; the current task still controls the active chat and preserves per-model values.

## Verification

### How to verify

Run the automated suite from the main repository. It loads CodeCompanion from the isolated `nvimwt3a` data profile but prepends the main tree, so it does not start or alter the daily-driver profile.

After the commit is synced/cherry-picked into the `nvimwt3a` worktree, open that profile for the manual checklist. Do not test through the active `nvim3_jelly_tinynvim` profile until the change is accepted.

### Commands

```bash
cd ~/dotfiles/.config/nvim3_jelly_tinynvim
NVIM_APPNAME=nvimwt3a nvim --headless -u NONE -i NONE \
  --cmd 'set rtp^=/Users/tharutaipree/.local/share/nvimwt3a/lazy/plenary.nvim' \
  --cmd 'set rtp^=/Users/tharutaipree/.local/share/nvimwt3a/lazy/codecompanion.nvim' \
  --cmd 'set rtp^=/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim' \
  -l tests/test_codecompanion_thinking.lua
```

Optional live metadata check (requires Agoda network/VPN):

```bash
CODECOMPANION_THINKING_LIVE=1 NVIM_APPNAME=nvimwt3a nvim --headless -u NONE -i NONE \
  --cmd 'set rtp^=/Users/tharutaipree/.local/share/nvimwt3a/lazy/plenary.nvim' \
  --cmd 'set rtp^=/Users/tharutaipree/.local/share/nvimwt3a/lazy/codecompanion.nvim' \
  --cmd 'set rtp^=/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim' \
  -l tests/test_codecompanion_thinking.lua
```

After syncing the worktree:

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
:CodeCompanionChat adapter=openai_agd model=gpt-5.4
:CodeCompanionThinking high
:CodeCompanionThinking inspect
```

### Checklist

- [ ] `<leader>At` opens a model-aware picker; custom input remains available for unknown/advisory models while strict routes show only verified levels.
- [ ] GPT-5.4 can be set to `high`; `inspect` shows the flat `reasoning_effort` field and current value.
- [ ] Switch GPT-5.4 → Claude Sonnet 5, set Claude to `low`, then switch back; GPT restores `high` and Claude restores `low`.
- [ ] In `/debug`, manually change the current effort and save; a later model switch remembers that manual value.
- [ ] A `/debug` or YAML model-only switch does not copy the source model's effort onto the target model.
- [ ] `clear` removes the override/inherits provider behavior; `none` remains a distinct explicit value.
- [ ] Qwen exposes `none`/`low`/`medium`/`xhigh` and rejects `high`/`max`; unknown models retain manual values.
- [ ] `openai_responses_agd` maps the dotted setting to nested `reasoning.effort`.
- [ ] Regular chats still submit successfully after switching models; temperature/top_p remain visible in chat settings.
- [ ] The daily-driver profile remains untouched until the user accepts and syncs the commit.

## References

- [Thinking controller](lua/utils/my_codecompanion_thinking.lua)
- [Adapter integration](lua/utils/my_codecompanion_utils.lua)
- [CodeCompanion setup/keymap](lua/plugins/extra/myCodecomp.lua)
- [Regression suite](tests/test_codecompanion_thinking.lua)
- [CodeCompanion memory](docs/memory/codecompanion.md)
- Installed source: `~/.local/share/nvimwt3a/lazy/codecompanion.nvim/`
