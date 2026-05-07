---
title: "Upgrade blink.cmp to v2"
status: open
priority: medium
created: 2026-05-07
updated: 2026-05-07
related:
  - [lua/plugins/extra/myCoding.lua](lua/plugins/extra/myCoding.lua)
  - [lua/plugins/coding.lua](lua/plugins/coding.lua)
  - [docs/memory/lazy-nvim-config-merging.md](docs/memory/lazy-nvim-config-merging.md)
---

## Objective

Upgrade blink.cmp from pinned v1.10.2 to v2. Currently blocked on Neovim 0.12+. Capture all migration requirements here so upgrade can be done in one session.

## Context

After `9122f94 feat(plugins): bump deps` advanced `blink.cmp` lock past v2 cutover (2026-04-29), startup broke:

```
blink.cmp v2 requires blink.lib ("saghen/blink.lib") installed via your package manager: module 'blink.lib' not found
```

Fixed by committing `saghen/blink.cmp` to SHA `9b189bb` (v1.10.2) via `myCoding.lua` override. v2 deferred pending nvim upgrade.

**Current state**:
- Nvim: 0.11.6 (homebrew stable available: 0.12.2)
- blink.cmp: pinned to v1.10.2 via [`lua/plugins/extra/myCoding.lua:4`](lua/plugins/extra/myCoding.lua#L4)
- lazy-lock.json: `"blink.cmp": { "commit": "9b189bb2a0e03412e0e901dfbd09904f86cd593c" }`

## Requirements

### Hard prerequisites

- [ ] Upgrade Neovim to 0.12+ (`brew upgrade neovim` → 0.12.2 available now)
- [ ] Add `saghen/blink.lib` as dependency

### Spec changes

All edits go in `myCoding.lua` (project convention — no upstream edits):

1. **Remove v1 pin** — delete the `commit = "9b189bb..."` override block in `myCoding.lua`
2. **Add `blink.lib` dependency** — add to blink.cmp spec in `myCoding.lua`:
   ```lua
   {
     "saghen/blink.cmp",
     dependencies = { "saghen/blink.lib" },
   },
   ```
3. **Remove `prebuilt_binaries`** from opts if present (field removed in v2; currently not set explicitly in our config — check anyway)
4. **Build step** — v2 changes build invocation:
   - v1: `cargo build --release` → binary in `target/release/`
   - v2: `require('blink.cmp').build():wait(60000)` → binary in `lib/`
   - Upstream `coding.lua` has build commented out; verify blink pre-built binaries still work for v2 or set build
5. **LuaSnip version pin** — `coding.lua:26` sets `version = "v2.*"`. v2 UPGRADE.md: *"remove any version pinning"* → update override in `myCoding.lua` to unpin (`version = false` or omit)
6. **`fuzzy.implementation`** — current: `"prefer_rust_with_warning"`. v2 may rename/change — verify against v2 schema after upgrade
7. **Keymaps now buffer-local** — v2 change. Test custom keymap `<C-c>` (copilot trigger in `myCoding.lua:56`) still works after upgrade
8. **`cmp.*` API now synchronous** — v2: `cmp.*` return actual result (not scheduled). Check copilot trigger function:
   ```lua
   -- myCoding.lua:57 — verify `cmp.show` return value not used for async flow
   function(cmp)
     return cmp.show { providers = { "copilot" } }
   end
   ```
9. **blink.compat version** — `coding.lua:8` sets `version = "2.*"`. Check blink.compat v2 compatibility with blink.cmp v2 — may need new version of blink.compat
10. **`sources.completion.enabled_providers`** — opts_extend key still valid in v2? Check `cmp.saghen.dev` docs

### Lock file

After upgrade, `lazy-lock.json` entry for `blink.cmp` should track v2 SHA (no `branch` field needed once commit pin removed and version properly set upstream).

## Implementation Plan

- [ ] `brew upgrade neovim` — confirm reaches 0.12+
- [ ] In `myCoding.lua`: replace commit-pin block with `{ "saghen/blink.cmp", dependencies = { "saghen/blink.lib" } }` override
- [ ] In `myCoding.lua`: add LuaSnip version unpin override
- [ ] Run `:Lazy sync` — installs blink.lib, updates blink.cmp to latest v2
- [ ] Run `:Lazy build blink.cmp` if pre-built binary not auto-downloaded
- [ ] Test completion works (InsertEnter, no error toast)
- [ ] Test copilot trigger `<C-c>` if ENABLE_COPILOT=true
- [ ] Test minuet trigger `<C-c>` if ENABLE_COPILOT=false
- [ ] Run `:checkhealth blink.cmp`
- [ ] Update `docs/memory/lazy-nvim-config-merging.md` — note commit-pin workaround obsolete after upgrade

## Success Criteria

- No error on startup or InsertEnter
- Completion menu shows in insert mode
- `:Lazy` shows `blink.cmp` at v2.x tag and `blink.lib` listed
- `:checkhealth blink.cmp` passes
- Copilot and/or minuet completion trigger works

## Verification

### How to verify

Restart Neovim after sync. Enter insert mode in a Lua buffer (for lazydev completions) and a general buffer.

### Commands

```bash
brew upgrade neovim
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

```vim
:Lazy
:checkhealth blink.cmp
```

### Checklist

- [ ] Neovim reports 0.12+: `:lua print(vim.version())`
- [ ] No error toast on startup
- [ ] No error on `InsertEnter`
- [ ] Completion menu shows when typing in insert mode
- [ ] `:Lazy` shows `blink.cmp` v2.x and `blink.lib` installed
- [ ] `:checkhealth blink.cmp` clean
- [ ] `<C-c>` trigger works per ENABLE_COPILOT state
- [ ] LuaSnip snippets still expand (type snippet prefix + trigger)
- [ ] Render-markdown source still loads in `.md` files
- [ ] lazydev source still loads in `.lua` files
- [ ] No regressions in `blink.compat` based sources (cmp source)

## References

- [UPGRADE.md (v2)](https://github.com/Saghen/blink.cmp/blob/main/UPGRADE.md)
- [blink.lib repo](https://github.com/Saghen/blink.lib)
- [blink.cmp docs v2](https://cmp.saghen.dev/)
- [Current pin override](lua/plugins/extra/myCoding.lua)
- [Upstream spec](lua/plugins/coding.lua)
- [Lazy merging — commit pin pattern](docs/memory/lazy-nvim-config-merging.md)
