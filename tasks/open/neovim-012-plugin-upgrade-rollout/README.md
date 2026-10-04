---
title: "Neovim 0.12 rollout and staged plugin upgrades"
status: open
priority: high
created: 2026-09-29
updated: 2026-10-05
refs:
  - Neovim v0.12.5 @2026-08-23 stable release
  - mcphub.nvim 163b3ad [tag:v6.2.0] @2025-07-31 chore(release)
related:
  - [blink.cmp v2 migration](tasks/open/upgrade-blink-v2.md)
  - [MCPHub patch-stack recovery](tasks/open/mcphub-patch-stack-recovery.md)
  - [Worktree testing](docs/memory/nvim-worktree-testing.md)
  - [Local patching](docs/memory/lazy-local-patching.md)
---

## Objective

Finish the Neovim 0.12 upgrade with evidence that the daily-driver workflows remain usable, then update compatible plugins in reviewed batches. “Latest” means the newest suitable stable release or tested commit, not an automatic update of every pinned plugin.

## Current state and notes

- [x] Homebrew Neovim is 0.12.5; the 0.11.6 keg remains installed for rollback. Existing running Neovim processes need restarting to use the new binary.
- [x] Headless main and `NVIM_APPNAME=nvimwt3a` startup, MCPHub open/attach, Avante load, CodeCompanion thinking test, worktree carryover test, and LuaSnip snippet-list view passed on 0.12.5.
- [x] LuaSnip's optional snippet-list view needed [a local 0.12 diagnostics patch](patches/LuaSnip/01-neovim-012-diagnostics_v1.patch); matching patch is present in the worktree profile too. Keep it until upstream replaces the removed API.
- [ ] Interactive GUI/editor verification is outstanding; headless checks do not establish that all installed plugins work. Main lockfile has 80 entries and the worktree lockfile has 78 as of 2026-09-29.
- [ ] The main `lazy-lock.json` already contains user-owned edits, and the worktree `.mcphub/servers.json` is dirty. Preserve both; do not replace either with a blanket `:Lazy sync` result.
- [ ] The MCPHub 09/10 patch failure was repaired locally but its Lazy-event recurrence is not yet understood. Complete [patch-stack recovery](tasks/open/mcphub-patch-stack-recovery.md) before broad sync/update.
- `norg` Tree-sitter's unsupported-language warning occurred on both 0.11 and 0.12; it is not currently evidence of an upgrade regression. Main headless starts also attempted a `c_sharp` parser install; verify it completes in a normal session.

## Upgrade inventory and decisions

| Group | Current gate | Next decision |
| --- | --- | --- |
| Low-risk, unpinned plugins | Inventory `:Lazy check` in isolated profile after patch lifecycle is safe | Update small batches; retain commit list and smoke each batch |
| `blink.cmp` v1 → v2 | Neovim 0.12 prerequisite met; v2 additionally needs `blink.lib` and config migration | Follow [existing blink task](tasks/open/upgrade-blink-v2.md); do not bundle with unrelated plugins |
| Avante | 0.11-only compatibility pin is conditional in [AI specs](lua/plugins/extra/myAi.lua); current lock still points to `90a0e77` | Test a newer compatible release in `nvimwt3a`, including load, model call, and MCPHub integration, before main |
| MCPHub | Pinned v6.2.0 with a consolidated local patch stack | No upstream move until complete clean apply/reverse and UI checks are repeatable |
| CodeCompanion and integrations | Pinned version and local patch dependencies | Review release notes and patch applicability as a separate batch |

## Reviewed lockfile batch — 2026-10-05

These revisions were already installed in the main profile; the review does not run `:Lazy sync`, install parsers, restart MCPHub, or make model requests. Each proposed SHA matches that plugin's installed HEAD. The pinned AI integrations and blink.cmp remain unchanged.

| Plugin | Previous SHA | Reviewed SHA | Scope / remaining check |
| --- | --- | --- | --- |
| fff.nvim | `c9d1302` | `e208805` | Native file and content search passed; picker interaction remains manual |
| friendly-snippets | `6cd7280` | `b4d01b0` | Manifest snippet JSONs decode successfully; expansion remains manual |
| gitsigns.nvim | `5be654f` | `f2421c5` | Setup and existing diff API passed; new repository diff panel remains manual |
| img-clip.nvim | `b6ddfb9` | `99848da` | `vim.uv` compatibility fallback; setup passed, clipboard paste not exercised |
| mini.ai | `25248c6` | `cb02c54` | HTML tags with whitespace before `>` now match; textobject check passed |
| neo-tree.nvim | `ebd6676` | `1a14083` | Filesystem view opens/closes; new trash/selection keys not exercised |
| nvim-treesitter | `1907129` | `9a168f6` | Installed Lua, TypeScript and Markdown parsers/queries passed; KDL/proto parser changes require separate reinstall checks if used |
| nvim-treesitter-textobjects | `898ee30` | `5c7b026` | Lua query and selection API passed; repeat-motion interaction remains manual |
| quick-code-runner.nvim | `a98f199` | `1eb3a73` | CI/docs-only diff; module loads |
| render-markdown.nvim | `4663eb3` | `f94914e` | Heading/table rendering produces extmarks; visual layout remains manual |
| sidekick.nvim | `208e1c5` | `3d80a47` | Config and CLI API load with NES disabled; live Copilot NES not tested |
| vim-test | `2676d84` | `f688a3e` | Strategy definitions load, including optional Herdr strategy; no test runner launched |

- [x] Thirteen targeted probes passed in a clean `NVIM_APPNAME=nvimwt3a` instance using the main profile's installed plugin files. See [the smoke harness](tests/test_plugin_lock_smoke.lua) and [test setup notes](docs/memory/plugin-upgrade-checks.md).
- [x] Avante MCP regression tests passed: 104 helper assertions and 56 completion assertions using real installed Avante, blink.compat and Blink text edits.
- [x] LuaSnip diagnostics patch applies and reverses cleanly against the pinned pristine source; its view disables diagnostics only in its scratch buffer. The new-tab mapping preserves an unsaved buffer and cursor.
- [ ] CopilotChat and copilot.vim lock additions are intentionally excluded from this batch. Installed copilot.vim is 1.59.0 but the spec requests 1.57.0; reconcile the opt-in Copilot configuration and test it separately. Preserve the two working-tree lock entries for review.
- [ ] The broad interactive checklist and MCPHub patch lifecycle checks below remain open. These probes do not prove clipboard, live provider requests, terminal key transport, destructive file actions, or every parser/language.

## Implementation plan

- [ ] Capture the exact current lockfile, installed SHAs, pinned specs, and dirty-file list for each profile without modifying user-owned files.
- [ ] Resolve the [MCPHub patch lifecycle gate](tasks/open/mcphub-patch-stack-recovery.md) and run its repeated apply/reverse fixture.
- [ ] Use the isolated `nvimwt3a` profile to check upstream releases and migrate one plugin group at a time. Record old/new SHAs and why each upgrade is compatible with 0.12.
- [ ] Keep major-version migrations (especially blink v2) separate from low-risk updates. Rebase local patches on a disposable checkout before changing any patch-heavy plugin.
- [ ] Run lightweight headless tests, then hand off interactive tests to the user. Promote only accepted batches to main; preserve dirty/profile-local files.
- [ ] Update permanent plugin notes in `docs/memory/` and the lockfile only for accepted upgrades. Do not mark review tasks completed on the user's behalf.

## Success criteria

- Neovim 0.12.5 remains the linked binary, or a documented rollback is chosen after a reproducible regression.
- Each upgraded plugin has an old/new SHA, compatibility note, clean patch state, and relevant automated/manual evidence.
- Main and worktree profiles start without patch errors; MCPHub, completion, LSP, AI integrations, snippets, and Tree-sitter work interactively.
- No unrelated lockfile or profile-local changes were overwritten.

## Verification

### How to verify

Restart a fresh Neovim process for each profile. Use a normal Lua or Markdown project, then test MCPHub and AI actions without sharing OAuth callback URLs or tokens.

### Commands

```bash
nvim --version
NVIM_APPNAME=nvimwt3a nvim
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

```vim
:Lazy
:MCPHub
:checkhealth vim.lsp
```

### Checklist

- [ ] A fresh process reports Neovim 0.12.5 in each profile and opens without an error toast.
- [ ] MCPHub opens on the first attempt, reaches Connected, switches to Agents with `Z`, and its edit popup stays open as expected.
- [ ] Completion and snippet expansion work in Lua and Markdown; LSP diagnostics and Tree-sitter highlighting appear normally.
- [ ] CodeCompanion and Avante load; an authorized MCP tool call completes when a safe test is available.
- [ ] `:Lazy` shows only the intended plugin changes, with no 09/10 patch errors or unexpected dirty entries.

## References

- [Neovim v0.12.5 release](https://github.com/neovim/neovim/releases/tag/v0.12.5)
- [Neovim 0.12 breaking changes](https://neovim.io/doc/user/news-0.12/)
- [blink.cmp v2 migration guide](https://github.com/Saghen/blink.cmp/blob/main/UPGRADE.md)
- [MCPHub patch catalog](patches/mcphub.nvim/README.md)
