# mcphub.nvim patches

Patch files are applied in filename order by `lazy-local-patcher` against the pinned plugin checkout (`163b3ad`). The 2026-09-29 consolidation folded related follow-ups into 03, 08, and 11. Eleven patches now produce the same Lua tree as the former 01–15 stack, plus the new Hub Build feature in 16.

**Application order** (required):
```bash
git apply --ignore-space-change 01-compat_v1.patch
git apply --ignore-space-change 02-hub-stability_v1.patch
git apply --ignore-space-change 03-main-ui_v3.patch
git apply --ignore-space-change 04-clear-auth_v1.patch
git apply --ignore-space-change 05-stdio-auth-command_v1.patch
git apply --ignore-space-change 06-instruction-files_v1.patch
git apply --ignore-space-change 07-codecompanion-resource-refresh_v1.patch
git apply --ignore-space-change 08-agent-settings_v2.patch
git apply --ignore-space-change 11-startup-guards_v2.patch
git apply --ignore-space-change 15-avante-lazy-startup_v1.patch
git apply --ignore-space-change 16-hub-build-info_v1.patch
```

`02` adds hub/main context required by `03`; `04` and `05` use the final `03` key dispatch. `08` uses the final main-view folding behavior, `11` follows the completed Agents view, and `15` keeps optional Avante loading out of startup. `16` adds the Help → Hub Build tab and requires a hub with `/api/build-info` for full details; older hubs show an in-tab fallback. The fork now has clear-auth and stdio-auth committed, so external server patches 03/04 are historical, not prerequisites to reapply to its current tip.

To change an existing group, reproduce the stack in a disposable checkout, generate a new grouped patch, and verify both forward and reverse application. Never flatten the entire stack into one patch: the groups retain independent feature/rollback boundaries.

---

## 08-agent-settings_v2.patch

Combines the former 08–10 Agent settings sequence into one final-state patch.
`Z` opens the dedicated Agents view; `gS` cycles User, Local, and Full scope.
Agent roots, setup/config files, and skills appear in foldable groups with
`h`/`l` and `z` folds. `y` copies paths, `e` opens the in-place file editor,
`I` saves and opens the edited file, and `l` opens a concrete path in Neovim.
Discovery uses configured local paths only, not agent CLI calls. Folding and
editing no longer pass through the obsolete intermediate main-view dashboard.

**Files**: `lua/mcphub/config.lua`, `lua/mcphub/ui/init.lua`,
`lua/mcphub/ui/views/agent_settings.lua`, `lua/mcphub/ui/views/main.lua`,
`lua/mcphub/utils/text.lua`, `lua/mcphub/utils/ui.lua`

---

## 11-startup-guards_v2.patch

Combines the former 11–14 startup race fixes. The first health probe follows
the resolved workspace port, retries through hub setup, and transfers an
in-flight probe to a newer generation. Automatic mismatch discovery stays
non-interactive; only explicit `R` can request a restart confirmation.
Initial context resolution does not launch a second hub start. SSE jobs and
recovery callbacks are generation-fenced so an old context cannot reset a
newer connection.

**Files**: `lua/mcphub/config.lua`, `lua/mcphub/hub.lua`, `lua/mcphub/ui/init.lua`

---

## 15-avante-lazy-startup_v1.patch

MCPHub previously loaded Avante synchronously while setting up slash commands.
An Avante build requiring a newer Neovim can block in `vim.fn.getchar()`, leaving
the first Hub window at `Starting...` until a key is consumed and its `quit`
closes the float.

- Subscribe to MCP server and prompt updates without loading Avante.
- Register slash commands immediately if Avante is already loaded, or after
  lazy.nvim reports that Avante has loaded.
- Keep the Hub connection path independent of the optional integration.

**Files**: `lua/mcphub/extensions/avante/init.lua`,
`lua/mcphub/extensions/avante/slash_commands.lua`

---

## 16-hub-build-info_v1.patch

Help has a **Hub Build** sub-tab beside the plugin **Changelog**. It fetches
`/api/build-info` once per attached hub/port/PID, caches the result in
`mcphub.state`, and shares it with the Home status row. Home shows the running
version, commit/date, and binary path. Hub Build shows the release tag commit
date and each listed commit's date, plus capabilities, patch manifest, and
runtime paths. `X` on Home or Hub Build confirms and sends a deliberate stop request;
the client suppresses automatic reconnect until an explicit `R` restart. The
main dashboard's server-row `x` clears OAuth credentials; tool-row `x` keeps
strict-hide behavior. Server hover hints show `x` clear-auth; native rows
omit clear-auth. Global `X` stop appears in the Home footer, not server hints. A 404 from an
older hub is shown without a global error; the plugin changelog stays separate.

**Files**: `lua/mcphub/hub.lua`, `lua/mcphub/state.lua`,
`lua/mcphub/ui/build_info.lua`, `lua/mcphub/ui/views/help.lua`,
`lua/mcphub/ui/views/main.lua`, `lua/mcphub/utils/renderer.lua`

---

## 01-compat_v1.patch

Upstream compatibility fixes. No shared files with other groups; safe to apply independently.

- Updates CodeCompanion extension glue for v19 behavior — keeps MCPHub tool/resource/prompt integration stable after upstream API changes. Rebased after the v6.2.0-era patch stopped applying atomically.
- Fixes startup health checks treating compatible `mcp-hub` patch versions as mismatches. Reuses `validation.validate_version()` for the existing hub's `/api/health` version instead of exact string equality, so a running `4.2.1` hub is not hard-restarted when the plugin requires `4.2.0`.

**Files**: `lua/mcphub/extensions/codecompanion/` (core, init, slash_commands, tools, variables), `lua/mcphub/hub.lua`

---

## 02-hub-stability_v1.patch

Hub lifecycle hardening. Contains env-tool-filters which is the root dependency for `03-main-ui_v3`.

- **Env-driven tool filters** — adds `*_ALLOWED_TOOLS_REGEX` / `*_DENIED_TOOLS_REGEX` env var support per server config. Adds strict hide via `removed_tools` blocking tool execution. Adds UI action key `x` for strict-hide toggling on tool rows.
- **Log dedup/throttle** — deduplicates repeated server log entries; throttles UI notification updates to avoid freezes during disconnect/reconnect bursts.
- **Confirm hard-restart** — adds `confirm_hard_restart = true`; startup config/cache mismatch paths default to connecting the existing hub instead of replacing it. Manual `R` is explicit intent and skips the prompt.
- **Workspace switch debounce** — debounces `MCPHub:handle_directory_change` by `shutdown_delay` ms client-side. A timer cancels pending switches if `cwd` returns to the original workspace before it fires. Falls back to immediate switch when `shutdown_delay <= 0`. Timer is cancelled in `_clean_up()`.
- **UI context reconcile on open** — on `:MCPHub` open, re-resolves workspace context and switches the connected hub if `cwd` now points to a different port. Cancels any pending debounce timer so the two don't race. Uses `MCPHub:start()`'s fast path (short-circuits to `connect_sse()` when the target port is already up).

**Files**: `lua/mcphub/hub.lua`, `lua/mcphub/state.lua`, `lua/mcphub/utils/handlers.lua`, `lua/mcphub/ui/init.lua`, `lua/mcphub/config.lua`

---

## 03-main-ui_v3.patch

Main-view UI work. Depends on `02-hub-stability_v1` for hub.lua and main.lua context.

- **Config defaults** — adds `ui.endpoints`, `ui.agent_registry`, `ui.input_navigation`, and `ui.token_counts`. Active capability form navigation defaults to `J` next field and `K` previous field.
- **Multi-server expansion** — replaces the single `expanded_server` field with an `expanded_servers` set. Multiple connected servers can remain expanded at once. `h` on an expanded server collapses only that server; `h` inside an expanded server section collapses the owning server; `h` on an already-collapsed connected server row collapses all expanded servers.
- **Section navigation/folding** — adds `collapsed_sections`, `J/K` section-header navigation, and `T` toggle-all for foldable sections. MCP Servers is a navigation anchor; Global/Project groups, Native Servers, Endpoints, CLI Agents, and Active Hubs are foldable.
- **Endpoints panel** — shows `/mcp` and `/mcp-lean` endpoint rows with inspector/register/unregister/copy actions.
- **CLI Agents panel** — shows configured agent profile bindings by endpoint, with add/remove/toggle/refresh/edit actions and alternate config targets. Claude bindings are resolved by user/project config scope; non-scoped CLIs render as `global` to avoid projecting one flat list into multiple scopes.
- **Context-aware dispatch and copy actions** — keeps endpoint/agent row actions separate from default server/tool/native actions, and adds copy helpers for browse rows and active capability payload/result rows.
- **Strict-hidden tools in the main view** — adds `x` on tool rows to toggle `removed_tools`. Removed tools render in the error style, sort after disabled tools, cannot be opened, cannot be auto-approved, and cannot be toggled with the regular `t` handler until restored with `x`.
- **Capability summaries and token estimates** — server rows show token estimates before active-only capability summaries using the same capability icons as expanded sections, for example `(<tool icon> 3, <prompt icon> 2, <resource icon> 1, <template icon> 1)`. Expanded capability section headers show enabled/total counts. Server and tool token estimates respect disabled/removed/env-regex filters.
- **SSE recovery** — recovers transient SSE disconnects by probing the existing hub before tearing down state.
- **Deduped log badge rendering** — repeated log entries with `entry.count > 1` display a muted `xN` suffix in server entry rendering.

**Files**: `lua/mcphub/config.lua`, `lua/mcphub/hub.lua`, `lua/mcphub/ui/init.lua`, `lua/mcphub/ui/views/main.lua`, `lua/mcphub/ui/capabilities/`, `lua/mcphub/utils/renderer.lua`

---

### Included startup dashboard changes (formerly `03-main-ui_v2`)

These changes are folded into `03-main-ui_v3.patch`; there is no separate follow-up patch.

- **Stable startup dashboard** — from `setup_state = in_progress` onward, the
  main view renders the server, Endpoints, CLI Agents, and workspace sections.
  A fixed hub-state row says `Starting...`, `Setting up MCPHub`, or the partial
  server/tool count while the connection settles. Live logs belong only to `L`,
  so startup no longer swaps the dashboard for a variable-length log buffer.
  Logs and server-output notifications redraw only the Logs view.
- **Early server snapshots** — when the UI opens before the hub exists or is
  ready, it retries `GET /api/health` up to 30 times at 500 ms while the UI
  remains visible. The retry survives the asynchronous `State.hub_instance`
  handoff and makes one health read around `READY`, whose event can precede the
  hub's regular server update. A changed read, or the first successful read in
  a probe generation, schedules an in-place redraw; that covers an unchanged
  snapshot after a missed notification without redrawing every 500 ms retry.
  This exposes a completed connection and its tool count as soon as the backend
  has created its connection object, without waiting for every configured server
  or the global `READY` event. Use `l` to expand that row for tool names. A
  generation guard stops stale retries after close or context switch.
- **In-place state redraws** — a burst of server/setup notifications queues one
  redraw for the current event-loop turn. Once the UI is visible, that redraw
  calls the already-active view directly instead of re-entering/leaving the
  same view, so it does not recreate mappings or cursor handlers. The main view
  anchors selectable server, section, endpoint, workspace, instructions, and
  agent rows by semantic identity; if a row moves when a new status arrives,
  the cursor follows it. If the row disappeared, the existing numeric fallback
  remains in effect.
- **Boundary** — this is an observability/UI improvement only: it does not
  change backend readiness, force a capability refresh, or make a connecting
  server executable before its MCP initialization completes.

**Files**: `lua/mcphub/ui/init.lua`, `lua/mcphub/ui/views/main.lua`

---

---

## 04-clear-auth_v1.patch

Depends on `03-main-ui_v3` for keymap dispatch infrastructure. Requires a
hub binary with `/servers/clear-auth`; the current fork has this committed.
Falls back to file-edit via `utils.mcphub_auth` when the endpoint is absent.

- **`lua/mcphub/hub.lua`** — `MCPHub:clear_server_auth(name, cb)`: calls `POST /servers/clear-auth`; notifies on success; passes `(false, err)` to callback for fallback handling.
- **`lua/mcphub/ui/views/main.lua`** — `MainView:handle_clear_auth(context)`: API path → on error falls back to `utils.mcphub_auth.clear_notify` by URL; patch 16 assigns this to `x` on server rows (`X` stops the hub).
- **`lua/mcphub/utils/renderer.lua`** — introduces the clear-auth hover hint; patch 16 shows `<x> Clear auth` on all non-native server rows.

Also: `lua/utils/mcphub_auth.lua` (project-local helper) updated to try API path before file-edit.

**Server build dependency**: requires a hub with clear-auth support. Without it,
`X` falls back to the file-edit path, which still needs manual `R` to flush in-memory state.

**Files**: `lua/mcphub/hub.lua`, `lua/mcphub/ui/views/main.lua`, `lua/mcphub/utils/renderer.lua`

---

## 05-stdio-auth-command_v1.patch

Depends on `03-main-ui_v3` for the server-row action flow. The current fork
has stdio `authCommand` support committed; older binaries need that capability
for `/servers/authorize` to launch the configured command.

- **`lua/mcphub/ui/views/main.lua`** — `l` on an unauthorized server row now accepts either an HTTP `authorizationUrl` or a stdio `authCommand`; only HTTP auth opens the callback popup.
- **`lua/mcphub/hub.lua`** — `authorize_mcp_server` reports command-based auth launches instead of warning that no URL exists.
- **`lua/mcphub/types.lua`** — documents optional `authCommand` server metadata.

**Server build dependency**: requires a hub with stdio-auth-command support.
Without it, the UI can call `/servers/authorize`, but stdio auth-required rows
will not expose or launch an auth command.

**Files**: `lua/mcphub/hub.lua`, `lua/mcphub/types.lua`, `lua/mcphub/ui/views/main.lua`

---

## 06-instruction-files_v1.patch

Adds external markdown files to per-server custom instructions without changing
the mcp-hub backend or the external server config.

- **Schema** — `custom_instructions.files` is an array of non-empty paths;
  `custom_instructions.max_bytes` is an optional positive integer. File-backed
  configs default to 8192 bytes per server; legacy inline-only configs remain
  uncapped unless `max_bytes` is explicitly set.
- **Resolution** — expands `~`/environment references and resolves relative
  paths from the directory containing the server's active config source.
- **Prompt merge** — keeps inline `text` first, then appends readable files in
  declaration order with blank-line separators. The byte cap covers the combined
  body, including separators, so inline content has deterministic priority.
  Truncation backs up to a complete UTF-8 codepoint and never exceeds the
  configured byte budget.
- **Resilience/cache** — missing or unreadable files warn once per unchanged
  server/path failure and do not abort prompt generation. Read-error dedup uses
  a stable metadata signature rather than volatile OS error text. File reads are
  bounded to the current content budget plus one overflow byte. Cached prefixes
  record both the file metadata signature and requested limit, grow only when a
  larger overflowing prefix is requested, and refresh when metadata changes.
- **Validation/token counts** — validates `disabled`, `text`, `files`, and
  `max_bytes`. Existing server token estimates already call
  `prompt.server_to_text()`, so file-backed instructions are counted without a
  second renderer implementation. Expanded sections and connected-server rows
  also recognize a non-empty `files` list as configured instructions.

The patch only affects prompts assembled by mcphub.nvim (including the current
CodeCompanion extension, guide/preview output, and MCPHub UI token estimates).
It does not inject instructions into raw external clients connected directly to
the mcp-hub `/mcp` endpoint.

**Server build dependency**: none. This is a Neovim plugin patch only.

**Files**: `lua/mcphub/utils/prompt.lua`, `lua/mcphub/utils/renderer.lua`, `lua/mcphub/utils/validation.lua`, `lua/mcphub/types.lua`

---

## 07-codecompanion-resource-refresh_v1.patch

CodeCompanion snapshots editor context when a chat opens, while its completion
provider caches the shared context list. A later `resource_list_changed` event
previously refreshed only global config and syntax, leaving an existing chat
unable to resolve newly registered MCP resources.

The patch updates MCP entries in every open chat's context, preserves non-MCP
chat-local entries, and invalidates CodeCompanion completion through the paired
[`patches/codecompanion.nvim/01-editor-context-refresh_v1.patch`](../codecompanion.nvim/01-editor-context-refresh_v1.patch).

**Files**: `lua/mcphub/extensions/codecompanion/variables.lua`

---

## Validation note

- A disposable checkout at `163b3ad` applied the consolidated 01–16 stack in filename order, matched the expected final Lua tree, and reversed to clean. `git diff --check` and Lua parsing passed. This validates patch content and order, not a future Lazy lifecycle run. `01` must retain the `init.lua` `strategies` to `interactions` conversion; without it the CodeCompanion v19 extension fails during startup.
- `git apply --check` with multiple patch files can be misleading here; validate by applying each patch one at a time in a temporary worktree.
- If `lazy-local-patcher` shows both `Applied ...` and `Error applying ...`, inspect the plugin checkout first. `restore_all()` restores files to the checkout's current `HEAD`; if `HEAD` is a leftover local patch-baseline commit instead of the lockfile commit, early patches may already be in `HEAD` and fail when reapplied.

## User notes

Historical follow-up requirements for the former `03-main-ui_v1.patch` review are tracked in
[reconcile-mcphub-03-main-ui-patch](../../tasks/open/reconcile-mcphub-03-main-ui-patch.md).

Historical notes from the earlier larger main-UI patch:

Fix
- [ ]
- [ ] error and unauth server show as enabled — make clear distinction in the response?

Added requirements
- [ ] be able to check mcp-lean tools from UI
  - Current low-risk path: `e` on `/mcp-lean` opens MCP Inspector with proxy auth token attached.
  - Native execution inside MCPHub UI would need a separate endpoint-client capability view.
- [x] Add UI command to open/close the npx inspector web UI to check on each endpoint
  - `e` on endpoint row launches inspector + opens browser; `s` stops it
- [x] Single key to reset stale OAuth client_id from the MCPHub main view
  - `X` on an unauthorized server row: clears in-memory + file state, disconnects, no hard-restart needed
