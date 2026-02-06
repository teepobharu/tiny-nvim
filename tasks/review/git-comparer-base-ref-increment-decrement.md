---
title: "Add increment/decrement controls for git comparer base ref"
status: "review"
assignee: "ai"
created: 2026-02-05
priority: "medium"
refs:
  - "[Implementation Summary](../../lua/utils/snacks_pickers.lua#L715-L960)"
  - "[Debug Output Notifications](../../lua/utils/snacks_pickers.lua#L435-L440)"
  - "[git_last_commit_show Enhanced](../../lua/utils/snacks_pickers.lua#L371-L576)"
related:
  - [Git utils](lua/utils/git.lua)
  - [Snacks pickers](lua/utils/snacks_pickers.lua)
  - [Editor keymaps](lua/utils/editor_keymaps.lua)
---

## Objective

Enable increment/decrement navigation of the base reference in git comparer picker. Users should be able to move through the commit history relative to the current branch/HEAD, with constraints to prevent going to the current commit or beyond the base reference (master/origin).

## Checklist

- [x] Implement base ref increment/decrement logic in `snacks_pickers.lua`
  - [x] Track current base ref in picker state
  - [x] Get commit history between base ref and HEAD
  - [x] Implement `move_base_ref_forward()` (closer to current branch)
  - [x] Implement `move_base_ref_backward()` (further from current branch)
  - [x] Add bounds checking (don't increment to HEAD, don't decrement beyond master)
- [x] Add keymaps for increment/decrement (`<C-j>` / `<C-k>`)
- [x] Update picker title to show active base ref
  - [x] Display short hash (e.g., `abc1234`)
  - [x] Display branch name if available
  - [x] Format: "Changed Files vs {branch}/{hash}"
- [x] Add footer help text showing available control keys
- [x] Update file-list picker view with dynamic base ref feedback
- [x] Add debug output showing commit navigation and file counts
- [x] Extend functionality to `git_last_commit_show()` for commit navigation
- [ ] Manual testing in actual Neovim session to verify list updates properly

## Implementation Summary

### Changes Made

1. **Fixed picker refresh mechanism (CRITICAL FIX)**:
   - **Root cause**: `picker:update()` doesn't update title or re-run finder
   - **Solution**: Use `picker:refresh()` which calls `:find({ refresh = true })`
   - **Implementation**:
     - Update picker title: `picker.title = "Commit: " .. display`
     - Call `picker:update_titles()` to update UI
     - Call `picker:refresh()` to re-run finder with new state
   - Applied to both `git_last_commit_show()` and `show_file_list_picker()`

2. **Cleaned up debug logging**:
   - Removed excessive DEBUG notifications
   - Kept essential user feedback: commit/ref display and file count
   - Format: `"Commit: {branch} ({hash}) [HEAD~X] ({file_count} changed files)"`

3. **Refactored `git_last_commit_show()`** to support commit navigation:
   - Added state management for `current_commit` (same pattern as base_ref)
   - Implemented `move_commit_forward()` and `move_commit_backward()` functions
   - Supports navigating through 100 most recent commits
   - Keymaps: `<C-j>` next (newer), `<C-k>` prev (older)
   - Footer displays available navigation controls

4. **Key implementation details**:
   - State-based architecture allows mutable commit/ref tracking across picker lifetime
   - Custom actions reference current state dynamically
   - Preview and format functions use current base_ref/commit
   - Title updates dynamically on each navigation
   - Both file list AND title now refresh correctly

### Issues address by user on the changes done

- [ ] the preview toggle does not seems to work
- [ ] Research on how to optimized once scroll down the list quickly through the list the process start delaying and wait observed that might related to png / large file diffs , understand how list and preview is generated and what can cause it
- [ ]

### Testing Checklist

**`show_file_list_picker()` (git comparer):**

- [ ] Press `<C-j>` to navigate forward (closer to HEAD)
- [ ] Press `<C-k>` to navigate backward (away from HEAD)
- [ ] Verify notifications show file count for each ref
- [ ] Verify file list updates with new changed files
- [ ] Verify title shows current base ref
- [ ] Test bounds: can't go to HEAD, can't go before initial base ref

**`git_last_commit_show()` (commit navigator):**

- [ ] Press `<C-j>` to navigate to newer commits
- [ ] Press `<C-k>` to navigate to older commits
- [ ] Verify notifications show file count for each commit
- [ ] Verify file list updates with each commit's changed files
- [ ] Test bounds: can't go beyond HEAD, can't go before oldest commit
- [ ] Verify diff preview updates properly
