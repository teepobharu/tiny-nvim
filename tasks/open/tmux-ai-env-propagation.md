---
title: "Fix tmux AI env propagation for fzf Ctrl-V Neovim"
status: open
priority: medium
created: 2026-06-08
updated: 2026-07-02
related:
  - "tmux config: ~/dotfiles/.tmux.conf"
  - [Sidekick config](lua/plugins/extra/myAi.lua)
  - [CodeCompanion AGD adapters](lua/utils/my_codecompanion_utils.lua)
  - "Claude AGD wrapper: ~/dotfiles/ai/claude/cc-agd/cag.sh"
  - "Codex AGD wrapper: ~/dotfiles/ai/codex/codex-agd.sh"
---

## Objective

Fix cases where Neovim opened from fzf Ctrl-V inside tmux cannot use CodeCompanion, Claude Code, or sidekick AGD tools because the process is missing Agoda AI environment variables.

## Context

The observed CodeCompanion error was:

```text
curl: (6) Could not resolve host: AG_OPENAIPROXY
```

Headless verification showed CodeCompanion resolves the AGD adapter correctly when `AG_OPENAIPROXY` is present:

```text
url=http://openai-proxy.agoda.is
```

When `AG_OPENAIPROXY` is absent from the Neovim process, CodeCompanion keeps the literal string:

```text
url=AG_OPENAIPROXY
```

That makes the model fetch call target `AG_OPENAIPROXY/v1/models`, which curl treats as a hostname.

Relevant paths:

- fzf Ctrl-V binding: `.bash_fzf_opts`
- tmux nvim reuse/fallback helper: `scripts/everything.fzf/helpers/fzf-tmux-nvim.sh`
- CodeCompanion AGD adapter: `lua/utils/my_codecompanion_utils.lua`
- sidekick common env table: `lua/plugins/extra/myAi.lua`
- Claude AGD sidekick tool: `lua/plugins/extra/myAi.lua`
- Claude AGD wrapper: `ai/claude/cc-agd/cag.sh`
- Codex AGD wrapper with env loader reference: `ai/codex/codex-agd.sh`

## Implementation Plan

- [x] First try tmux `update-environment` so new sessions import AI env vars from the attaching client.
- [x] Verify whether new tmux panes and direct `tmux split-window nvim` inherit `DOTFILES_DIR`, `AG_OPENAIPROXY`, and token aliases.
- [x] Verify login shell startup order: inherited tmux env is available before shell rc files, then `~/.bash.local` can override values if it exports them.
- [ ] If tmux-only propagation is insufficient, add Neovim-side fallbacks:
  - Use `vim.env.DOTFILES_DIR or vim.fn.expand("~/dotfiles")` for sidekick `cag.sh`.
  - Use `vim.env.AG_OPENAIPROXY or "http://openai-proxy.agoda.is"` for CodeCompanion adapter URLs.
  - Use `vim.env.OPENAI_API_KEY or vim.env.GENAIAG` for sidekick env.
- [ ] Consider adding `load_agoda_env` to `ai/claude/cc-agd/cag.sh`, mirroring `ai/codex/codex-agd.sh`.

## Verification Notes

2026-06-08:

- `tmux source-file /Users/tharutaipree/dotfiles/.tmux.conf` succeeds after fixing two pre-existing reload blockers:
  - `manpage_copy_cmd_full` changed to the valid user option `@manpage_copy_cmd_full`.
  - local config sourcing split into `source-file ~/.tmux.local.conf` and a separate `display-message`.
- Active tmux server now reports `update-environment` with:
  - `DOTFILES_DIR`
  - `AG_OPENAIPROXY`
  - `OPENAI_BASE_URL`
  - `GENAIAG`
  - `OPENAI_API_KEY`
  - `ANTHROPIC_AUTH_TOKEN`
- Isolated tmux test with dummy values confirmed:
  - direct tmux commands inherit client-imported values from `update-environment`;
  - bash login shell startup can override those inherited values from `~/.bash.local` when it exports the same names;
  - names not overridden by shell startup remain from tmux.
- Follow-up finding: direct shell `fzfs` works because the current shell has already sourced token env, but `M-t` -> `f` runs from tmux `display-popup`:
  - previous command: `EVERYTHING_FZF_TMUX_TARGET_PANE=#{pane_id} bash "#{@dotfiles_dir}/scripts/everything.fzf/fzfinit.sh"`
  - that path is a non-login bash launched from tmux server env, so it can miss `GENAIAG`, `OPENAI_API_KEY`, and `AG_OPENAIPROXY`.
  - changed the menu to call `scripts/tmux/tmux-fzfinit-popup.sh`, which sources `.bash_exports` and `~/.bash.local`, applies AGD env defaults, then launches `fzfinit.sh`.

## Action Items

- [ ] Re-run the tmux environment commands in a fresh tmux server and a reused tmux server.
- [ ] Test the actual `M-t` -> `f` -> fzf Ctrl-V path, not only direct shell `fzfs`.
- [ ] Add Neovim-side env fallbacks only if tmux and popup wrapper propagation still miss required values.
- [ ] If `cag.sh` still lacks env backfill, mirror the `load_agoda_env` behavior from `~/dotfiles/ai/codex/codex-agd.sh`.

## Points to Confirm

- [ ] Confirm whether tmux popup workflows are required to work without restarting the tmux server.
- [ ] Confirm whether AGD defaults such as `http://openai-proxy.agoda.is` are acceptable as fallback literals in Neovim config.
- [ ] Confirm which token env vars should be considered canonical: `GENAIAG`, `OPENAI_API_KEY`, or both.

## Success Criteria

- Neovim opened via fzf Ctrl-V inside tmux resolves CodeCompanion AGD URL to `http://openai-proxy.agoda.is`, not literal `AG_OPENAIPROXY`.
- sidekick can launch `claude_Agd` without failing because `DOTFILES_DIR` is nil.
- `cag.sh` and Codex/Claude sidekick tools receive the expected AI env vars in new tmux panes.
- No secrets are committed into tracked config files.

## Verification

### How to verify

Reload tmux config, open a new tmux pane/session from a shell that has `~/.bash.local` sourced, then start Neovim from that new pane.

### Commands

```bash
tmux source-file ~/.tmux.conf
tmux show -gqv update-environment
tmux show-environment -g | rg '^(DOTFILES_DIR|AG_OPENAIPROXY|OPENAI_BASE_URL|GENAIAG|OPENAI_API_KEY|ANTHROPIC_AUTH_TOKEN)='
```

```bash
NVIM_APPNAME=nvim3_jelly_tinynvim nvim --headless +'lua local cc=require("utils.my_codecompanion_utils").get_agoda_adapters(true).openai_agd(); local a=require("codecompanion.adapters").resolve(cc); require("codecompanion.utils.adapters").get_env_vars(a,{timeout=1000}); print("url=" .. tostring(a.env_replaced.url));' +qa
```

Expected output:

```text
url=http://openai-proxy.agoda.is
```

### Checklist

- [ ] New tmux sessions import the AI env vars from the attaching client.
- [ ] `~/.bash.local` overrides inherited tmux env values when it exports the same names.
- [ ] fzf Ctrl-V opened Neovim can fetch CodeCompanion AGD models.
- [ ] sidekick `claude_Agd` starts without a missing `DOTFILES_DIR` path.

## References

- `tmux show -gqv update-environment`
- `.bash_profile` sources `.bash_exports`, then `.bash.local`
- `ai/codex/codex-agd.sh` has `load_agoda_env` backfill behavior
