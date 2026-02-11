**Create Dotfiles Config Picker**

- What: Create a custom Snacks picker in `lua/utils/snacks_pickers.lua` to quickly access dotfiles configuration files with configurable include/exclude patterns
- Why: Quick access to frequently edited config files across `~/dotfiles/` directory with easy-to-maintain filtering rules
- Acceptance: Picker opens with `<leader>fD`, shows bash config files, includes `~/.bash.local`, excludes `fork` and `nvim*` directories, config table is easily editable for adding new patterns

## Implementation Tasks

### 1. Create Config Table Structure ✅
- [x] Add config table at top of `M.dotfiles_picker()` function with three sections:
  - `include_patterns`: array of file patterns (e.g., `*bash*`, `*.lua`, `*.vim`)
  - `exclude_dirs`: array of directory patterns to skip (e.g., `fork`, `nvim*`, `.git`)
  - `extra_files`: array of explicit file paths (e.g., `~/.bash.local`)

### 2. Implement M.dotfiles_picker() Function ✅
- [x] Create function in `lua/utils/snacks_pickers.lua` (line 1555)
- [x] Expand home directory (`~`) to absolute path
- [x] Build base directory list: `~/dotfiles/`
- [x] Handle extra files outside base directory

### 3. Add File Filtering Logic ✅
- [x] Implement directory exclusion using `exclude_dirs` patterns
- [x] Implement file inclusion using `include_patterns`
- [x] Ensure glob pattern matching works (e.g., `nvim*` matches `nvim1`, `nvim2`)
- [x] Handle both files in base directory and extra files

### 4. Handle Edge Cases ✅
- [x] Properly expand `~/.bash.local` to absolute path
- [x] Handle missing files gracefully (don't error if `~/.bash.local` doesn't exist)
- [x] Ensure relative path display for better UX
- [x] Test with symbolic links if present

### 5. Register Keybinding ✅
- [x] Add keybinding in `lua/plugins/snacks.lua` under the `keys` section
- [x] Use `<leader>fD` mapping
- [x] Add description: "Dotfiles Config"
- [x] Place near other file-related keybindings (after `<leader>fc`)

### 6. Testing
- [ ] Test picker opens with `<leader>fD`
- [ ] Verify bash files appear (`.bashrc`, `.bash_profile`, `.bash_aliases`, etc.)
- [ ] Verify `~/.bash.local` is included
- [ ] Verify `fork` directory is excluded
- [ ] Verify `nvim*` directories are excluded (if any exist)
- [ ] Verify files in `~/dotfiles/.config/` are shown
- [ ] Test adding new pattern to config table
- [ ] Test removing pattern from config table

## Technical Notes

**Base Implementation Pattern:**
```lua
function M.dotfiles_picker()
  local CONFIG = {
    base_dir = "~/dotfiles",
    include_patterns = { "*bash*", "*.lua", "*.vim", "*.json" },
    exclude_dirs = { "fork", "nvim*", ".git", "node_modules" },
    extra_files = { "~/.bash.local" }
  }
  
  -- Implementation here using Snacks.picker.files() as base
end
```

**Key Considerations:**
- Use `vim.fn.expand()` for path expansion
- Use Snacks native file picker for consistency
- Consider using `find_files` or custom source if needed
- Add helpful formatter to show relative paths
- Follow existing picker patterns in the codebase

## References
- Existing pickers: `M.session_picker()`, `M.pick_tmux_window()`
- Snacks plugin config: `lua/plugins/snacks.lua`
- Similar pattern-based filtering in: `M.custom_git_pickers`
