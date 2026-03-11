# LSP Client Manager Picker with Preview

**Status**: Review  
**Created**: 2026-03-12  
**Type**: Enhancement

## Overview

Added a new LSP client management picker using Snacks.nvim that provides a rich preview showing full paths, LSP server details, capabilities, and workspace information. The implementation preserves backward compatibility with existing `vim.ui.select` dialogs.

## Problem Statement

The existing LSP client management (<leader>Lr, <leader>Lx) used basic `vim.ui.select()` which:
- Showed no preview of LSP server details
- Displayed only truncated paths in the list
- Provided no visibility into server capabilities or attached buffers
- Made it hard to identify which LSP server to restart/stop

## Solution

### Implementation Approach

**Refactored shared logic** to avoid code duplication:
- Extracted `get_lsp_clients_info()` - Returns formatted client info
- Extracted `execute_lsp_action(client, action)` - Single source of truth for restart/stop
- Refactored `processLspClients()` to use helpers (backward compatible)

**Added new picker** using built-in Snacks functionality:
- `M.lsp_clients_picker()` - Uses `Snacks.picker.lsp_config({ attached = true })`
- Rich preview showing full paths, capabilities, workspace folders, buffers, settings
- In-picker actions via keybindings

### Files Modified

1. **[lua/utils/lsp_setup.lua](lua/utils/lsp_setup.lua)**
   - Added: `get_lsp_clients_info()` helper (lines 157-179)
   - Added: `execute_lsp_action()` helper (lines 181-196)
   - Refactored: `processLspClients()` to use helpers (lines 198-218)
   - Added: `M.lsp_clients_picker()` new picker function (lines 220-287)

2. **[lua/config/mykeymaps.lua](lua/config/mykeymaps.lua)**
   - Updated: LSP keymap descriptions for clarity (lines 821-824)
   - Added: `<leader>Ll` keymap for new picker (lines 826-831)

## Features

### New Keymap

- **`<leader>Ll`** - Opens LSP Clients Manager picker with preview

### Picker Keybindings

| Key | Action | Description |
|-----|--------|-------------|
| `<Tab>` | Select | Toggle selection (for multi-select operations) |
| `<C-r>` | Restart LSP | Restarts selected LSP(s), shows debug message, auto-refreshes (stays open) |
| `<C-x>` | Stop LSP | Stops selected LSP(s), shows debug message, auto-refreshes (stays open) |
| `<C-l>` | Refresh | Manually refresh LSP clients list (updates picker) |
| `<CR>` | Show hint | Displays hint about available actions (keeps picker open) |

**Multi-Select Support:**
- Use `<Tab>` to select multiple LSP clients
- `<C-r>` and `<C-x>` work on all selected items
- If no selection, operates on current item (under cursor)
- Messages adapt: "lua_ls is restarting" (single) or "Restarting 3 LSP clients" (multiple)

**Behavior**: Actions do NOT close the picker. Instead:
- Show `Snacks.debug()` message (single message, no duplicates)
- Execute the action on all selected LSP clients (or current if none selected)
- Auto-refresh picker after 200ms to update state
- Picker remains open for further actions
- Use `<C-l>` to manually refresh at any time

### Preview Information

The preview panel shows:
- **Server name and ID**
- **Installation path** (full absolute path)
- **Enabled status**
- **Filetypes** supported
- **Root markers** (.git, tsconfig.json, etc.)
- **Workspace folders** (full absolute paths)
- **Attached buffer IDs**
- **Server capabilities** (completion, hover, rename, formatting, etc.)
- **Settings and init options**

### Backward Compatibility

**Preserved existing functionality:**
- `<leader>Lr` - LSP Restart (select dialog) - **UNCHANGED**
- `<leader>Lx` - LSP Stop (select dialog) - **UNCHANGED**
- `<leader>LX` - LSP Stop All - **UNCHANGED**
- `<leader>Li` - LSP Info (:check lsp) - **UNCHANGED**
- Commands: `:RestartLspClients`, `:StopLspClients`, `:StopAllLspClients` - **UNCHANGED**

## Code Quality

### Code Reuse
- **Zero duplication** - Shared logic extracted into helper functions
- Both old and new implementations use same helpers
- Single source of truth for LSP actions

### Design Patterns
- **Separation of concerns** - Data collection, formatting, and actions separated
- **Backward compatible** - Old behavior completely preserved
- **Snacks native** - Uses built-in `lsp_config` picker (tested, maintained)

### Lines of Code
- **Total changes**: ~115 lines
  - 40 lines: Extracted helpers
  - 20 lines: Refactored processLspClients
  - 67 lines: New lsp_clients_picker
  - 8 lines: Keymap additions

## Usage Examples

### Example 1: View LSP Details

1. Press `<leader>Ll`
2. Navigate to desired LSP client (e.g., `lua_ls`)
3. Preview automatically shows full details:
   ```
   # `lua_ls`
   
   - **cmd**: `lua-language-server`
   - **installed**: /usr/local/bin/lua-language-server
   - **enabled**: yes
   - **workspace**: /Users/user/dotfiles/.config/nvim3_jelly_tinynvim
   - **buffers**: 1, 5, 12
   - **server capabilities**:
     * textDocument/completion: true
     * textDocument/hover: true
     ...
   ```

### Example 2: Restart LSP

1. Press `<leader>Ll`
2. Select LSP client (e.g., `lua_ls`)
3. Press `<C-r>`
   - Shows debug message: "lua_ls is restarting"
   - Restarts the LSP client
   - Picker refreshes and stays open
   - Can continue managing other LSP clients

### Example 3: Stop LSP

1. Press `<leader>Ll`
2. Select LSP client (e.g., `ts_ls`)
3. Press `<C-x>`
   - Shows debug message: "ts_ls is stopping"
   - Stops the LSP client
   - Picker refreshes and stays open
   - Client removed from list (if stopped successfully)

### Example 4: Multi-Select Restart

1. Press `<leader>Ll`
2. Navigate to first LSP (e.g., `lua_ls`)
3. Press `<Tab>` to select it (marked)
4. Navigate to second LSP (e.g., `ts_ls`)
5. Press `<Tab>` to select it (marked)
6. Press `<C-r>`
   - Shows debug message: "Restarting 2 LSP clients"
   - Restarts both LSP clients
   - Picker refreshes and stays open
   - No duplicate messages

### Example 5: Quick Hint

1. Press `<leader>Ll`
2. Press `<CR>` on any item
3. Shows: "LSP: lua_ls — Press <C-r> to restart, <C-x> to stop"
4. Picker stays open, can now press `<C-r>` or `<C-x>`

## Testing

### Manual Testing Checklist

- [ ] **Backward Compatibility**
  - [ ] `<leader>Lr` opens vim.ui.select and restarts LSP
  - [ ] `<leader>Lx` opens vim.ui.select and stops LSP
  - [ ] `:RestartLspClients` command works
  - [ ] `:StopLspClients` command works

- [ ] **New Picker**
  - [ ] `<leader>Ll` opens Snacks picker
  - [ ] Preview shows full paths (not truncated)
  - [ ] Preview shows LSP server name and version
  - [ ] Preview shows server capabilities
  - [ ] Preview shows workspace folders
  - [ ] Preview shows attached buffers
  - [ ] `<C-r>` on single item shows "lua_ls is restarting" (no duplicates)
  - [ ] `<C-x>` on single item shows "lua_ls is stopping" (no duplicates)
  - [ ] `<Tab>` selects items for multi-select
  - [ ] `<C-r>` on multiple items shows "Restarting X LSP clients"
  - [ ] `<C-x>` on multiple items shows "Stopping X LSP clients"
  - [ ] Multi-select actions execute on all selected items
  - [ ] `<C-l>` manually refreshes picker (client list updates)
  - [ ] `<CR>` shows hint notification (picker stays open)
  - [ ] Footer shows: "<Tab> select · <C-r> restart · <C-x> stop · <C-l> refresh · <CR> info"

- [ ] **Edge Cases**
  - [ ] No LSP clients attached → Picker shows empty list
  - [ ] Multiple LSP clients → All shown correctly
  - [ ] LSP with multiple workspaces → All workspaces shown in preview
  - [ ] Very long paths → List truncates, preview shows full path
  - [ ] Multi-select with non-existent client → Shows warning for that client only

### Test Environment

Test with multiple LSP servers attached:
- `lua_ls` (Lua LSP)
- `ts_ls` or `typescript-tools` (TypeScript)
- `pyright` (Python)

## Verification

### How to Verify

1. **Environment**: Neovim with at least one LSP client attached
2. **Commands to run**:
   ```vim
   " Test backward compatibility
   <leader>Lr    " Should open vim.ui.select
   <Esc>
   
   " Test new picker
   <leader>Ll    " Should open Snacks picker with preview
   
   " In picker, test actions:
   " 1. Test single-select:
   "    - Select an LSP client (e.g., lua_ls)
   "    - Press <C-r>
   "      → Should show: "lua_ls is restarting" (single message, no duplicates)
   "      → Picker should auto-refresh after 200ms and stay open
   " 
   " 2. Test multi-select:
   "    - Navigate to lua_ls, press <Tab> (select)
   "    - Navigate to ts_ls, press <Tab> (select)
   "    - Press <C-r>
   "      → Should show: "Restarting 2 LSP clients" (not individual messages)
   "      → Both clients should restart
   "      → Picker should auto-refresh and stay open
   "
   " 3. Test stop action:
   "    - Press <C-x> on a client
   "      → Should show: "ts_ls is stopping" (single message)
   "      → Picker should auto-refresh and stay open
   "
   " 4. Test manual refresh:
   "    - Press <C-l>
   "      → Should show: "Refreshing LSP clients list"
   "      → Picker should refresh immediately
   "
   " 5. Test hint:
   "    - Press <CR>
   "      → Should show hint: "LSP: lua_ls — Press <C-r> to restart, <C-x> to stop"
   "      → Picker should stay open
   ```

3. **Expected Outcomes**:
   - ✅ Backward compatible keymaps work unchanged
   - ✅ New picker opens with preview
   - ✅ Preview shows full absolute workspace paths
   - ✅ Preview shows LSP server name, version, capabilities
   - ✅ `<C-r>` shows single debug message (no duplicates)
   - ✅ `<C-x>` shows single debug message (no duplicates)
   - ✅ Multi-select works: `<Tab>` to select, actions execute on all
   - ✅ Multi-select shows summary message ("Restarting X LSP clients")
   - ✅ `<C-l>` manually refreshes picker (client list updates immediately)
   - ✅ `<CR>` shows hint (picker stays open)
   - ✅ Footer hints visible: "<Tab> select · <C-r> restart · <C-x> stop · <C-l> refresh · <CR> info"

## Benefits

✅ **Rich preview** - Full paths, capabilities, workspace info visible  
✅ **Backward compatible** - All existing mappings work unchanged  
✅ **Zero duplication** - Shared logic extracted into helpers  
✅ **Multi-select support** - Restart/stop multiple LSPs at once with `<Tab>`  
✅ **Intuitive UX** - `<C-r>`/`<C-x>` for action, `<CR>` for hint  
✅ **Picker stays open** - Actions don't close picker, allows multiple operations  
✅ **No duplicate messages** - Single debug message per action (silent helper execution)  
✅ **Smart messages** - Adapts to selection count ("lua_ls is restarting" vs "Restarting 3 LSP clients")  
✅ **Debug feedback** - Shows clear messages via Snacks.debug  
✅ **Auto-refresh** - Picker updates after actions to show current state  
✅ **Clean code** - ~160 lines total, well-structured  
✅ **Snacks native** - Uses built-in tested picker  
✅ **Discoverable** - Footer hints show available actions  

## Future Enhancements (Optional)

- [ ] Add `<C-i>` to open `:LspInfo` for selected client
- [ ] Show LSP log file location in preview
- [ ] Add filtering by filetype
- [ ] Add bulk actions (restart all, stop all)
- [ ] Custom formatting for preview (icons, colors)

## Related

- Task: Add LSP client picker with preview
- Files: [lua/utils/lsp_setup.lua](lua/utils/lsp_setup.lua), [lua/config/mykeymaps.lua](lua/config/mykeymaps.lua)
- Snacks docs: LSP config picker
- Memory: [docs/memory/snacks.md](docs/memory/snacks.md) (if exists)

---

**Implementation Date**: 2026-03-12  
**Ready for Review**: Yes  
**Requires User Testing**: Yes
