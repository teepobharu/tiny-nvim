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

## USER Checklsit

- [ ] c-s not work but c-g (check why)
- [ ] picker last commit works what about other / and custom ref picker ?
- [ ] verify custom ref picker keymap works with git_last_commit_show + custom git ref picker
  - [ ] when c-k it should start from the current ref base (not from head) fix this behavior better to make it scalable by accepting base and current ref (left/right ref) so it can be reused and trigger opt update each picker can use new value to reflect on the new ref

- [ ] Test new `git_diff_merge_base()` picker with increment/decrement
- [ ] Test fallback to HEAD when merge-base equals HEAD (no commits ahead)
- [ ] Test workdir diff toggle (`<C-w>`) when comparing with HEAD
- [ ] Verify staged-only mode works (fallback without workdir toggle)
- [ ] Verify workdir mode shows all changes (staged + unstaged)

Enhancement

- [ ] Unify this picker and allow input initial ref and base
  - [ ] then some key to toggle the variant
- [ ] Dont limit the ref on to base or HEAD just alert that it go beyond head+/-1 and allow to
- [x] merge-base - done show commit range count + ref +warn
  - [x] Fallback to HEAD when merge-base equals HEAD
  - [x] Workdir diff toggle for HEAD comparisons
  - [ ] move keymap from mykeymap to editor_keymaps.lua
- [ ] custom ref - not yet
- [ ] last commit - work but not show commit range count + ref + warn when reach merge-refs / head
- [ ] MAPPING
  - [ ] Remap the key to switch they c-j/k to have the correct mnemonic for left (specific commit) and move base commit closer to (HEAD)
- [ ] Unify all mapping on custom git to follow this approach
- [ ] better score matcher searchable in git status M/D/A
- [ ] slight lag when change base fast / scroll list fast is debounce available ?

## New: Merge-Base Picker Details

### `git_diff_merge_base()` Function

**Purpose**: Compare current branch against origin's default branch using merge-base as the reference point. Allows navigating through history with increment/decrement controls.

**Primary Keymap**: `<leader>fu` (Git diff merge-base)

**How it works**:

1. Detects origin default branch (origin/main, origin/master, or configured default)
2. Calculates merge-base between current branch and origin default
3. Shows files changed between merge-base and HEAD
4. Supports navigation through merge-base history

**Navigation**:

- `<C-j>`: Move closer to merge-base (earlier in history)
- `<C-k>`: Move further from merge-base (later in history)
- `<C-w>`: Toggle workdir diff (only when comparing with HEAD)
- Updates file list and counts dynamically
- Prevents going before merge-base commit

**Fallback Behavior**:

When merge-base equals HEAD (no commits ahead of origin):

- Automatically falls back to comparing with the merge-base ref (which equals HEAD)
- Shows "HEAD (staged)" or "HEAD (workdir)" in title
- **Staged mode** (default): `git diff --cached base_ref` - Shows only staged changes from base_ref
- **Workdir mode** (toggled): `git diff base_ref` - Shows all changes from base_ref (staged + unstaged)
- Use `<C-w>` to toggle between staged and workdir modes
- **Base ref is always included** - Never omitted even when at HEAD

**Features**:

- [x] Dynamic base ref tracking with state management
- [x] File status indicators (Added/Modified/Deleted)
- [x] Git diff preview with syntax highlighting
- [x] Commit count display in notifications
- [x] Changed file count tracking
- [x] Bounds checking (can't go before merge-base)
- [x] Automatic fallback to HEAD when merge-base equals HEAD
- [x] Workdir diff toggle for HEAD comparisons
- [x] Staged-only mode (default when at HEAD)
- [x] Workdir mode shows all changes (staged + unstaged)

**Keymaps available**:

- `<leader>fu`: Open merge-base picker
- Custom actions in picker: open_file_diff, open_remote_at_ref
- Navigation: `<C-j>` forward, `<C-k>` backward
- Workdir toggle: `<C-w>` (HEAD only)

**Files modified**:

- `[snacks_pickers.lua:L686-L817](lua/utils/snacks_pickers.lua#L686)` - New `git_diff_merge_base()` function
- `[snacks_terminal.lua:L207](lua/utils/snacks_terminal.lua#L207)` - Wrapper function
- `[mykeymaps.lua:L213-215](lua/config/mykeymaps.lua#L213)` - Keymap binding

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
- [ ] Add verification checklist to prompt user confirmation for keymap behavior

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

### Verification Checklist (User)

- [ ] Confirm custom git keymap works in `git_last_commit_show()`
- [ ] Confirm custom git keymap works in custom git ref picker
- [ ] Confirm keymap still works for `show_file_list_picker()` base ref navigation

### Follow-up Todo

- [x] Add custom git ref picker option to set base ref via merge-base with default origin remote
  - [x] Implemented: `git_diff_merge_base()` picker function
  - [x] Compares current branch with origin default using merge-base
  - [x] Supports increment/decrement navigation via `<C-j>`/`<C-k>` keys
  - [x] Displays range: `[merge-base]:hash..HEAD:hash (N commits)`
  - [x] Includes file status indicators and diff preview
  - Reference: `[snacks_pickers.lua:L683-L817](lua/utils/snacks_pickers.lua#L683)`

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
