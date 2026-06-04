# mcphub.nvim patches

Patch files are applied in order by `lazy-local-patcher`. Four grouped patch files cover all local changes against `163b3ad` (v6.2.0).

**Application order** (required):
```bash
git apply --ignore-space-change 01-compat_v1.patch
git apply --ignore-space-change 02-hub-stability_v1.patch
git apply --ignore-space-change 03-main-ui_v1.patch
git apply --ignore-space-change 04-clear-auth_v1.patch
```

`02` must precede `03` — env-tool-filters (in `02`) adds hub.lua and main.lua context that `03` depends on.
`04` depends on `03` for the keymap dispatch infrastructure in main.lua.

To add a new patch on top, apply all groups first, make changes, then `git diff HEAD -- <files>`. Save as a new `_v2` file rather than overwriting `_v1`.

---

## 01-compat_v1.patch

Upstream compatibility fixes. No shared files with other groups; safe to apply independently.

- Updates CodeCompanion extension glue for v19 behavior — keeps MCPHub tool/resource/prompt integration stable after upstream API changes.
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

All main-view UI work. Depends on `02-hub-stability_v1` for hub.lua and main.lua context.

- **Tool input navigation keys** — configurable capability-form navigation: `<C-j>` next field, `<C-k>` previous field. Config path: `ui.input_navigation.{next_field, prev_field}`.

- **Endpoints panel** — shows `/mcp` (flat) and `/mcp-lean` (lean) rows below MCP Servers with hub-up status dot. Per-row hover-only key hints via `context.hint` / `hover_ns`.
  - `e` launches `npx @modelcontextprotocol/inspector -y` (reuses running) and opens browser with proxy auth token.
  - `s` stops the inspector. `i` edits `~/.config/mcp-inspector/config.json`.
  - `y` copies the endpoint URL.

- **CLI Agents panel** — shows registered bindings for each configured agent profile × scope × endpoint. Profile-aware: `{ name = "claude" }` normalises to the `claude` preset; explicit profiles support `id`, `preset`, `label`, `command`, `config_dir`, `config_path`, `scopes`. Agent commands run with `CLAUDE_CONFIG_DIR=<config_dir>`. Row keys: `t` toggle flat↔lean, `d` remove, `a` add lean, `A` add flat, `R` refresh, `e` edit config.

- **Main-view keymap dispatch fix** — routes endpoint/agent keys through a persistent main-view dispatch instead of cursor-move key deletion, so normal server/tool/native actions (`e`, `t`, `d`, `a`, `A`, `r`, `R`) are never wiped on non-endpoint/agent rows.

- **Copy actions** — `y`/`Y` on server rows copies server name; on tool/prompt/resource rows `y` copies item name/URI, `Y` copies `server_name_item_name`. Inside capability views, `y` on input rows copies field value; on submit row copies JSON payload; on result rows copies full result text.

- **Token estimates** — server rows show `~N` / `~Nk` approximate prompt-token count after tool filters. Tool rows show per-tool estimate while visible. Controlled by `ui.token_counts.{enabled, servers, tools}`. Uses `ceil(chars / 4)` — sizing hints, not exact values.

- **SSE recovery** — recovers from transient disconnects by probing the hub before tearing down state; reconnects SSE when reachable. Main-view `r` tries soft reconnect when disconnected, falls back to hard-refresh when connected.

- **Agent alternate config targets** — `config_alternates` list on each agent profile registers extra keys (non-conflicting with existing main-view keys). Pressing the key on an agent row opens the target file and jumps to the `matcher` location.
  - Matcher: dot-path navigation for JSON/TOML/YAML, plain-text fallback. JSON prefers the shallowest (root-level) match so `.mcpServers` lands on the root key, not a nested duplicate inside `projects[]`.
  - Paths expand `~` and `$HOME`.

  ```lua
  config_alternates = {
    { key = "1", label = "perms",  path = "~/.claude/settings.json", matcher = ".permissions" },
    { key = "2", label = "c_json", path = "~/.claude.json",          matcher = ".mcpServers"  },
  }
  ```

- **Cursor persists on toggle** — `cleanup()` calls `before_leave()` before closing so browse position is saved and restored when the UI is reopened.

- **Section navigation / fold** — in main browse mode:
  - `J` / `K` — jump to next / previous section header (wraps); shown in footer.
  - `h` / `l` on a section header — fold / unfold (`▶` collapsed, `▼` open); on any other line — original server collapse/expand.
  - `T` (outside any section line) — toggle all foldable sections at once; collapses all if any are open, expands all if all are collapsed.
  - Foldable sections: Global group, Project group, Native Servers, Endpoints, CLI Agents, Active Hubs. MCP Servers is a nav anchor only (not foldable).

**Files**: `lua/mcphub/config.lua`, `lua/mcphub/ui/init.lua`, `lua/mcphub/ui/views/main.lua`, `lua/mcphub/ui/capabilities/` (base, prompt, resource, resourceTemplate, tool), `lua/mcphub/utils/renderer.lua`

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

## Validation note

- All 4 patches validated by applying in order from clean `163b3ad` (v6.2.0) with `git apply --check` then `git apply`.
- `lazy-local-patcher` can show a contradictory notification (`Error applying...` and `Applied ...`) due to notifier race behavior; use manual `git apply --check` for authoritative validation.

## User notes

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
