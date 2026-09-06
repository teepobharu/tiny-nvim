# mcphub.nvim patches

Patch files are applied in order by `lazy-local-patcher`. Seven grouped patch files cover all local changes against the pinned plugin checkout (`163b3ad`).

**Application order** (required):
```bash
git apply --ignore-space-change 01-compat_v1.patch
git apply --ignore-space-change 02-hub-stability_v1.patch
git apply --ignore-space-change 03-main-ui_v1.patch
git apply --ignore-space-change 04-clear-auth_v1.patch
git apply --ignore-space-change 05-stdio-auth-command_v1.patch
git apply --ignore-space-change 06-instruction-files_v1.patch
git apply --ignore-space-change 07-codecompanion-resource-refresh_v1.patch
```

`02` must precede `03` — env-tool-filters (in `02`) adds hub.lua and main.lua context that `03` depends on.
`04` depends on `03` for the keymap dispatch infrastructure in main.lua.
`05` depends on `03` and requires mcp-hub fork patch `external-patches/mcp-hub/04-stdio-auth-command.patch`.
`06` is a Neovim-only prompt/config patch and must remain after `05` in the sorted local patch stack.
`07` is applied after `06` and requires the paired CodeCompanion completion-cache patch.

To add a new patch on top, apply all groups first, make changes, then `git diff HEAD -- <files>`. Save as a new `_v2` file rather than overwriting `_v1`.

---

## 01-compat_v1.patch

Upstream compatibility fixes. No shared files with other groups; safe to apply independently.

- Updates CodeCompanion extension glue for v19 behavior — keeps MCPHub tool/resource/prompt integration stable after upstream API changes. Rebased after the v6.2.0-era patch stopped applying atomically.
- Fixes startup health checks treating compatible `mcp-hub` patch versions as mismatches. Reuses `validation.validate_version()` for the existing hub's `/api/health` version instead of exact string equality, so a running `4.2.1` hub is not hard-restarted when the plugin requires `4.2.0`.

**Files**: `lua/mcphub/extensions/codecompanion/` (core, init, slash_commands, tools, variables), `lua/mcphub/hub.lua`

---

## 02-hub-stability_v1.patch

Hub lifecycle hardening. Contains env-tool-filters which is the root dependency for `03-main-ui_v1`.

- **Env-driven tool filters** — adds `*_ALLOWED_TOOLS_REGEX` / `*_DENIED_TOOLS_REGEX` env var support per server config. Adds strict hide via `removed_tools` blocking tool execution. Adds UI action key `x` for strict-hide toggling on tool rows.
- **Log dedup/throttle** — deduplicates repeated server log entries; throttles UI notification updates to avoid freezes during disconnect/reconnect bursts.
- **Confirm hard-restart** — adds `confirm_hard_restart = true`; startup config/cache mismatch paths default to connecting the existing hub instead of replacing it. Manual `R` is explicit intent and skips the prompt.
- **Workspace switch debounce** — debounces `MCPHub:handle_directory_change` by `shutdown_delay` ms client-side. A timer cancels pending switches if `cwd` returns to the original workspace before it fires. Falls back to immediate switch when `shutdown_delay <= 0`. Timer is cancelled in `_clean_up()`.
- **UI context reconcile on open** — on `:MCPHub` open, re-resolves workspace context and switches the connected hub if `cwd` now points to a different port. Cancels any pending debounce timer so the two don't race. Uses `MCPHub:start()`'s fast path (short-circuits to `connect_sse()` when the target port is already up).

**Files**: `lua/mcphub/hub.lua`, `lua/mcphub/state.lua`, `lua/mcphub/utils/handlers.lua`, `lua/mcphub/ui/init.lua`, `lua/mcphub/config.lua`

---

## 03-main-ui_v1.patch

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

---

## 04-clear-auth_v1.patch

Depends on `03-main-ui_v1` for keymap dispatch infrastructure. Requires mcp-hub fork
`external-patches/mcp-hub/03-clear-auth-endpoint.patch` applied and rebuilt for the
API path to work. Falls back to file-edit via `utils.mcphub_auth` when the endpoint
is absent (bundled mcp-hub without the fork patch).

- **`lua/mcphub/hub.lua`** — `MCPHub:clear_server_auth(name, cb)`: calls `POST /servers/clear-auth`; notifies on success; passes `(false, err)` to callback for fallback handling.
- **`lua/mcphub/ui/views/main.lua`** — `MainView:handle_clear_auth(context)`: API path → on error falls back to `utils.mcphub_auth.clear_notify` by URL; `X` keymap on server rows dispatches here.
- **`lua/mcphub/utils/renderer.lua`** — adds `<X> Clear auth` to the hover hint for `unauthorized` server rows.

Also: `lua/utils/mcphub_auth.lua` (project-local helper) updated to try API path before file-edit.

**Server build dependency**: requires mcp-hub fork with `external-patches/mcp-hub/03-clear-auth-endpoint.patch` applied and rebuilt. Without it, `X` falls back to the file-edit path which still needs manual `R` to flush in-memory state.

**Files**: `lua/mcphub/hub.lua`, `lua/mcphub/ui/views/main.lua`, `lua/mcphub/utils/renderer.lua`

---

## 05-stdio-auth-command_v1.patch

Depends on `03-main-ui_v1` for the server-row action flow. Requires mcp-hub fork
`external-patches/mcp-hub/04-stdio-auth-command.patch` so `/servers/authorize`
can launch a configured stdio `authCommand`.

- **`lua/mcphub/ui/views/main.lua`** — `l` on an unauthorized server row now accepts either an HTTP `authorizationUrl` or a stdio `authCommand`; only HTTP auth opens the callback popup.
- **`lua/mcphub/hub.lua`** — `authorize_mcp_server` reports command-based auth launches instead of warning that no URL exists.
- **`lua/mcphub/types.lua`** — documents optional `authCommand` server metadata.

**Server build dependency**: requires mcp-hub fork patch `04-stdio-auth-command.patch` applied and rebuilt. Without it, the UI can call `/servers/authorize`, but stdio auth-required rows will not expose or launch an auth command.

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

- Current repair on 2026-09-04 confirms a fresh sequential apply of `01 -> 02 -> 03 -> 04 -> 05 -> 06 -> 07` from clean `163b3ad` passes. `01` must retain the `init.lua` `strategies` to `interactions` conversion; without it the CodeCompanion v19 extension fails during startup.
- `git apply --check` with multiple patch files can be misleading here; validate by applying each patch one at a time in a temporary worktree.
- If `lazy-local-patcher` shows both `Applied ...` and `Error applying ...`, inspect the plugin checkout first. `restore_all()` restores files to the checkout's current `HEAD`; if `HEAD` is a leftover local patch-baseline commit instead of the lockfile commit, early patches may already be in `HEAD` and fail when reapplied.

## User notes

Current follow-up requirements for the `03-main-ui_v1.patch` review are tracked in
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
