## Snacks Actions — External Toggle / Ref / Unused Review

### 1. Buffers External Filtering + unused filter functions
- **Status: Resolved.** The `filter_buffers_outside_git_root` and `filter_buffers_nonexistent` functions (snacks_actions.lua) create sub-pickers (new picker windows). The transform-based `external` toggle filters in-place and is the preferred approach. Sub-picker functions remain as unused alternatives.
- Buffer external filter now uses scope-based CWD filtering with `<A-s>` traversal and `<A-S>` persistence.
- **Latest fix**: Buffer transform properly handles scope filtering even without external toggle — `<A-s>` filters to show INSIDE scope, `<A-e>` inverts to show OUTSIDE scope.

### 2. Code Reference picker vs Select Path Format picker unification
- **Status: Investigated.** Different contexts (current buffer cursor vs picker item) — complementary, not duplicates. No unification needed.
- **Fixed:** `@` format in `copy_path_select` was using space (`@path line:col`) instead of colon (`@path:line:col`). Now consistent with `code_ref.lua`.

### 3. Buffer toggle_external logic + scope cycling
- **Status: Implemented.** See [main task](tasks/review/2026-01-26-enhance-toggle-external-files-picker.md).
- Buffer `<A-e>`: shows buffers outside scope CWD (or all external when no scope)
- Buffer `<A-s>`: upward subproject traversal (short-lived), scopes buffer list to INSIDE the selected level
- Buffer `<A-S>`: subproject picker with `vim.g.picker_buffer_cwd_state_value` (separate from files)
- Returning to initial scope (index 1) clears `_buffer_scope_cwd` to show all buffers
