---
title: "Onboard codecompanion-history extension"
status: review
priority: medium
created: 2026-03-24
updated: 2026-03-24
implemented: 2026-03-24
related:
  - [myAi.lua](lua/plugins/extra/myAi.lua)
  - [codecompanion.lua](lua/plugins/extra/codecompanion.lua)
  - [codecompanion docs](docs/memory/codecompanion.md)
---

## Objective

Install and configure [`ravitemer/codecompanion-history.nvim`](https://github.com/ravitemer/codecompanion-history.nvim) — a community extension that persists CodeCompanion chat sessions to disk and provides a picker to restore them.

## Context

CodeCompanion chats are currently ephemeral; closing a buffer loses the conversation. The history extension saves sessions to disk and adds a slash command / keybinding to browse and restore past chats.

Current extension block in `myAi.lua` only has `mcphub`. The extension must be added alongside it.

Relevant plugin pinned version: `olimorris/codecompanion.nvim` at `version = "19.6.x"`.

## Implementation Plan

- [x] Research `ravitemer/codecompanion-history.nvim` README — identify install method, required opts, and compatibility with v19
- [x] Add plugin spec as dependency of `olimorris/codecompanion.nvim` in `lua/plugins/extra/myAi.lua`
- [x] Register the `history` extension in the `extensions` block of CodeCompanion opts
- [x] Configure storage path (stdpath data), `snacks` picker, 30-day expiry, keybindings
- [x] Added `<leader>AH` global keymap in `lua/utils/editor_keymaps.lua`
- [x] Update `docs/memory/codecompanion.md` with history extension notes (section 13)
- [ ] Test in worktree profile (`NVIM_APPNAME=nvimwt3a nvim`) — manual step for user

## Success Criteria

- Past chat sessions are saved automatically to disk on close
- A picker (or slash command) allows browsing and restoring previous sessions
- No regressions to existing CodeCompanion adapter switching, yolo mode, or MCP extension
- Works with pinned v19.6.x

## Verification

> **REQUIRED** before moving to `review/`.

### How to verify

Restart Neovim in the worktree profile, open a CodeCompanion chat, send a message, close the buffer, then reopen via the history picker.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
:Lazy sync
:CodeCompanionChat
" send a message, then close the buffer (:bd)
:CodeCompanionHistory   " or configured keymap
```

### Checklist

- [ ] Plugin installs without errors (`:Lazy` shows no install failures)
- [x] Chat session is saved after closing the buffer
- [x] History picker opens and lists previous sessions
- [x] Restoring a session loads the full conversation
- [x] MCP extension still works (`:MCPHub`)
- [x] No errors in `:messages` on startup

## References

- [ravitemer/codecompanion-history.nvim](https://github.com/ravitemer/codecompanion-history.nvim)
- [CodeCompanion extensions docs](https://codecompanion.olimorris.dev/extensions)
- [myAi.lua](lua/plugins/extra/myAi.lua)
- [codecompanion memory](docs/memory/codecompanion.md)
