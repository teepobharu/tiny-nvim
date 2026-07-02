---
title: "Reconcile MCPHub 03 main UI patch ownership"
status: "open"
priority: "high"
created: 2026-07-02
updated: 2026-07-02
refs:
  - 163b3ad [tag:v6.2.0] chore(release): v6.2.0
related:
  - [Patch catalog](patches/mcphub.nvim/README.md)
  - [03 main UI patch](patches/mcphub.nvim/03-main-ui_v1.patch)
  - [02 hub stability patch](patches/mcphub.nvim/02-hub-stability_v1.patch)
  - [MCPHub memory](docs/memory/mcphub.md)
---

## Objective

Reconcile `03-main-ui_v1.patch` so it contains only the main-view behavior that belongs in patch group 03 and applies cleanly after `01-compat_v1.patch` and `02-hub-stability_v1.patch`.

## Context

Initial review found that `03-main-ui_v1.patch` was smaller than the older README description and duplicated changes already owned by `02-hub-stability_v1.patch`.

Observed duplicated or overlapping areas:

- `confirm_hard_restart` default is added by both `02` and `03`.
- Strict-hidden tool UI plumbing (`x`, `handle_removed_tool_toggle`, `context.removed`) appears in both `02` and `03`.
- Renderer tool-filter helpers and removed/disabled sorting appear in both `02` and `03`.

Before regeneration, sequential application from clean `163b3ad` applied `01` and `02`, then `03` failed at:

- `lua/mcphub/config.lua`
- `lua/mcphub/ui/views/main.lua`
- `lua/mcphub/utils/renderer.lua`

The repo already has older notes and memory docs for a broader `03` scope, including:

- `ui.endpoints`, `ui.agent_registry`, `ui.input_navigation`, and `ui.token_counts` config sections.
- Browse-mode section folding and section-to-section jump navigation.
- Endpoints and CLI Agents panels in the main MCPHub UI.
- Active capability field navigation in tool/prompt forms.
- Copy/yank helpers, inspector helpers, and endpoint register/unregister actions.
- Richer capability summaries on server rows and expanded capability sections.

The regenerated patch now restores that broader scope while keeping `03` based on the `01+02` patch state.

Patch regeneration status:

- `03-main-ui_v1.patch` was regenerated from an `01+02` baseline.
- `04-clear-auth_v1.patch` was regenerated against the new `03` baseline after the review fixes.
- Fresh sequential apply of `01 -> 02 -> 03 -> 04` from clean `163b3ad` passes.
- Lua syntax checks pass for the touched MCPHub Lua files in the verification worktree.
- `git diff --check` passes in the full applied verification worktree.
- Review agent `Hilbert` found no issues against the requested requirements and also verified sequential patch application plus `git diff --check`. Manual `:MCPHub` UI interaction tests were not run.

## Current Uncommitted 03 Change List

- Config defaults for `ui.endpoints`, `ui.agent_registry`, `ui.input_navigation`, and `ui.token_counts`.
- Active capability input navigation defaults to `J/K`.
- Multi-server expansion using `expanded_servers` instead of one `expanded_server`.
- `h` collapse behavior for server rows and nested capability rows.
- Browse-mode `J/K` section navigation and `T` fold toggle behavior.
- Endpoints panel and CLI Agents panel rendering/actions.
- Context-aware dispatch for endpoint rows, agent rows, server rows, and capability rows.
- Copy/yank helpers for browse rows and active capability payload/result rows.
- Strict-hide guardrails for removed tools: no open, no auto-approve, no regular toggle.
- `x` key for strict-hide toggle via `removed_tools`.
- Tool-filter-aware active server counts, expanded section counts, and auto-approve counts.
- Server and tool prompt-token estimates after filters.
- SSE recovery for transient disconnects.
- Repeated log entry count badge in renderer output.

## Expected 03 Scope

Expected config changes in `lua/mcphub/config.lua`:

- Keep `confirm_hard_restart = true`.
- Add `ui.endpoints` toggle.
- Add `ui.agent_registry` with default agent/scope and built-in profiles for `claude`, `codex`, and `opencode`.
- Keep `ui.input_navigation`, but change the expected active-capability defaults from `<C-j>/<C-k>` to `J/K`.
- Keep `ui.token_counts` toggles for global, server, and tool display.

Expected `lua/mcphub/ui/views/main.lua` behavior:

- Replace single `expanded_server` with `expanded_servers`, so expanding one server never collapses another expanded server.
- Add `collapsed_sections = {}` and section fold helpers.
- `J/K` in browse mode jump between section headers.
- `J/K` in active capability mode move between input fields / submit row.
- `T` toggles all foldable sections.
- `h` on an expanded server row collapses only that server.
- `h` inside an expanded server's capability rows collapses the owning server and returns cursor to the server row.
- `h` on an already-collapsed connected server row collapses all other expanded servers.
- Add Endpoints and CLI Agents panels.
- Restore context-aware key dispatch for endpoint rows, agent rows, and normal server/tool rows.
- Keep `x` strict-hide and `X` clear-auth actions.
- Allow `<l>` on disconnected servers to reconnect.
- Keep inspector helpers, endpoint register/unregister helpers, config-open helpers, and yank helpers in scope.

Expected `lua/mcphub/utils/renderer.lua` behavior:

- Keep tool regex filters, removed-tool rendering, and token estimates.
- Restore compact active-only capability summary on each server row, using full labels like `(tool: X, prompt: Y, resource: Z)` rather than enabled/total counts.
- In expanded server view, show enabled/total count hints next to each capability section header for tools, prompts, resources, and resource templates where applicable.
- Keep section folding markers and log dedup count badges.

## Restored In Current Patch

- [x] `ui.endpoints` config block.
- [x] `ui.agent_registry` config block.
- [x] `ui.input_navigation` defaults using `J/K` instead of `<C-j>/<C-k>`.
- [x] Browse-mode `J/K` section navigation.
- [x] `collapsed_sections` and fold/unfold state.
- [x] `T` toggle-all-sections behavior.
- [x] Multi-server expanded state where expanding server B leaves server A expanded.
- [x] Explicit extra-`h` collapse-all behavior from an already-collapsed connected server row.
- [x] Endpoints panel rendering.
- [x] CLI Agents panel rendering.
- [x] Server token estimate renders before the server-line capability summary.
- [x] Compact server-line capability summary uses active-only counts like `(tool: X, prompt: Y, resource: Z)`.
- [x] Expanded section-header enabled/total count hints for tools/prompts/resources/resource templates.
- [x] Active capability `J/K` focus movement.
- [x] Active capability `J/K` keymaps are no longer overwritten by browse-mode section navigation.
- [x] Section headers are tracked on their rendered lines, not the preceding line.
- [x] Expanded capability section headers are tracked as `J/K` navigation anchors.
- [x] CLI Agent rows avoid duplicating one unscoped list result into both user/project scopes.

## Requirements

- [x] Decide patch ownership: keep strict-hide and `confirm_hard_restart` in `02`, and keep broader main UI behavior in `03`.
- [x] Remove duplicated hunks from `03-main-ui_v1.patch` after ownership is decided.
- [x] Keep `03` documentation in [patches/mcphub.nvim/README.md](patches/mcphub.nvim/README.md) aligned with the exact patch contents.
- [x] Preserve the broader expected `03` scope from existing notes/docs.
- [x] Verify `01 -> 02 -> 03 -> 04` applies through real sequential `git apply`, not only combined `git apply --check`.
- [x] Restore `ui.input_navigation` in `03` with `J/K` defaults for active capability field navigation.
- [x] Restore browse-mode `J/K` section-header navigation and `T` section fold toggling.
- [x] Restore Endpoints and CLI Agents panels.
- [ ] Verify `:MCPHub` main view still shows strict-hidden tools distinctly after patch ownership changes.
- [x] Enforce true multi-server expanded state: expanding a second connected server must not collapse the first.
- [x] Add explicit `h` collapse semantics: expanded server row collapses itself; capability rows collapse their owning server; already-collapsed connected server row collapses all expanded servers.
- [x] Restore a compact capability summary on each server row in the user's requested active-only form, for example `(tool: X, prompt: Y, resource: Z)`, instead of showing enabled/total counts.
- [x] Restore enabled/total count hints on expanded capability section headers for tools, prompts, resources, and resource templates.
- [x] Ensure active-capability `J/K` works for any capability form that exposes input/submit rows, not only tools.
- [x] Ensure browse-mode `J/K` and `T` keymaps are registered only outside active capability mode.
- [x] Ensure `04-clear-auth_v1.patch` still applies after the regenerated `03-main-ui_v1.patch`.
- [ ] Verify multi-server expansion/collapse works with at least two connected MCP servers.
- [ ] Verify server tool counts and token estimates respect disabled, removed, allowed-regex, and denied-regex filters.

## Implementation Plan

- [x] Phase 1: Reconcile patch ownership between `02-hub-stability_v1.patch` and `03-main-ui_v1.patch`.
  Decide whether `confirm_hard_restart`, strict-hide handlers, and renderer tool-filter helpers stay in `02` or move fully into `03`, then remove duplicated hunks so sequential apply works again.
- [x] Phase 2: Restore `03` config and main-view behavior.
  Bring back `ui.endpoints`, `ui.agent_registry`, `ui.input_navigation`, and `ui.token_counts` config blocks if `03` still owns them. Restore true multi-server expansion, explicit `h` collapse semantics, browse-mode `J/K` section jumps, `T` fold toggling, active-capability `J/K` field navigation, Endpoints panel, CLI Agents panel, and context-aware key dispatch.
- [x] Phase 3: Restore renderer-level summaries and hints.
  Bring back compact server-row capability indicators in the requested active-only form like `(tool: X, prompt: Y, resource: Z)` and show enabled/total counts beside expanded capability section headers for tools, prompts, resources, and resource templates.
- [ ] Phase 4: Align docs and verify behavior.
  Update [patches/mcphub.nvim/README.md](patches/mcphub.nvim/README.md) to match the final patch contents, then validate real sequential `git apply` and manual MCPHub UI behavior in `NVIM_APPNAME=nvimwt3a`. README, patch apply, `git diff --check`, and Lua syntax validation are done; manual UI verification remains.

## Success Criteria

- `03-main-ui_v1.patch` applies cleanly after `01-compat_v1.patch` and `02-hub-stability_v1.patch`, and before `04-clear-auth_v1.patch`, from clean `163b3ad`.
- The final `03` patch scope is unambiguous: no duplicated ownership with `02`, and the README description matches the patch contents.
- Expanding a second connected server leaves the first connected server expanded.
- Pressing `h` on an expanded server row collapses only that server.
- Pressing `h` inside an expanded server's capability rows collapses that owning server.
- Pressing `h` on an already-collapsed connected server row collapses all other expanded servers.
- Active capability navigation uses `J/K` as expected.
- Browse-mode section navigation and folding work as expected if they remain part of `03`.
- Server rows show compact active-only capability summaries in the requested full-label form.
- Expanded capability sections show enabled/total count hints.
- Endpoints and CLI Agents panels are either restored in `03` or explicitly moved to another patch with docs updated to reflect that split.

## Follow-Up Plan: `<C-r>` Refresh

If a dedicated refresh key is still needed after manual UI testing:

- Add `<C-r>` as a browse-mode alias for the existing row-aware refresh path.
- Keep `r` behavior unchanged so endpoint rows can continue using `r` for register.
- Do not register `<C-r>` in active capability mode, where form input/navigation should remain isolated.
- Update hover hints only where the extra refresh key is actually useful.

## Verification

### How to verify

Use a temporary worktree of `ravitemer/mcphub.nvim` at `163b3ad`, then apply patches one at a time in the documented order. After patch application succeeds, open the worktree Neovim profile and manually test the main view.

### Commands

```bash
tmpdir="$(mktemp -d /tmp/mcphub-patchcheck.XXXXXX)"
git -C ~/.local/share/nvimwt3a/lazy/mcphub.nvim worktree add --detach "$tmpdir" 163b3ad
git -C "$tmpdir" apply --ignore-space-change ~/dotfiles/.config/nvimwt3a/patches/mcphub.nvim/01-compat_v1.patch
git -C "$tmpdir" apply --ignore-space-change ~/dotfiles/.config/nvimwt3a/patches/mcphub.nvim/02-hub-stability_v1.patch
git -C "$tmpdir" apply --ignore-space-change ~/dotfiles/.config/nvimwt3a/patches/mcphub.nvim/03-main-ui_v1.patch
git -C "$tmpdir" apply --ignore-space-change ~/dotfiles/.config/nvimwt3a/patches/mcphub.nvim/04-clear-auth_v1.patch
git -C "$tmpdir" diff --check
luac -p \
  "$tmpdir"/lua/mcphub/config.lua \
  "$tmpdir"/lua/mcphub/hub.lua \
  "$tmpdir"/lua/mcphub/ui/capabilities/base.lua \
  "$tmpdir"/lua/mcphub/ui/capabilities/prompt.lua \
  "$tmpdir"/lua/mcphub/ui/capabilities/resource.lua \
  "$tmpdir"/lua/mcphub/ui/capabilities/resourceTemplate.lua \
  "$tmpdir"/lua/mcphub/ui/capabilities/tool.lua \
  "$tmpdir"/lua/mcphub/ui/init.lua \
  "$tmpdir"/lua/mcphub/ui/views/main.lua \
  "$tmpdir"/lua/mcphub/utils/renderer.lua
git -C ~/.local/share/nvimwt3a/lazy/mcphub.nvim worktree remove "$tmpdir"
```

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
:MCPHub
```

### Checklist

- [x] All four patch files apply sequentially without patch failures.
- [x] `git diff --check` passes after all four patches are applied.
- [x] `luac -p` passes for the touched MCPHub Lua files after all four patches are applied.
- [ ] `:MCPHub` opens without Lua errors.
- [ ] Expanding server A, then expanding server B, leaves both server A and server B expanded.
- [ ] Pressing `h` on expanded server A collapses only server A while server B stays expanded.
- [ ] Pressing `h` inside server B's tool/resource/prompt section collapses server B and returns cursor to server B's row.
- [ ] Pressing `h` on an already-collapsed connected server row collapses all other expanded servers.
- [ ] In active capability mode, `J` moves to the next input/submit row and `K` moves to the previous row.
- [ ] In browse mode, `J/K` jump between section headers and `T` collapses/expands all foldable sections.
- [ ] Endpoints and CLI Agents panels render when enabled.
- [ ] Pressing `x` on a tool marks it strict-hidden and writes the tool name under `removed_tools`.
- [ ] Strict-hidden tools are visually distinct from disabled tools and cannot be opened, auto-approved, or toggled with `t`.
- [ ] Server rows show the token estimate before a compact multi-capability summary like `(tool: X, prompt: Y, resource: Z)`.
- [ ] Expanded capability section headers show enabled/total counts for tools, prompts, resources, and resource templates where applicable.
- [ ] Server tool counts decrease when tools are disabled, strict-hidden, or filtered by allow/deny regex.
- [ ] Server token estimates stay visible when `ui.token_counts` is unset or enabled, and disappear when disabled.

## References

- [Patch catalog](patches/mcphub.nvim/README.md)
- [03 main UI patch](patches/mcphub.nvim/03-main-ui_v1.patch)
- [02 hub stability patch](patches/mcphub.nvim/02-hub-stability_v1.patch)
