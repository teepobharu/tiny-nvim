# 1. Explorer item debug info  20260107

Requirement Feature 
Create a snacks helper to in snacks utils to get from explorer / files to copy the path info to clipboard

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
