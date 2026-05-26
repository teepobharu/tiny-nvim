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
| 1   | `patches/mcphub.nvim/01-codecompanion-v19-compat.patch` | `mcphub.nvim` | `v6.2.0` (`163b3ad`) | 2026-03-21 | CodeCompanion v19 renamed `variables` → `editor_context`, changed tool/image APIs | [PR #279](https://github.com/ravitemer/mcphub.nvim/pull/279) — Open |
| 6   | `patches/mcphub.nvim/06-compatible-health-version-check.patch` | `mcphub.nvim` | `v6.2.0` (`163b3ad`) | 2026-05-21 | Existing hub health check treated compatible patch versions as mismatch and triggered hard restart | Local |
| 7   | `patches/mcphub.nvim/07-confirm-hard-restart.patch` | `mcphub.nvim` | `v6.2.0` (`163b3ad`) | 2026-05-21 | Automatic startup mismatch hard restart could happen without confirmation | Local |
| 8   | `patches/mcphub.nvim/08-main-view-keymap-dispatch.patch` | `mcphub.nvim` | `v6.2.0` (`163b3ad`) | 2026-05-22 | Patch 05 cursor-line mappings deleted normal `e`/`t` server/tool actions | Local |
| 9   | `patches/mcphub.nvim/09-endpoint-inspector-auth-copy.patch` | `mcphub.nvim` | `v6.2.0` (`163b3ad`) | 2026-05-22 | Endpoint inspector auth URL plus `y`/`Y` copy actions for MCP rows | Local |
| 10  | `patches/mcphub.nvim/10-configurable-agent-profiles.patch` | `mcphub.nvim` | `v6.2.0` (`163b3ad`) | 2026-05-22 | CLI agent registry supports preset-backed profiles such as `claude-agd` | Local |
| 11  | `patches/mcphub.nvim/11-copy-payload-token-counts.patch` | `mcphub.nvim` | `v6.2.0` (`163b3ad`) | 2026-05-22 | Active tool copy payload/result lines and server/tool token estimates | Local |

### Patch 1: mcphub.nvim CodeCompanion v19 compatibility

**Problem**: CodeCompanion v19 introduced breaking API changes that mcphub.nvim's extension hasn't adapted to yet. Upstream [PR #279](https://github.com/ravitemer/mcphub.nvim/pull/279) by bahaaza provides the fix but is unmerged.

Test if mcp works with this chat message (before patch it will not call mcp tool + show error variables null when toggle chat + type something)
test message: @{mcp} what's available mcp

**What the patch changes** (4 files):

| File                                          | Change                                                                                                                                                         |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `extensions/codecompanion/variables.lua`      | `config.strategies.chat.variables` → editor context registration; use `(config.strategies.shared and config.strategies.shared.editor_context) or config.strategies.chat.editor_context` for compatibility |
| `extensions/codecompanion/tools.lua`          | Tool `callback` from table → function; `cmds` handler signature `(agent, args, _, output_handler)` → `(self, action, opts)`; `system_prompt` signature updated |
| `extensions/codecompanion/core.lua`           | Output handler signature `(self, agent, cmd, data)` → `(self, data, meta)`; `helpers.add_image()` → `chat:add_image_message()`                                 |
| `extensions/codecompanion/slash_commands.lua` | Remove `id` field from registrations; cleanup by key prefix; image helper update                                                                               |

**Config change**: CodeCompanion is pinned to exact `v19.6.0` (`af7f1042a424e17ab49cef93442f33a55d514de6`) in [lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua).

**v19.6.0 note**: CodeCompanion moved chat editor context modules under `strategies.shared.editor_context` and merges any user `strategies.chat.editor_context` overrides into that shared table. If mcphub writes MCP resources back into only `config.strategies.chat.editor_context`, CodeCompanion can later try resolving stale paths. Use a compatibility fallback so the same patch works on both paths.

**Monitor task**: [tasks/open/monitor-mcphub-pr279-merge.md](tasks/open/monitor-mcphub-pr279-merge.md) — once PR #279 is merged upstream, remove this patch.

### Patch 6: mcphub.nvim compatible health version check

**Problem**: `setup()` validates the selected `mcp-hub` executable with
semver-compatible logic, so required `4.2.0` accepts installed `4.2.1`. Later,
`MCPHub:check_server()` compared `/api/health.version` with exact string
equality against `REQUIRED_NODE_VERSION.string`, so a second Neovim instance
could see the already-running compatible hub as a mismatch and post
`/api/hard-restart`.

**Fix**: Use `validation.validate_version(response.version)` in
`check_server()` and remove the direct `version.REQUIRED_NODE_VERSION.string`
comparison.

### Patch 7: mcphub.nvim hard restart confirmation

**Problem**: Startup config/cache mismatch paths could post `/api/hard-restart`
immediately, disconnecting other Neovim or CLI clients on the same hub without
explicit user intent.

**Fix**: Add `confirm_hard_restart = true` and prompt before automatic startup
mismatch hard restarts. Config/cache mismatch prompts default to connecting to
the existing hub; version mismatch prompts default to cancel. Manual `R` is
explicit user intent and does not prompt.

### Patch 8: mcphub.nvim main-view keymap dispatch

**Problem**: Patch 05 used cursor-line buffer-local mappings for endpoint and
agent rows. It deleted `e`, `t`, `d`, `a`, `A`, `r`, and `R` on every cursor
move, then recreated them only on endpoint/agent rows. That broke normal
server/tool/native-server actions such as `t` toggle and `e` edit; `l` still
worked because it was not deleted.

**Fix**: Keep core browse-mode keymaps registered and dispatch by current row
type. Endpoint-only actions (`s`, `i`, `u`, `y`) are also silent row-aware
main-view mappings, so cursor movement no longer deletes keymaps.

**Server build dependency**: none. This is a Neovim plugin patch only.

### Patch 9: mcphub.nvim endpoint inspector auth and copy actions

**Problem**: Endpoint `E` duplicated config editing already available through
the config view, MCP Inspector 0.21+ needs `MCP_PROXY_AUTH_TOKEN` in the browser
URL, and main-view MCP rows had no copy action for names or full tool paths.

**Fix**: Remove endpoint `E`, keep `e` for Inspector, add `y` for row names and
`Y` for full paths such as `servername_toolname`, and update hover hints.
The companion local helper [lua/utils/mcp_inspector.lua](lua/utils/mcp_inspector.lua)
honors an existing `MCP_PROXY_AUTH_TOKEN` or creates
`~/.config/mcp-inspector/proxy-token`, starts Inspector with that token, disables
Inspector auto-open, and attaches `MCP_PROXY_AUTH_TOKEN=<token>` to the URL.

**Server build dependency**: none. This is client/UI plus local helper behavior
only.

**Suggested commit title**: `mcphub: auth inspector endpoint links and add copy actions`.

### Patch 10: mcphub.nvim configurable CLI agent profiles

**Problem**: The CLI Agents panel keyed rows by executable name, so a second
Claude profile could not be listed or updated independently. Endpoint-row
register/unregister also hardcoded `claude` user scope.

**Fix**: Normalize agent config records into preset-backed profiles. The old
`{ name = "claude" }` format still works, while explicit profiles can set
`id`, `preset`, `command`, `config_dir`, `config_path`, and per-profile `scopes`.
For Claude profiles with `config_dir`, [lua/utils/mcphub_agents.lua](lua/utils/mcphub_agents.lua)
runs `claude mcp ...` with `CLAUDE_CONFIG_DIR=<config_dir>`. Endpoint rows now
use `ui.agent_registry.default_agent_id` and `default_scope`.

**Configured local profile**: `claude-agd` uses
`/Users/tharutaipree/.claude-agd` and opens
`/Users/tharutaipree/.claude-agd/settings.json` from `e`.

**Server build dependency**: none. This is client/UI plus local helper behavior
only.

**Suggested commit title**: `mcphub: support configurable CLI agent profiles`.

### Patch 11: mcphub.nvim copy active payloads and show token estimates

**Problem**: Browse-mode `y` copied MCP row names, but active tool forms could
not copy the current input, submit payload, or result text line. MCPHub also
only exposed one aggregate prompt token estimate, making server/tool-level cost
hard to inspect.

**Fix**: Route `y` in active capability mode through the active handler. Tool
and prompt input rows copy their current value; submit rows copy the JSON form
payload without running validation first; rendered result text lines are tracked
and copy the whole current result. Tool values are schema-converted when valid
and left raw when invalid. Server and expanded tool rows show approximate `~Nt`
counts, controlled by `ui.token_counts`; server counts filter out
`disabled_tools`, `removed_tools`, and env regex-denied tools.

**Server build dependency**: none. This is client/UI behavior only.

**Suggested commit title**: `mcphub: copy active payloads and show token estimates`.

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

**Last Updated**: 2026-03-21
