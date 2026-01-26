---
title: "Snacks Picker: Add action key to yank preview content"
status: "open"
assignee: "ai"
created: 2026-01-24
priority: "medium"
related:
  - [Snacks actions](lua/utils/snacks_actions.lua)
  - [Snacks pickers](lua/utils/snacks_pickers.lua)
  - [Snacks picker memory](docs/memory/snacks_picker.md)
  - [Snacks.nvim actions reference](https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/actions.lua)
  - [DeepWiki: Snacks copy actions](https://deepwiki.com/search/is-there-copy-action-and-how-d_e0314aa4-42c3-4052-878a-ab59592d04ec?mode=fast)
---

## Objective
Add an action key binding to snacks picker that allows yanking (copying) the preview content to system clipboard. Prefer using builtin functionality if available.

## Checklist
- [ ] Research snacks builtin copy/yank actions (check actions.lua reference)
- [ ] Identify picker contexts where preview yank would be useful (git diff, file preview, etc.)
- [ ] Implement yank_preview action in lua/utils/snacks_actions.lua
- [ ] Add keybinding to relevant pickers (suggest: `<C-y>` or `y`)
- [ ] Test with different preview types:
  - [ ] File preview
  - [ ] Git diff preview
  - [ ] Command output preview
- [ ] Update docs/memory/snacks_picker.md with implementation notes
- [ ] User verification

## Implementation Notes

### Potential Approaches
1. **Builtin action**: Check if snacks has built-in `yank_preview` or similar action
2. **Custom action**: Create action that:
   - Gets preview buffer content
   - Copies to `+` register (system clipboard)
   - Shows notification feedback

### Code References
- Existing actions pattern: lua/utils/snacks_actions.lua:10-27 (toggle_external example)
- Preview utilities: Check snacks.picker.preview module
- Clipboard interaction: Use `vim.fn.setreg('+', content)`

### Suggested Keybinding
```lua
actions = {
  yank_preview = function(picker)
    -- Implementation here
  end,
}
```

## Questions to Resolve
- Does snacks provide builtin preview yank action?
- Which key binding is most intuitive? (`<C-y>`, `y`, `gy`?)
- Should it support yanking selection or full preview?
- Should it handle different preview formats (raw, formatted, etc.)?

## Success Criteria
- Can yank preview content with single key press
- Works across different picker types
- Provides user feedback (notification)
- Documented in memory bank for future reference
