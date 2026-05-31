---
title: "CC: buff/file keymap fix + thinking toggle preset + extract myCodecomp"
status: review
priority: low
created: 2026-05-31
updated: 2026-06-01
related:
  - [myAi.lua](lua/plugins/extra/myAi.lua)
  - [editor_keymaps.lua](lua/utils/editor_keymaps.lua)
  - [my_ai_constants.lua](lua/utils/my_ai_constants.lua)
  - [codecompanion-reasoning-effort task](tasks/open/codecompanion-reasoning-effort.md)
---

## Objective

Three housekeeping items bundled (none individually complex):

1. **#4 buff/file keymap**: Resolve why `<C-b>`/`<C-f>` insert-mode pickers can't use the "default" — identify the conflict and fix or document the intended binding.
2. **#6 thinking toggle via model preset**: Add a chat keymap to cycle/toggle `reasoning_effort` per active model preset. Depends on `codecompanion-reasoning-effort.md` being completed first.
3. **#7 extract**: Move the CodeCompanion plugin spec block out of `myAi.lua` into its own `lua/plugins/extra/myCodecomp.lua`. Do this last so prior fixes land in the smaller file.

## Context

### #4 buff/file keymap

Custom insert-mode pickers at `lua/plugins/extra/myAi.lua:130-163` (`run_codecompanion_slash_picker`) and `L864-881` (buffer `<C-b>`, file `<C-f>`). Comment at `L838`: *"require codecompanion.actions not seem to have keymap avail for buffer/files"* — these were added because no upstream default existed.

Known conflicts:
- Insert-mode `<C-b>` = Neovim default page-up scroll (`:help i_CTRL-B` — not actually a default, so may be blink.cmp)
- Insert-mode `<C-b>` is commonly bound to "scroll docs backward" in blink.cmp/nvim-cmp

Upstream default: no `<C-b>`/`<C-f>` in `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/config.lua:541-547`. Buffer/file insertion is via `/buffer`, `/file` slash commands triggered from the chat input.

Investigation needed: check blink.cmp config (`lua/plugins/extra/myEditor.lua` or `myBlink.lua`) for `<C-b>`/`<C-f>` bindings to confirm the conflict source.

### #6 thinking toggle via model preset

Depends on `reasoning_effort` schema being live (see `tasks/open/codecompanion-reasoning-effort.md`). Once `can_reason` flags and schema are in place:
- Add a chat keymap (e.g. `<leader>tr` or repurpose an existing one) that cycles `reasoning_effort` between `low` / `medium` / `high` for the current model
- Reuse the `change_adapter` pattern at `~/.local/share/.../config.lua:372` or call `adapter:set("reasoning_effort", next_level)` directly from a keymap

### #7 extract to myCodecomp.lua

`lua/plugins/extra/myAi.lua` is 1777 lines. The CodeCompanion plugin spec starts around `L649` and runs to ~`L1100` (~450 lines). It is self-contained and has no hard coupling to the rest of `myAi.lua`.

Plan:
- Create `lua/plugins/extra/myCodecomp.lua` with the extracted block
- Move shared helper functions (`run_codecompanion_slash_picker`, `L130-163`) into `lua/utils/my_codecompanion_actions.lua` or a new `lua/utils/my_codecompanion_ui.lua` (check if they already live elsewhere first)
- In `myAi.lua`, replace the extracted block with `require("plugins.extra.myCodecomp")` or a Lazy import entry

## Implementation Plan

### Sub-task: #4 buff/file keymap

- [x] Check blink.cmp config for `<C-b>`/`<C-f>` insert bindings (find relevant `my*.lua` under `lua/plugins/extra/`)
- [x] Determine whether the conflict is blink.cmp or something else — confirmed blink.cmp preset binds `<C-b>`/`<C-f>` to scroll_documentation_up/down
- [x] Decision: rebind pickers to `<M-b>` / `<M-f>` (Alt+b / Alt+f — not used by blink.cmp)
- [x] Implement fix at `myCodecomp.lua` (was myAi.lua); updated comment at keymaps block header

### Sub-task: #6 thinking toggle

- [x] **Prerequisite**: `codecompanion-reasoning-effort.md` completed
- [x] Found existing keymap table in `myCodecomp.lua` (extracted from myAi.lua)
- [x] Added `toggle_reasoning` keymap entry (index 9, `<leader>Ar`) cycling `reasoning_effort` low→medium→high
- [ ] Test that the keymap is visible in `<leader>?` / whichkey for CodeCompanion chat buffer (requires manual verification)

### Sub-task: #7 extract

- [x] Identified exact line range: myAi.lua L643-1770 (comment + two CC spec entries)
- [x] Confirmed helpers (`run_codecompanion_slash_picker`, `focus_codecompanion_chat`, `enable_yolo_on_created`) not referenced outside CC block
- [x] Created `lua/plugins/extra/myCodecomp.lua` (1209 lines) with all required upvalues re-declared
- [x] Helpers inlined into myCodecomp.lua (no separate util file needed — used only inside CC spec)
- [x] Removed extracted block + dead upvalues from `myAi.lua` (610 lines, was 1779)
- [x] Added `"myCodecomp"` to `enable_extra_plugins` in `mydefault-nvim-config.lua`
- [x] Ran `NVIM_APPNAME=nvimwt3a nvim --headless -c "Lazy check"` — no errors

## Success Criteria

- Insert-mode buffer/file picker works without conflicting with blink.cmp or is replaced by working slash-command flow
- (After #5 task done) Thinking toggle keymap cycles `reasoning_effort` visibly in the chat buffer
- `lua/plugins/extra/myCodecomp.lua` exists and Lazy loads CodeCompanion from it; `myAi.lua` shrinks by ~450 lines
- No startup errors from the extraction

## Verification

### How to verify

```bash
NVIM_APPNAME=nvimwt3a nvim
```

**Picker keymap:**
```vim
" Open CodeCompanion chat, enter insert mode in the input area
" Press the picker key (whatever it lands on after the fix)
" Should open a buffer/file picker
```

**Thinking toggle (after prerequisite):**
```vim
:CodeCompanionChat
" Send a message with a can_reason model active
" Press the toggle keymap
" Confirm reasoning_effort changes in :messages or debug log
```

**Extraction:**
```bash
NVIM_APPNAME=nvimwt3a nvim --headless -c "Lazy check" -c "qa"
grep -c "codecompanion" lua/plugins/extra/myAi.lua   # should be near zero
wc -l lua/plugins/extra/myCodecomp.lua                # should be ~450+
```

### Checklist

- [ ] Buffer picker `<M-b>` works in insert mode without blink.cmp interference
- [ ] File picker `<M-f>` works in insert mode
- [ ] Thinking toggle `<leader>Ar` cycles effort level and shows in output
- [x] `lua/plugins/extra/myCodecomp.lua` loads without error on startup (`Lazy check` clean)
- [x] `myAi.lua` no longer contains the CC plugin spec block (0 matches for olimorris/codecompanion)
- [ ] All existing CC functionality (adapters, keymaps, slash commands) unchanged after extraction — needs manual test

## References

- [Custom picker helpers](lua/plugins/extra/myAi.lua:116-163)
- [In-chat keymap table](lua/plugins/extra/myAi.lua:839-882)
- [Upstream chat keymaps](~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/config.lua)
- [Reasoning effort task (prerequisite for #6)](tasks/open/codecompanion-reasoning-effort.md)
- [CodeCompanion memory](docs/memory/codecompanion.md)
- [Lazy merging guide](docs/memory/lazy-nvim-config-merging.md)
