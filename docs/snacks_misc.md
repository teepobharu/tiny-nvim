# Mini
- copy path

# 1. Explorer item debug info  20260107

## TODO



## DONE

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

# 2. Help set toggle and persist cwd picker state

1. use get_initial_picker_state to set cwd for files and grep related pickers to get initial cwd state
2. use it to set existing mapping in editor_keymaps

Check if git_files could work to filter out cwd by subproject ?

# 3. Git selector on file

Similar to leader+G+B 
- which open the files history of current buffer
- The picker has to support folder filter
- first step: show all commits on that files / folder with git diff between previous commit and current commit in preview secction
- once enter is pressed on a commit it show the diff of that commit on each files
- in this step use git diff preview and use the same mapping support for existing snacks git picker

# 4. Snacks Git diff/status
1 - keymap M-g diff + group + -> status switches currently 
# 5. Git custom picker 
- use opts to choose base against custom picker 
- use default branch previewer/selectors - no remote

# Refactor actions, keys

## DONE 20260115 
- move to keys and actions settings from lua/plugins/extra/myEditor.lua to lua/utils/editor_keymaps.lua


add git action to get branch, fullref, ref, sha from refName/alias within git utils and used it in create_git_file_actions  and inside get_ref_stats
