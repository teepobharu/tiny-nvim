# Lazy Local Patching — Applying Upstream Fixes Before They're Merged

## Overview

[`lazy-local-patcher.nvim`](https://github.com/polirritmico/lazy-local-patcher.nvim) auto-applies git patches to Lazy-managed plugins. It hooks into Lazy's sync lifecycle: **reverts patches before git operations**, then **re-applies them after**. Between syncs, patched files persist in the plugin directory.

## Setup

**Plugin spec**: [lua/plugins/extra/myLazyPatcher.lua](lua/plugins/extra/myLazyPatcher.lua)

```lua
{
  "polirritmico/lazy-local-patcher.nvim",
  config = true,
  lazy = false, -- load early to register Lazy autocmds
}
```

**Defaults** (no custom config needed if paths are standard):

- `patches_path`: `vim.fn.stdpath("config") .. "/patches"` → `~/.config/$NVIM_APPNAME/patches/`
- `lazy_path`: `vim.fn.stdpath("data") .. "/lazy"` → `~/.local/share/$NVIM_APPNAME/lazy/`

## Patches Directory Structure

```
patches/
└── <plugin-name>/                  # must match the Lazy plugin directory name
    ├── 01-<short-description>.patch
    └── 02-<another-fix>.patch
```

Or for a single patch:

```
patches/
└── <plugin-name>.patch
```

Patches are applied in sorted order within a plugin directory.

## Current plugins status

# | name | path | latest_version | previous_latest_version | current version | updated_table_on | patch count |

## Active Patches

| #   | Patch file                                              | Plugin        | Applied on version      | Date       | Why                                                                               | Upstream                                                            |
| --- | ------------------------------------------------------- | ------------- | ----------------------- | ---------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| 1   | `patches/mcphub.nvim/01-codecompanion-v19-compat.patch` | `mcphub.nvim` | `v6.2.0-18` (`7cd5db3`) | 2026-03-16 | CodeCompanion v19 renamed `variables` → `editor_context`, changed tool/image APIs | [PR #279](https://github.com/ravitemer/mcphub.nvim/pull/279) — Open |

### Patch 1: mcphub.nvim CodeCompanion v19 compatibility

**Problem**: CodeCompanion v19 introduced breaking API changes that mcphub.nvim's extension hasn't adapted to yet. Upstream [PR #279](https://github.com/ravitemer/mcphub.nvim/pull/279) by bahaaza provides the fix but is unmerged.

Test if mcp works with this chat message (before patch it will not call mcp tool + show error variables null when toggle chat + type something)
test message: @{mcp} what's available mcp

**What the patch changes** (4 files):

| File                                          | Change                                                                                                                                                         |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `extensions/codecompanion/variables.lua`      | `config.interactions.chat.variables` → editor context registration; use `(config.interactions.shared and config.interactions.shared.editor_context) or config.interactions.chat.editor_context` for `v19.3.0`/`v19.6.0` compatibility |
| `extensions/codecompanion/tools.lua`          | Tool `callback` from table → function; `cmds` handler signature `(agent, args, _, output_handler)` → `(self, action, opts)`; `system_prompt` signature updated |
| `extensions/codecompanion/core.lua`           | Output handler signature `(self, agent, cmd, data)` → `(self, data, meta)`; `helpers.add_image()` → `chat:add_image_message()`                                 |
| `extensions/codecompanion/slash_commands.lua` | Remove `id` field from registrations; cleanup by key prefix; image helper update                                                                               |

**Config change**: CodeCompanion is pinned to exact `v19.6.0` (`af7f1042a424e17ab49cef93442f33a55d514de6`) in [lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua).

**v19.6.0 note**: CodeCompanion moved chat editor context modules under `interactions.shared.editor_context` and merges any user `interactions.chat.editor_context` overrides into that shared table. If mcphub writes MCP resources back into only `config.interactions.chat.editor_context`, CodeCompanion can later try resolving stale paths like `interactions.chat.editor_context.buffer` and fail. Use a compatibility fallback so the same patch works on both `v19.3.0` and `v19.6.0`.

**Monitor task**: [tasks/open/monitor-mcphub-pr279-merge.md](tasks/open/monitor-mcphub-pr279-merge.md) — once PR #279 is merged upstream, remove this patch.

## Lifecycle

```
Startup
  └── lazy-local-patcher.nvim loads (lazy = false)
      └── Registers autocmds for Lazy events

:Lazy sync / :Lazy update
  ├── LazySyncPre  → restore_all() — reverts all patches (git restore .)
  ├── Lazy does git pull / checkout
  └── LazySync     → apply_all()  — re-applies all patches (git apply)

Between syncs
  └── Patched files persist in ~/.local/share/$NVIM_APPNAME/lazy/<plugin>/
```

## How to Create a New Patch

### From an upstream PR diff

```bash
# Download the PR diff
curl -sL https://github.com/<owner>/<repo>/pull/<number>.diff \
  -o patches/<plugin-name>/01-<description>.patch

# Verify it applies cleanly against the installed version
git -C ~/.local/share/$NVIM_APPNAME/lazy/<plugin-name> \
  apply --check --ignore-space-change \
  ~/.config/$NVIM_APPNAME/patches/<plugin-name>/01-<description>.patch
```

### From manual edits

```bash
cd ~/.local/share/$NVIM_APPNAME/lazy/<plugin-name>
# make your edits
git diff > ~/.config/$NVIM_APPNAME/patches/<plugin-name>/01-<description>.patch
# revert the working copy (lazy-local-patcher will apply it)
git restore .
```

## How to Apply / Restore Manually

```vim
" Apply all patches now
:lua require("lazy-local-patcher").apply_all()

" Revert all patches (restore plugin repos to clean state)
:lua require("lazy-local-patcher").restore_all()
```

## How to Verify a Patch

```bash
# Dry-run check (no changes made)
git -C ~/.local/share/$NVIM_APPNAME/lazy/<plugin-name> \
  apply --check --ignore-space-change \
  ~/.config/$NVIM_APPNAME/patches/<plugin-name>/<patch>.patch

# Check if plugin repo is clean or has local changes
git -C ~/.local/share/$NVIM_APPNAME/lazy/<plugin-name> status --short
```

## Removing a Patch

When the upstream fix is merged:

1. `:Lazy update <plugin-name>` — pulls the fix
2. Delete the patch file from `patches/<plugin-name>/`
3. If no patches remain, optionally remove `lazy-local-patcher.nvim` from the plugin spec
4. Verify the plugin works without the patch
5. Update this doc — remove from the Active Patches table

## Gotchas

- **Patch applies to `stdpath("data")`**: The patch file lives in the config dir (`stdpath("config")/patches/`), but it's applied to the plugin in the data dir (`stdpath("data")/lazy/<plugin>/`). When testing in a worktree profile, both paths use the worktree's `NVIM_APPNAME`. See [nvim-worktree-testing.md](nvim-worktree-testing.md).

- **Patch may fail after plugin update**: If the upstream plugin changes the files your patch targets, the patch may no longer apply cleanly. Re-download or regenerate the patch from the latest upstream PR diff.

- **First-time application**: After installing `lazy-local-patcher.nvim` for the first time, you need to run `:Lazy sync` or `:lua require("lazy-local-patcher").apply_all()` to apply patches. They don't auto-apply on startup — they persist from the previous sync.

---

**Last Updated**: 2026-03-16
