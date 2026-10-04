# Targeted plugin upgrade checks

Compare exact old/new source revisions and the consuming config before recording an installed revision in the lockfile. Do not interpret a load-only test as proof of a model request, clipboard operation, or interactive workflow. Keep major upgrades and spec/lock mismatches separate.

## Isolated smoke harness

Run from the config repository with a clean Neovim instance. This uses installed main-profile plugin files but the worktree namespace; it does not start Lazy, MCPHub, AI requests, Herdr sessions, or test runners. FFF indexes only the config repository and uses temporary databases.

```bash
NVIM_APPNAME=nvimwt3a \
NVIM_REVIEW_PLUGIN_ROOT="$HOME/.local/share/nvim3_jelly_tinynvim/lazy" \
nvim --headless -u NONE -i NONE -l tests/test_plugin_lock_smoke.lua
```

The default plugin root is the selected profile's installed `lazy` directory; omit the override to test the worktree's plugins. The test reports thirteen probes, covering the new-tab mapping, LuaSnip diagnostics, snippets, basic plugin loading, Lua/TypeScript/Markdown queries, Markdown extmarks, Neo-tree filesystem view, and FFF native search.

## Test setup pitfalls

- FFF's `fff.core.ensure_initialized()` initializes the native picker, but the Lua `fff.file_picker` wrapper has separate state. Its `wait_for_initial_scan()` returns false immediately until `fff.file_picker.setup()` runs. Initialize the wrapper before a programmatic `file_search()` test with a wait budget; otherwise a test can misreport an indexing timeout. No production config change was needed for this review.
- render-markdown's extmarks live in the `render-markdown.nvim` namespace, not `render-markdown`. Read `require("render-markdown.core.ui").ns` when asserting output.
- Unified-diff patch files contain required context whitespace. Validate apply/reverse against pristine source rather than deleting context to silence a blanket whitespace check.

Last verified: 2026-10-05, Neovim 0.12.5. The reviewed SHA batch and pending manual checks are in [the rollout task](../../tasks/open/neovim-012-plugin-upgrade-rollout/README.md).
