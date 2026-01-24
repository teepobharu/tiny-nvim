# TASKS
## WIP
2-codex
- git picker base
- git picker external

- rm action from files/qflist picker (with key d in normal mode only same key with explorer - should support multiple files selected possible to use trash system ?)

---
cwd cronos dedup and get the 


## Pickers

- session items -> finder style so find will refresh item
- buffer refresh toggle
  https://deepwiki.com/search/suggest-way-to-achieve-the-act_13b29d19-06dc-4383-bc2b-5871786b2b2e
  /Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua

## Mini

- copy path

## 20260122 session picker + refactor smaller files - wip

- [ ] copy picker + send to snacks support sidekick check
- [ ]

- [ ] To check
      terminals not working ?
      move below actions to snacks_actions_wip.lua
  - my_diff_compare
    move below actions to snacks_actions.lua
  - gitdiff_toggle_group
  - toggle_files_buffers
  - toggle_case_sensitivity
  - open_file_remote
  - open_mr

  - remove_qf_item
    TO FIX
    Low priority

- [ ] session not updated when remove from buffer

## 20260122 filter - wip

preferences: not want double picker

- currently after remove it not refresh record

## Explorer item debug info 20260107

### TODO

# DONE

Enhanced path copy picker (20260120)

- ✅ Added directory path variants to `generate_path_formats`
  - Generates 4 dirname formats: Dir Relative, Dir Git, Dir Relative CWD, Dir Absolute
  - Deduplication logic automatically merges duplicate paths with merged labels
  - Implementation: lua/utils/snacks_terminal.lua:1678-1758 (generate_path_formats)
- ✅ Enhanced picker preview with file/directory statistics
  - Shows Type (File/Directory), Size (human-readable), Lines (files only)
  - Shows Modified/Created timestamps, Permissions
  - Uses `vim.loop.fs_stat()` for accurate metadata
  - Preview now reads stats from selected item's path (picker_item.path) instead of fixed file_path
  - Implementation: lua/utils/snacks_terminal.lua:1760-1815 (get_path_stats), :1952-2020 (preview function)
- ✅ Added markdown link paste functionality
  - New keybinding `<C-m>` to paste path as markdown link: `[filename/dirname](path)`
  - Automatically extracts filename/dirname from path
  - Implementation: lua/utils/snacks_terminal.lua:1910-1930 (insert_markdown_link), :2037-2041 (action), :2066-2070 (keybinding)

Fixed insert to buffer bug (20260118)

- ✅ Simplified `insert_at_cursor` to use `nvim_put` API (similar to prompts_helper.lua)
- ✅ Only tracks original window (not buffer/cursor) - `nvim_put` handles cursor positioning
- ✅ Correctly inserts text into the buffer that was active when picker opened
- ✅ Much simpler implementation: ~10 lines instead of ~25 lines
- Implementation: lua/utils/snacks_terminal.lua:1800-1816 (insert_at_cursor), :1827-1834 (window capture in copy_path_select)

Requirement Feature
Create a snacks helper to in snacks utils to get from explorer / files to copy the path info to clipboard

Fixed (20260113)
.

- ✅ c-num keys: C-1, C-2, C-3, C-4 directly copy respective path formats
- ✅ Enhanced UI: Replaced vim.ui.select with Snacks picker showing preview
- ✅ Clean display: Removed numbered prefix (1., 2., etc.) from format list
- ✅ Preview shows: Path format label and actual path that will be copied

- Bind key
  - C-1 to copy selected relative path compared with previous buffer / active buffer should support ../ if the path is outside the current buffer
  - C-2 to copy relative path to git path
  - C-3 to copy relative path to current cwd
  - C-4 to copy absolute path
  - C-y to open vim.ui.select to choose between all the above options to copy + close the picker after copy

Sample explorer item debug info

```text
   Warn  21:40:03 notify.warn Debug: ~/.local/share/nvim3_jelly_tinynvim/lazy/snacks.nvim/lua/snacks/picker/actions.lua:741 {
  _path = "/Users/tharutaipree/Personal/mynotes/study/Programming/algorithms/agoda_interview/code_signals/shipWithinDays.js",
  child_match_only = false,
  dir = false,
  file = "/Users/tharutaipree/Personal/mynotes/study/Programming/algorithms/agoda_interview/code_signals/shipWithinDays.js",
  hidden = false,
  idx = 39,
  last = false,
  match_tick = 3,
  match_topk = 3,
  parent = {
    _path = "/Users/tharutaipree/Personal/mynotes/study/Programming/algorithms/agoda_interview/code_signals",
    child_match_only = true,
    dir = true,
    file = "/Users/tharutaipree/Personal/mynotes/study/Programming/algorithms/agoda_interview/code_signals",
    idx = 1,
    internal = true,
    match_tick = 3,
    match_topk = 3,
    open = true,
    score = 1,
    sort = "",
    text = ""
  },
  score = 82,
  sort = "#shipWithinDays.js ",
  text = "shipWithinDays.js",
  type = "file"
}
```

# 2. CWD Help set toggle and persist cwd picker state

## TODO

- subproject support toggling downward/upward
- subproject support relative path matches
- Check if git_files could work to filter out cwd by subproject ?
- show all subproject and set scope with pickers + persist / restore if persisted ?

## DONE

1. use get_initial_picker_state to set cwd for files and grep related pickers to get initial cwd state
2. use it to set existing mapping in editor_keymaps

# 3. Git selector on file

Similar to leader+G+B

- which open the files history of current buffer
- The picker has to support folder filter
- first step: show all commits on that files / folder with git diff between previous commit and current commit in preview secction
- once enter is pressed on a commit it show the diff of that commit on each files
- in this step use git diff preview and use the same mapping support for existing snacks git picker

# 4. Snacks Git diff/status

## Done

1 - keymap M-g diff + group + -> status switches currently

# 5. Git custom picker

- use opts to choose base against custom picker
- use default branch previewer/selectors - no remote

# Refactor actions, keys

## DONE

Integrated git ref metadata (20260120)

- ✅ `M.get_ref_metadata()` added to lua/utils/git.lua (lines 65-141)
- ✅ Extracts branch, fullref, ref, sha from git references
- ✅ Integrated into `create_git_file_actions` (editor_keymaps.lua:1004)
- ✅ Integrated into `get_ref_stats` (snacks_terminal.lua:599)
- ✅ Used in `show_file_list_picker` (snacks_terminal.lua:787-788)

Refactored picker keys and actions (20260115)

- ✅ Moved keys and actions settings from lua/plugins/extra/myEditor.lua to lua/utils/editor_keymaps.lua
