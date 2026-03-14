---
title: "Monitor mcphub.nvim PR #279 merge — remove patch when merged"
status: open
priority: low
created: 2026-03-15
updated: 2026-03-15
related:
  - [Patch task](tasks/open/patch-mcphub-codecompanion-v19.md)
  - [MCPHub config](lua/plugins/extra/myAi.lua)
  - [Upstream PR #279](https://github.com/ravitemer/mcphub.nvim/pull/279)
---

## Objective

Watch for [PR #279](https://github.com/ravitemer/mcphub.nvim/pull/279) to be
merged into `ravitemer/mcphub.nvim:main`, then remove the local patch that was
applied in the companion task so we stay on clean upstream code.

## Context

PR #279 fixes mcphub.nvim's CodeCompanion extension for v19 API compatibility.
The maintainer has not merged it yet (as of 2026-03-15). A local patch via
`lazy-local-patcher.nvim` was applied as a workaround (see companion task).

Once the fix lands upstream, the patch is no longer needed and should be
removed to avoid drift. This is a watch-and-cleanup task.

**PR to monitor**: https://github.com/ravitemer/mcphub.nvim/pull/279
**Companion patch task**: `tasks/open/patch-mcphub-codecompanion-v19.md`
(move to archive once this task is completed)

## Implementation Plan

- [ ] Periodically check PR #279 status — look for "Merged" badge on the PR page
- [ ] Once merged: run `:Lazy update mcphub.nvim` to pull latest upstream
- [ ] Remove patch files from `~/.config/nvim3_jelly_tinynvim/patches/mcphub.nvim/`
- [ ] Verify MCPHub + CodeCompanion v19 still work without patches
- [ ] If `lazy-local-patcher.nvim` is no longer needed for anything else, remove it too
- [ ] Move the companion patch task (`patch-mcphub-codecompanion-v19.md`) to `tasks/archive/`
- [ ] Move this task to `tasks/review/`

## Success Criteria

- PR #279 is merged into `ravitemer/mcphub.nvim:main`
- Local patch files for mcphub.nvim are deleted
- MCPHub integration with CodeCompanion v19 works via upstream code (no patches)
- No dirty state in Lazy for mcphub.nvim

## Verification

### How to verify

After removing patches and updating mcphub.nvim, restart Neovim and confirm
MCPHub tools/variables/slash commands still work in CodeCompanion.

### Commands

```bash
# Check PR status (requires gh CLI)
gh pr view 279 --repo ravitemer/mcphub.nvim --json state,mergedAt

# Remove patch files once merged
rm -rf ~/.config/nvim3_jelly_tinynvim/patches/mcphub.nvim/
```

```vim
" Update mcphub.nvim to latest
:Lazy update mcphub.nvim

" Confirm no patches needed and servers healthy
:MCPHub
```

### Checklist

- [ ] `gh pr view 279 --repo ravitemer/mcphub.nvim` shows `state: MERGED`
- [ ] Patch files in `patches/mcphub.nvim/` are removed
- [ ] `:Lazy update mcphub.nvim` completes cleanly (no dirty state warning)
- [ ] No startup errors after removing patches
- [ ] MCPHub tools, variables, and slash commands work in CodeCompanion chat
- [ ] Companion patch task moved to `tasks/archive/`

## References

- [Upstream PR #279](https://github.com/ravitemer/mcphub.nvim/pull/279)
- [Companion patch task](tasks/open/patch-mcphub-codecompanion-v19.md)
- [lazy-local-patcher.nvim](https://github.com/polirritmico/lazy-local-patcher.nvim)
- [MCPHub config](lua/plugins/extra/myAi.lua)
