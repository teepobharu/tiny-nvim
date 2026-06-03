# mcphub.nvim patches

Patch files are applied in numeric order by `lazy-local-patcher`.

## 01-codecompanion-v19-compat.patch

- Updates CodeCompanion extension glue for v19 behavior.
- Keeps MCPHub tool/resource/prompt integration stable after upstream API changes.

## 02-env-tool-filters.patch

- Adds env-driven tool filter support (`*_ALLOWED_TOOLS_REGEX`, `*_DENIED_TOOLS_REGEX`, etc.).
- Adds strict hide behavior via `removed_tools` and blocks removed tool execution in mcphub.nvim path.
- Adds UI action key `x` for strict hide toggling in main view tool entries.

## 03-log-dedup-throttle.patch

- Reduces log spam pressure by deduplicating repeated server log entries.
- Throttles UI notification updates to avoid freezes during disconnect/reconnect bursts.

## 04-tool-input-nav-keys.patch

- Adds configurable capability-form navigation keys for tool input fields and submit line.
- Default keys: `<C-j>` next field, `<C-k>` previous field.
- Config path:

```lua
require("mcphub").setup({
  ui = {
    input_navigation = {
      next_field = "<C-j>",
      prev_field = "<C-k>",
    },
  },
})
```

## 05-endpoints-and-agents.patch

- Adds **Endpoints panel** below MCP Servers: shows `/mcp` (flat) and `/mcp-lean` (lean) rows with hub-up status dot.
- Adds **CLI Agents panel**: shows registered bindings for each configured agent profile (claude / claude-agd / codex / opencode) × scope × endpoint target.
- **Hover-only key hints**: action hints appear as virtual-text on the cursor line only. Driven by the upstream `context.hint` / `hover_ns` mechanism — no always-visible inline text.
- **MCP Inspector integration** (endpoint rows, cursor-only):
  - `e` — launch `npx @modelcontextprotocol/inspector -y` (reuse running) and open browser at `http://localhost:6274/?transport=sse&serverUrl=<url>&MCP_PROXY_AUTH_TOKEN=<token>`
  - `s` — stop the running inspector job
  - `i` — edit `~/.config/mcp-inspector/config.json` (created as `{}` if missing)
  - Servers config remains reachable through the MCPHub config view (`C`, then `e`).
- **Toggle-and-edit pattern** (matches upstream ConfigView's `e` behavior): any config file opened by `e`/`i` calls `self.ui:toggle()` to hide the floating MCPHub window, then `:edit <path>` in the underlying window. The hub itself stays alive — only the float is hidden. Re-show with `:MCPHub` (or your `<leader>ah` keymap).
- Keys on agent rows (cursor-only, single-key — no `<leader>` prefix): `t` toggle /mcp ↔ /mcp-lean, `d` remove, `a` add lean, `A` add flat, `R` refresh, `e` edit agent config (vsplit + `<C-q>`).
- Patch 08/09 route keys through main-view dispatch instead of cursor-line key deletion. Endpoint keys: `e/s/i/r/u/y`; agent keys: `e/t/d/a/A/R`.
- Hint text is terse single-token form (`e:inspect s:stop ...`, `t:toggle d:remove e:cfg`).
- Per-agent CLI dispatch in `lua/utils/mcphub_agents.lua`: claude uses `--transport sse`, codex uses `--url` (no `--transport`), opencode returns helpful error directing to `e` for manual config edit (no CLI add). Patch 10 makes this preset/profile-aware.
- Inspector lifecycle owned by `lua/utils/mcp_inspector.lua`: start (`vim.fn.jobstart`), stop (`vim.fn.jobstop`), `is_running` check, URL builder, `vim.ui.open` for browser.
- Config paths: `ui.endpoints.enabled`, `ui.agent_registry.{enabled, agents, scopes, default_agent_id, default_scope}`.
- **Server build dependency**: `/mcp-lean` requires the local `mcp-hub` fork to
  include the lean proxy endpoint and for `~/projects/mcp-hub/dist/cli.js` to be
  rebuilt. If this patch is committed together with the server-side lean proxy,
  include that dependency in the commit title, e.g.
  `mcphub: add lean endpoint UI and rebuild local hub`.

## 06-compatible-health-version-check.patch

- Fixes startup health checks treating compatible `mcp-hub` patch versions as
  mismatches.
- Reuses `validation.validate_version()` for an existing hub's `/api/health`
  `version` instead of exact string equality with `REQUIRED_NODE_VERSION.string`.
- Prevents a second Neovim instance from hard-restarting a compatible existing
  hub such as `4.2.1` when the plugin's required string is `4.2.0`.

## 07-confirm-hard-restart.patch

- Adds `confirm_hard_restart = true` and asks before posting
  `/api/hard-restart` from automatic startup mismatch paths.
- Startup config/cache mismatch cases default to connecting to the existing hub
  instead of replacing it.
- Manual `R` is explicit user intent and does not show the confirmation popup.
- Client-side patch; no `mcp-hub` server rebuild is required.

## 08-main-view-keymap-dispatch.patch

- Fixes a regression from patch 05 where cursor-line remapping deleted core
  browse-mode mappings (`e`, `t`, `d`, `a`, `A`, `r`, `R`) on non endpoint/agent
  rows.
- Keeps normal server/tool/native actions working, including `t` toggle and `e`
  edit, while still routing endpoint/agent rows to their special actions.
- Removes cursor-move key deletion entirely for these actions; endpoint-only
  keys are silent row-aware mappings owned by the main view.
- Client-side patch; no `mcp-hub` server rebuild is required.

## 09-endpoint-inspector-auth-copy.patch

- Removes endpoint `E` because endpoint config editing is already reachable through the MCPHub config view (`C`, then `e`).
- Keeps endpoint `e` focused on opening MCP Inspector.
- Adds `y` and `Y` copy actions:
  - Endpoint row: `y` copies the endpoint URL.
  - Server row: `y` and `Y` copy the server name.
  - Tool/prompt/resource rows: `y` copies the item name/URI, `Y` copies `server_name .. "_" .. item_name`, for example `gitlab_mr_get_merge_request`.
- Updates hover hints for server/capability rows to include `y`/`Y`.
- Companion local config change in `lua/utils/mcp_inspector.lua`:
  - Honors existing `MCP_PROXY_AUTH_TOKEN`.
  - Otherwise reads or creates `~/.config/mcp-inspector/proxy-token` using `openssl rand -hex 32` when available.
  - Starts Inspector with `MCP_PROXY_AUTH_TOKEN`, `CLIENT_PORT`, `SERVER_PORT`, and `MCP_AUTO_OPEN_ENABLED=false`.
  - Opens the browser URL with `MCP_PROXY_AUTH_TOKEN=<token>` attached.
- **Server build dependency**: none. This is client/UI plus local inspector-helper behavior only.
- Suggested commit title: `mcphub: auth inspector endpoint links and add copy actions`.

## 10-configurable-agent-profiles.patch

- Makes the CLI Agents panel profile-aware instead of keying all rows by executable name.
- Keeps old config working: `{ name = "claude" }` still normalizes to the `claude` preset.
- Supports explicit profiles:

```lua
{
  id = "claude-agd",
  preset = "claude",
  label = "claude-agd",
  command = "claude",
  config_dir = "/Users/tharutaipree/.claude-agd",
  config_path = "/Users/tharutaipree/.claude-agd/settings.json",
  binding_flat = "mcphub",
  binding_lean = "mcphub-lean",
  scopes = { "user" },
}
```

- `lua/utils/mcphub_agents.lua` runs Claude profile commands with `CLAUDE_CONFIG_DIR=<config_dir>`, so list/add/remove target the alternate Claude profile.
- Endpoint row `r`/`u` now use `ui.agent_registry.default_agent_id` and `default_scope` instead of hardcoded `claude` user scope.
- `e` on a profile row opens `config_path` when configured.
- **Server build dependency**: none. This is client/UI plus local helper behavior only.
- Suggested commit title: `mcphub: support configurable CLI agent profiles`.

## 11-copy-payload-token-counts.patch

- Adds `y` inside active capability views:
  - Tool/prompt input row: copies the current field value.
  - Tool/prompt submit row: copies the JSON form payload without forcing
    validation first. Tool values are schema-converted when valid and left raw
    when invalid.
  - Text result row: copies the whole current result, not only the selected
    rendered line.
- Resource/resource-template result text lines also use the same result-line copy tracking.
- Adds approximate token estimates:
  - Connected server rows show `~Nt` for that server's generated prompt text
    after `disabled_tools`, `removed_tools`, and env regex tool filters.
  - Expanded tool rows show `~Nt` for that tool description plus input schema
    only while the tool is visible to prompts.
- Token display is controlled by:

```lua
ui = {
  token_counts = {
    enabled = true,
    servers = true,
    tools = true,
  },
}
```

- Counts use the existing approximate `utils.calculate_tokens()` helper
  (`ceil(chars / 4)`), so they are sizing hints, not model-tokenizer exact values.
- **Server build dependency**: none. This is client/UI behavior only.
- Suggested commit title: `mcphub: copy active payloads and show token estimates`.

## 12-workspace-switch-shutdown-delay.patch

- Debounces workspace hub switches in `MCPHub:handle_directory_change` by `shutdown_delay` ms (client-side).
- Previously, switching `cwd` across workspace roots immediately tore down the old hub's SSE connection and started a new hub — `shutdown_delay` was only forwarded to the mcp-hub server process, not honoured by the Neovim client.
- Now: when ports would differ, a `vim.uv.new_timer` is started for `shutdown_delay` ms. If `cwd` returns to the original workspace before the timer fires, the switch is cancelled — no churn. If the timer fires and the context still wants a different port, the switch proceeds normally.
- Timer is always cancelled in `_clean_up()` to prevent leaks on explicit stop/restart.
- Falls back to immediate switch when `shutdown_delay <= 0`.

## 13-ui-show-reconcile-context.patch

- On `:MCPHub` open, re-resolves workspace context and switches the connected hub if `cwd` now points to a different port.
- Companion to patch 12: when the debounce timer hasn't fired yet, opening the UI is treated as explicit user intent — switch immediately so the UI reflects the current workspace (or global) hub.
- Adds `UI:reconcile_context()` and a single call from `UI:show()`. No-op when `workspace.enabled = false` or when the resolved port already matches `State.current_hub.port`.
- Cancels any pending switch timer so patch 12 and patch 13 don't race.
- Uses `MCPHub:start()`'s existing fast path: when the target port is already running our server, `start()` short-circuits to `connect_sse()` — no `--shutdown-delay` of the old hub, no process spawn, no hard restart.
- Closes the gap where pressing `r` (refresh) only refreshed the workspace hub's capabilities and `R` (hard restart) was the only way to swap hubs.

## 14-sse-recovery-and-hub-fallback.patch

- Recovers from transient SSE disconnects by probing the existing hub before tearing down state.
- Reconnects SSE when the hub is still reachable instead of forcing cleanup/restart.
- Makes main-view `r` try a soft reconnect when disconnected, then falls back to normal refresh when connected.
- Client-side patch; no `mcp-hub` server rebuild is required.

## 15-agent-alternate-config-open.patch

- Extends CLI Agent rows with optional `config_alternates` targets.
- Registers each alternate target's configured `key` when it does not conflict with an existing MCPHub main-view key.
- Pressing the configured key on an agent row opens the matching alternate config and jumps to `matcher` when provided.
- Example targets:

```lua
config_alternates = {
  { key = "1", label = "settings permissions", path = "~/.claude/settings.json", matcher = ".permissions" },
  { key = "P", label = "settings permissions", path = "$HOME/.claude/settings.json", matcher = ".permissions" },
}
```

- `e` still opens the profile's main `config_path`.
- Matchers support pragmatic dot-path search for JSON/TOML/YAML plus plain-text fallback.
- For JSON, `.mcpServers` prefers the shallowest (root-level) match; nested duplicates (e.g. inside `projects[]`) are skipped.
- Path config can use `~` or `$HOME`; paths are expanded before opening.
- Cursor persists across UI toggle: `cleanup()` saves browse position via `before_leave()` so reopening the UI restores the exact line.
- Section navigation in main view browse mode:
  - `J` / `K` — jump to next / previous section header (wraps)
  - `h` / `l` on a section header line — fold / unfold the section; on any other line — original server collapse/expand behavior
  - Sections: MCP Servers, Native Servers, Endpoints, CLI Agents, Active Hubs
  - Folded sections show `[folded]` hint inline and skip rendering their content
- Client-side patch; no `mcp-hub` server rebuild is required.

## Validation note

- `04-tool-input-nav-keys.patch` was validated on a clean baseline matching this setup by applying patches `01 -> 02 -> 03` then checking `04` with `git apply --check`.
- `lazy-local-patcher` can show a contradictory notification (`Error applying...` and `Applied ...`) due notifier behavior; use manual `git apply --check` for authoritative validation.

## User notes
Fix
- [ ]
- [ ] error and unauth server show as enabled can we make clear distinction in the response ?

Added requirements
- [ ] be able to check those mcp-lean tools from UI
  - Current low-risk path: `e` on `/mcp-lean` opens MCP Inspector with proxy auth token attached.
  - Native execution inside MCPHub UI would need a separate endpoint-client capability view.
- [x] Add UI command to open/close the npx inspector web ui to check on each endpoint lean / mcp
  - `e` on endpoint row launches inspector + opens browser; `s` stops it
