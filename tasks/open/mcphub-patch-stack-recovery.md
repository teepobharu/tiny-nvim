---
title: "Make MCPHub patch restore/apply repeatable across Lazy cycles"
status: open
priority: high
created: 2026-09-29
updated: 2026-09-29
refs:
  - mcphub.nvim 163b3ad [tag:v6.2.0] @2025-07-31 chore(release)
  - 0bdaeff @2026-09-26 fix(mcphub): recover startup patch stack
related:
  - [Patch lifecycle notes](docs/memory/lazy-local-patching.md)
  - [MCPHub patch catalog](patches/mcphub.nvim/README.md)
  - [Neovim 0.12 plugin rollout](tasks/open/neovim-012-plugin-upgrade-rollout/README.md)
---

## Objective

Prevent a Lazy check/sync/update from leaving the MCPHub checkout with an untracked patch-created file and only some of patches 09/10 applied. Keep unrelated user changes safe and make errors identify the first failing patch instead of continuing into a mixed stack.

## Evidence and current recovery

- The 2026-09-29 patch consolidation replaced 03 v1/v2 with `03-main-ui_v3`, 08–10 with `08-agent-settings_v2`, and 11–14 with `11-startup-guards_v2`. A clean disposable checkout produced the same final Lua tree and reversed all patches cleanly; this reduces intermediate patch-created-file churn but does **not** prove Lazy's own restore/apply lifecycle is fixed.

- The 2026-09-29 03:31 notifications reported 09 and 10 failed while 01–08 and 11–15 applied. The installed plugin remained at pinned `163b3ad`, not a newer upstream checkout.
- `git apply --check` for 09 failed because `lua/mcphub/ui/views/agent_settings.lua` already existed. That untracked file had a 03:09 timestamp, whereas the tracked files were reapplied at 03:31. Patch 10 then failed because 09's tracked-file changes were absent.
- A disposable checkout of `163b3ad` applied 01–15 in filename order and reversed 15–01 cleanly. Therefore the patch contents and pinned base are valid.
- After backing up the live checkout and confirming the stale file matched the clean full-stack output, that file was removed and 09/10 were applied in order. The live MCPHub Lua tree then matched the disposable full stack byte-for-byte. Headless MCPHub opened and switched to `agent_settings` successfully.
- The original unpatched `lazy-local-patcher` implementation uses `git restore .`, which leaves untracked files. The locally patched implementation reverses patches, but we have **not** proved which implementation or Lazy event path ran before 03:31. Treat a self-update/nested-event explanation as a hypothesis, not a confirmed cause.

## Implementation plan

- [ ] Build a disposable test around `lazy-local-patcher` that starts from a clean MCPHub checkout, applies the current consolidated stack, runs the same restore/apply lifecycle twice, and checks exact clean/full-stack states, including removal of patch-created files.
- [ ] Reproduce the former partial 09/10 state (or equivalent failure in the consolidated Agents patch) and identify whether a plugin self-update, nested `LazyCheck`/`LazySync` event, or manual apply path bypasses the patched restoration guard.
- [ ] Make the patcher fail fast per plugin repository and avoid reporting later patches as applied after a failed earlier patch. If the old module can load during its own update, move the safety guard to a stable config-owned bootstrap or otherwise eliminate the self-patching gap.
- [ ] Re-run the fixture on the patched plugin checkout and the isolated `nvimwt3a` profile before testing a controlled main-profile Lazy operation. Do not use `git restore .` or delete unverified user changes.
- [ ] Record the proven lifecycle cause and durable fix in [patch lifecycle notes](docs/memory/lazy-local-patching.md); keep the patch catalog order aligned.

## Success criteria

- Two consecutive isolated Lazy patch cycles finish with all MCPHub patches present, no Agents-patch errors, and no leftover untracked patch-created file after restoration.
- A forced failure at patch 08 leaves no silently mixed state and reports the actionable cause.
- Main-profile MCPHub remains byte-equivalent to the clean consolidated stack and opens its Agents view without errors.
- Unrelated local or profile-owned edits remain intact.

## Verification

### How to verify

First run the disposable fixture and isolated profile. Only after those pass, restart the main profile and perform a controlled Lazy check; avoid a blanket plugin update while this task is open.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

```vim
:Lazy check
:MCPHub
" In the MCPHub window:
" press Z, then use j/l/h/e/I on an agent settings item
```

### Checklist

- [ ] Repeating `:Lazy check` does not show any MCPHub patch-apply or restore error.
- [ ] MCPHub opens on the first attempt and its Agents view shows populated user-level settings.
- [ ] Folding/navigation and edit-popup keys operate without closing the main UI unexpectedly.
- [ ] The installed MCPHub checkout matches the expected consolidated patch stack; a disposable restore leaves a clean checkout.

## References

- [Consolidated Agents patch](patches/mcphub.nvim/08-agent-settings_v2.patch)
- [Reversible-restoration patch](patches/lazy-local-patcher.nvim/01-reversible-stack-restore_v1.patch)
- [Agent settings review task](tasks/review/mcphub-ai-agent-settings-dashboard.md)
