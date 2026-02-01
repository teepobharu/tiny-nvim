---
title: "Sidekick/Clipboard: Copy & Send file refs with line+char ranges"
created: 2026-01-31
updated: 2026-01-31
status: draft
priority: medium
tags: [sidekick, snacks, clipboard, keymap, file-reference]
related:
  - docs/misc_nvim.md
  - lua/plugins/ai.lua
  - lua/utils/editor_keymaps.lua
  - lua/utils/mypath.lua
  - lua/utils/file_reference.lua
  - docs/sidekick_explore20260122.md
---

# Sidekick/Clipboard line-ref send & copy

## Objective

Add keybindings to copy or send file references with line/column ranges to Sidekick (and clipboard) using relative and absolute addressing. Provide quick “send current context” and “copy linkable ref” workflows for AI sidekick and sharing.

## Requirements

- `<localleader>cl` (normal/visual): copy **relative** reference for current file/selection using `:+-` syntax (e.g., `@file :L+0:C1-L+3:C80`) in the **default Sidekick format** (do not rely on amp formatter overrides).
- `<localleader>L` (normal/visual): copy **absolute** reference with file path + line/col (e.g., `@file :L10:C1-L12:C120`) in the default Sidekick format.
- Both mappings should also have a modifier/secondary action to **send to sidekick** (CLI) in one step; reuse `sidekick.cli.send` with the generated ref.
- Support multi-segment context: allow adding multiple refs in one message (e.g., selection + nearby lines). Concatenate with newline or configurable separator.
- Works in visual mode (exact range) and normal mode (current line, optionally prompt for count / use motion operatorfunc).
- Copy should target `+` register; send should preserve clipboard content.
- Use the native/default Sidekick reference format (no dependence on the custom `amp` formatter overrides in `lua/plugins/ai.lua`).
- Safe on unsaved buffers: fallback to absolute path resolution; warn if buffer is modified but not written.

## Format & Examples

- Absolute: `@path/to/file.lua :L12:C3-L20:C15`
- Relative (from cursor): `@path/to/file.lua :L+0:C1-L+5:C120`
- Single line: `@path/to/file.lua :L42:C1`
- Multi-context send payload:
  ```
  @file.lua :L10:C1-L15:C120
  @file.lua :L30:C1-L32:C80
  ```

## Tasks

- [ ] Design format helpers (absolute/relative, single/multi range) in a shared util (prefer `lua/utils/file_reference.lua` or new helper).
- [ ] Implement keymaps in `lua/config/mykeymaps.lua` or `lua/utils/editor_keymaps.lua` (mirror VSCode keymaps if needed).
- [ ] Add Sidekick send variants (maybe `<localleader>cS` or prompt choice) that call `sidekick.cli.send` without changing focus.
- [ ] Ensure Snacks picker integration can invoke the same builder (optional).
- [ ] Handle modified/unsaved buffers gracefully.
- [ ] Tests/manual checks: normal vs visual, relative vs absolute, multi-range, clipboard untouched when sending.
- [ ] Update docs: `docs/misc_nvim.md` TODO section and any sidekick notes.

## Open Questions

- Separator for multiple refs: newline vs `;`? Should Sidekick CLI get one message or multiple sequential sends?
- Should relative format use `:+N` or `+N` shorthand (keep consistent with existing amp formatter expectations)?
- Provide optional prompt to include surrounding context lines automatically (e.g., `±5` lines)?

## Success Criteria

- One keystroke to copy ref; one keystroke to send ref to Sidekick.
- Works with both absolute and relative ranges; preserves clipboard when sending.
- Sidekick receives file refs that render correctly after `amp` formatter transformations.
