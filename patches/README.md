# Local Patch Catalog

This directory stores `lazy-local-patcher` patch sets grouped by plugin name.

Current plugin patch docs:

- `patches/codecompanion.nvim/README.md`
- `patches/codecompanion-history.nvim/README.md`
- `patches/mcphub.nvim/README.md`
- `patches/LuaSnip/01-neovim-012-diagnostics_v1.patch` — use the supported per-buffer diagnostics API in the optional snippet-list view (Neovim 0.11/0.12).


## Patcher recovery regression

The patcher's reversible-stack patch preflights the complete restore/apply in a
disposable checkout, then backs up and commits validated changes per repository.
A failed preflight leaves installed files unchanged; failed writes roll back.
Symlink paths, staged patch-owned changes, and unknown generated-file contents are
refused. Exact leftovers are recognized even with hidden untracked files. Each
repository has its own lifecycle result, so one conflict does not leave other
plugins unpatched. See [lifecycle notes](../docs/memory/lazy-local-patching.md) and
[disposable-clone tests](../tests/test_lazy_patcher_lifecycle.lua). Existing Neovim
processes must be reopened to load updated patcher code.
