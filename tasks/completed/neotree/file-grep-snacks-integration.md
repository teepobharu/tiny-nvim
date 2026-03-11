# Neotree — Snacks Pickers Integration

Short: Add Snacks `files` and `grep` picker actions to Neo-tree and new keybindings.

What I changed
- Added `snacks_grep` and `snacks_find_files` commands to `lua/plugins/extra/neotree.lua`
- Added filesystem mappings: `<leader>/` → `snacks_grep`, `<leader>f` → `snacks_find_files`

Files touched
- `lua/plugins/extra/neotree.lua`

Verification
- Open Neovim with this config: `NVIM_APPNAME=nvim3_jelly_tinynvim nvim`
- Open Neo-tree: `<leader>e` (or `:Neotree`)
- Navigate to a file node and press `<leader>/` — Snacks grep should open with cwd set to the file's parent dir
- Navigate to a file node and press `<leader>f` — Snacks files should open with depth=1 (parent dir)
- Navigate to a directory node and press `<leader>f` — Snacks files should open rooted at that dir

Notes
- The implementation coexists with existing fzf-lua keys `Ff` and `Fg`.
- The actual neotree code change was stashed and is included in the commit created below.
