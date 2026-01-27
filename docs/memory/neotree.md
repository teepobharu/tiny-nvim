# Neo-tree Snacks Keybinds Integration

## Issues & Fixes

- **Issue:** Neo-tree does not natively expose hovered filepath for external actions.
  - **Fix:** Use `neo-tree.sources.manager.get_state('filesystem')` and `tree:get_node()` to get hovered node path.

- **Issue:** Snacks.nvim grep command may require correct escaping of filepaths.
  - **Fix:** Use `vim.fn.fnameescape` for safe command invocation.

- **Issue:** File picker may not include hidden files by default.
  - **Fix:** Pass `{ hidden = true }` to Telescope's `find_files` picker.

## References
- [myneotree.lua](../../lua/plugins/myneotree.lua)
- [mysnacks.lua](../../lua/plugins/mysnacks.lua)
- [tasks/drafts/neotree_snacks_keybinds.md](../../tasks/drafts/neotree_snacks_keybinds.md)

## Manual Verification Checklist
- [ ] `<space>/` in Neo-tree triggers Snacks grep on hovered file/folder
- [ ] `<space>f` in Neo-tree opens file picker (includes hidden files)
