# Plugin Update Verification - January 24, 2026

## 🚨 BREAKING CHANGES - Immediate Attention Required

### 1. gitsigns.nvim (v2.0.0) - MAJOR RELEASE
**Status**: ⚠️ NEEDS REVIEW

**Breaking Changes**:
- Custom highlight names removed - must use standard highlight groups
- `setup()` is now optional (can use defaults)
- Minimum Neovim version: 0.11 (dropped 0.9.5 support)
- `current_line_blame_formatter_opts` deprecated
- yadm support removed

**Action Items**:
- [ ] Check `lua/plugins/ui.lua` for gitsigns config
- [ ] Remove any custom highlight group definitions in `config.signs`
- [ ] Remove deprecated `current_line_blame_formatter_opts` if used
- [ ] Test blame functionality after update

**New Features**:
- Statuscolumn support (commit b2094c6)
- Better stability with timer handling

**References**:
- File: lua/plugins/ui.lua (check if gitsigns config exists)
- [Changelog](https://github.com/lewis6991/gitsigns.nvim/blob/main/CHANGELOG.md)

---

## ✨ NEW FEATURES - High Value

### 2. avante.nvim - Major Enhancements
**Status**: ✅ CONFIG EXISTS (myEditor.lua:746-832)

**New Features**:
1. **Claude Code Subscriptions** (commit 2159c0c)
   - Enterprise-grade AI capabilities
   - Better rate limits and performance

2. **MCP Servers Support** (commit 148998b)
   - Configure in `acp_providers` config
   - Extend capabilities with custom tools
   - Current config: `acp_follow_agent_locations = false` in myEditor.lua:805

3. **Git Ignored Files Access** (commit 5cad31d)
   - NEW OPTION: `allow_access_to_git_ignored_files`
   - **ALREADY SET**: `false` in myEditor.lua:777 ✅
   - Security: Prevents access to .env, node_modules, etc.

4. **ACP Session Loading** (commit 7608dce)
   - Resume previous coding sessions
   - Persistent workflow support

5. **History Management** (commits a9e9890, 483c570, 92f972a)
   - Delete history via fzf-lua, snacks, telescope
   - Better session management

**Current Config Analysis**:
```lua
-- myEditor.lua:771-832
- provider = "copilot" ✅
- allow_access_to_git_ignored_files = false ✅ (already secure)
- acp_follow_agent_locations = false ✅
- selection.enabled = true, hint_display = "none" ✅
```

**Action Items**:
- [ ] Consider enabling ACP session loading if needed
- [ ] Review if MCP servers are needed for workflow
- [ ] Test new history management features with snacks picker
- [ ] Update docs/memory/avante.md with new features

---

### 3. oil.nvim - Multicursor & Horizontal Scroll
**Status**: ✅ CONFIG EXISTS (lua/plugins/extra/oil.lua)

**New Features**:
1. **Multicursor Support** (commit 756dec8)
   - Works with `multicursor.nvim` plugin
   - Currently NOT configured in oil.lua

2. **Horizontal Scrolling** (commit 2405570)
   - New actions for horizontal navigation
   - Better wide directory handling

3. **Float Params** (commit f55b25e)
   - `toggle_float` now accepts params
   - More flexible float configuration

**Current Config Analysis**:
```lua
-- lua/plugins/extra/oil.lua:44-108
- default_file_explorer = true ✅
- skip_confirm_for_simple_edits = true ✅
- Custom keymaps: <C-s> save, q close, <C-y> copy path ✅
- Float config: max_width=120, max_height=dynamic ✅
```

**Action Items**:
- [ ] Consider adding multicursor.nvim plugin
- [ ] Test horizontal scrolling actions (check :help oil)
- [ ] Update oil keymap documentation if needed
- [ ] Add to docs/memory/oil.md

---

### 4. fzf-lua - History Picker & Treesitter
**Status**: ✅ CONFIG EXISTS (myEditor.lua:915-919)

**New Features**:
1. **History Picker** (commit f75e50d)
   - Alias to oldfiles with buffers
   - Better recent files + buffer management

2. **Treesitter in live_grep** (commit 5aa0e4a)
   - Syntax highlighting in grep results
   - Better code readability

3. **Options Picker** (commit ce556fe)
   - Show option info in preview
   - Better vim option management

4. **Context Improvements** (commits 696f8d0, 578a11f)
   - Better window-local options
   - Fixed nvim_win_get_config for <0.10

**Current Config**:
```lua
-- myEditor.lua:915-919
opts = editor_keymaps.fzf_opts,
keys = editor_keymaps.keymaps.fzf_lua,
```

**Action Items**:
- [ ] Check utils/editor_keymaps.lua for fzf config
- [ ] Add history picker to keymaps (alternative to oldfiles)
- [ ] Test treesitter in live_grep for better UX
- [ ] Update docs/memory/fzf_lua.md

---

### 5. blink.cmp - Force Option & Better Keymaps
**Status**: ✅ CONFIG EXISTS (coding.lua:42-133, myEditor.lua:1225-1303)

**New Features**:
1. **Force Option** (commit 3182a89)
   - Accept completions without visual feedback
   - Faster workflow for power users

2. **Better Keymap Descriptions** (commit 20756cf)
   - More detailed keymap info
   - Better discoverability

3. **cmdline S-Tab Behavior** (commit 37ce860)
   - Match neovim's native select behavior
   - More intuitive

**Current Config Analysis**:
```lua
-- coding.lua:92 - keymap preset = "enter"
-- myEditor.lua:1247-1263 - Custom <C-c> for copilot source
-- myEditor.lua:1269-1301 - avante sources configured ✅
```

**Action Items**:
- [ ] Consider adding `force` option for faster completions
- [ ] Review keymap descriptions in current config
- [ ] Test S-Tab behavior in cmdline mode

---

### 6. render-markdown.nvim - Link Highlights & Priority
**Status**: ✅ CONFIG EXISTS (coding.lua:163-183, myEditor.lua:33-39)

**New Features**:
1. **link.highlight_title** (commit ae89236)
   - Better link rendering
   - More visual distinction

2. **Priority Fixes** (commit 0556144, 26097a4)
   - Lower priority for code highlights
   - on_yank and diagnostics now visible
   - Dash priority option added

**Current Config**:
```lua
-- coding.lua:164-168
opts = {}, -- minimal config
file_types = { "markdown", "Avante" } ✅
```

**Action Items**:
- [ ] Consider customizing link.highlight_title
- [ ] Test priority fixes (on_yank, diagnostics)
- [ ] Update docs/memory/render_markdown.md

---

## 📝 NOTABLE UPDATES - Medium Priority

### 7. CopilotChat.nvim
**Changes**:
- Multiple custom instruction files support (commit 90ebb50)
- .emmyrc.json for better Lua typing (commit d4c9ebe)

**Action**: Consider multiple instruction files if using custom prompts

---

### 8. nvim-lint
**Major Updates**:
- gitleaks linter added (commit 783da57)
- zizmor support (commit 6f6a969)
- markdownlint-cli2 stdin support (commit ca6ea12)
- proselint 0.16.0 compatibility (commit a19edd6)
- actionlint -stdin-filename support (commit ae64d64)

**Action**: Review if new linters are useful for projects

---

### 9. vim-test
**Changes**:
- neovim_sticky strategy improvements (commit 8f68254)
- vimux runner improvements (commit 02e59ee)
- csharp slash for pwsh (commit aaaff58)

**Action**: No changes needed unless using these features

---

## ✅ MINOR UPDATES - Low Priority

- **friendly-snippets**: CI improvements
- **lazy.nvim**: Dependency bumps only
- **mini.{ai,icons,pairs,statusline}**: Bug fixes
- **neogen**: Trailing space fixes
- **nvim-surround**: TSNode selection fix
- **nvim-web-devicons**: New icons (prisma, xslt)
- **grug-far.nvim**: Treesitter highlight fixes
- **img-clip.nvim**: Minor fixes
- **ts-error-translator.nvim**: AGENTS.md added

---

## 🎯 CONFIGURATION VALIDATION CHECKLIST

### Immediate (Breaking Changes)
- [ ] **gitsigns.nvim**: Check UI config for custom highlights
- [ ] **gitsigns.nvim**: Remove deprecated options
- [ ] **gitsigns.nvim**: Test blame functionality

### High Value (New Features)
- [ ] **avante.nvim**: Review MCP servers need
- [ ] **avante.nvim**: Test history management with snacks
- [ ] **oil.nvim**: Consider multicursor.nvim integration
- [ ] **fzf-lua**: Add history picker to keymaps
- [ ] **blink.cmp**: Test force option for faster workflow
- [ ] **render-markdown**: Test priority fixes

### Memory Bank Updates
- [ ] Create `docs/memory/avante.md` with new features
- [ ] Create `docs/memory/oil.md` with multicursor notes
- [ ] Create `docs/memory/fzf_lua.md` with history picker
- [ ] Create `docs/memory/gitsigns.md` with v2.0 changes
- [ ] Update `docs/memory/render_markdown.md` with priority info

---

## 📚 DIGDEEP TASKS

### Priority 1: Breaking Changes
1. **gitsigns v2.0**
   - Source: ~/.local/share/nvim/lazy/gitsigns.nvim
   - Check: CHANGELOG.md, lua/gitsigns/config.lua
   - Validate: Current config compatibility

### Priority 2: High-Value Features
2. **avante.nvim MCP servers**
   - Source: ~/.local/share/nvim/lazy/avante.nvim
   - Check: README.md for MCP configuration examples
   - Implement: If useful for workflow

3. **oil.nvim multicursor**
   - Source: ~/.local/share/nvim/lazy/oil.nvim
   - Check: Multicursor integration code
   - Decision: Add multicursor.nvim or skip

4. **fzf-lua history picker**
   - Source: ~/.local/share/nvim/lazy/fzf-lua
   - Check: lua/fzf-lua/providers/oldfiles.lua
   - Add: Keymap in utils/editor_keymaps.lua

---

## 🔗 REFERENCES

**Config Files**:
- lua/plugins/coding.lua (blink.cmp, render-markdown)
- lua/plugins/extra/myEditor.lua (avante, fzf-lua, oil keymaps)
- lua/plugins/extra/oil.lua (oil config)
- lua/plugins/ui.lua (gitsigns - NEEDS CHECK)
- lua/utils/editor_keymaps.lua (keymaps)

**Plugin Sources** (for DIGDEEP):
- ~/.local/share/nvim/lazy/avante.nvim
- ~/.local/share/nvim/lazy/gitsigns.nvim
- ~/.local/share/nvim/lazy/oil.nvim
- ~/.local/share/nvim/lazy/fzf-lua
- ~/.local/share/nvim/lazy/blink.cmp

**Documentation**:
- https://deepwiki.com/folke/snacks.nvim (for avante history + snacks)
- https://github.com/yetone/avante.nvim (MCP servers, ACP)
- https://github.com/lewis6991/gitsigns.nvim (v2.0 migration)

---

## ⚡ NEXT STEPS

1. **Run Neovim health checks**:
   ```vim
   :checkhealth gitsigns
   :checkhealth avante
   :checkhealth oil
   ```

2. **Test critical features**:
   - Open a git file and check gitsigns blame
   - Test avante with current provider
   - Open oil and test file operations

3. **Create memory banks**:
   - Document findings in docs/memory/
   - Note any issues or caveats

4. **Update configs** (if needed):
   - Apply breaking change fixes
   - Add high-value features
   - Test thoroughly

---

**Generated**: 2026-01-24
**Plugins Reviewed**: 21
**Breaking Changes**: 1 (gitsigns v2.0)
**High-Value Features**: 6
**Status**: READY FOR VALIDATION
