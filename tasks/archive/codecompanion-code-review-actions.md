# CodeCompanion: Code Review Actions for Current Buffer

**Status**: Review  
**Created**: 2026-03-11  
**Type**: Feature Enhancement

## Overview

Added three AI-powered code review actions to CodeCompanion for reviewing git changes in the current buffer. Actions support both normal mode (entire file) and visual mode (selected lines only).

## Problem Statement

Need a quick way to get AI code reviews for git changes without leaving Neovim. Existing solutions:
- External PR review tools (GitHub Copilot, GitLab AI) - require context switching
- Manual copy-paste of diffs - cumbersome and error-prone
- No support for reviewing partial changes (selected lines only)

## Solution

### Features Implemented

Three CodeCompanion actions accessible via `:CodeCompanionActions`:

1. **Review Staged Changes (Current Buffer)** - Reviews `git diff --staged`
2. **Review Unstaged Changes (Current Buffer)** - Reviews `git diff`
3. **Review All Changes (Current Buffer)** - Reviews both staged + unstaged

**Key Features:**
- ✅ Normal mode: Reviews entire file changes
- ✅ Visual mode: Reviews only selected line range
- ✅ Full file context provided to AI (via CodeCompanion context mechanism)
- ✅ Structured review format with prioritized categories
- ✅ Manual approval required (no auto-submit)

### Files Modified

1. **[lua/utils/my_ai_prompts.lua](lua/utils/my_ai_prompts.lua)** (new file)
   - Centralized AI prompts for reusability
   - `EMPTY_PROMPT_CODECOMPANION` - Empty prompt template
   - `CODE_REVIEW_INSTRUCTIONS()` - Review prompt function

2. **[lua/utils/my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua)** (+187 lines)
   - `get_buffer_git_diff()` - Generic git diff with line filtering
   - `get_buffer_staged_diff()` - Staged changes wrapper
   - `get_buffer_unstaged_diff()` - Unstaged changes wrapper
   - `get_buffer_all_diff()` - Combined staged + unstaged
   - `filter_diff_by_range()` - Visual selection filtering helper

3. **[lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua)** (+150 lines)
   - Three review actions in `prompt_library`
   - Imports prompts from `my_ai_prompts.lua`
   - Context integration for full file content

4. **[docs/memory/codecompanion.md](docs/memory/codecompanion.md)** (+340 lines)
   - Comprehensive documentation of the feature
   - Usage examples and testing guide

## Implementation Details

### Review Categories (Prioritized)

The AI analyzes changes in this order (bugs first):

1. **🐛 Bugs & Logic Errors** (HIGHEST PRIORITY)
   - Null/undefined dereferences
   - Off-by-one errors
   - Race conditions
   - Edge case handling
   - Type mismatches

2. **🔒 Security Issues**
   - Injection vulnerabilities
   - Auth bypasses
   - Hardcoded secrets
   - Input validation

3. **⚡ Performance**
   - Algorithmic complexity
   - Memory leaks
   - N+1 queries
   - Blocking operations

4. **✨ Best Practices**
   - Code style
   - Naming conventions
   - Error handling
   - Test coverage

### Context Integration

Each action includes full file content via:

```lua
context = {
  {
    type = "file",
    path = function()
      return vim.api.nvim_buf_get_name(0)
    end,
  },
}
```

The AI receives:
- Full file content (context)
- Specific git diff (prompt)

This allows better analysis:
- Understanding broader code structure
- Identifying breaking changes
- Suggesting fixes aligned with existing patterns

### Visual Selection Filtering

When called from visual mode (lines 45-78):
1. Parse git diff into hunks (`@@ ... @@` sections)
2. Check if hunk overlaps with selection range
3. Keep only overlapping hunks
4. Reconstruct filtered diff

Only changes in selected lines are sent to AI for review.

### Error Handling

| Case | Message |
|------|---------|
| Unsaved buffer | `Error: Buffer not saved. Save file before reviewing changes.` |
| Not in git repo | `Error: File not in a git repository.` |
| No changes | `No staged/unstaged changes in current buffer` |
| No changes in selection | `No changes in selected line range (X-Y)` |

## Usage Examples

### Pre-commit Review

```vim
" Review what you're about to commit
git add <files>
:edit <file>
:CodeCompanionActions → Review Staged Changes
" Get AI feedback before committing
```

### WIP Review

```vim
" Review work in progress
:edit <file>
:CodeCompanionActions → Review Unstaged Changes
" Quick feedback while developing
```

### Focused Review

```vim
" Review only changed function
:edit <file>
V     " Visual line mode
45G   " Go to line 45
78G   " Go to line 78
:'<,'>CodeCompanionActions → Review Unstaged Changes
" AI reviews just that section
```

### Complete Review

```vim
" Review everything
:CodeCompanionActions → Review All Changes
" Both staged and unstaged feedback
```

## Testing

### Quick Function Test

```vim
" Test utility functions
:lua print(require('utils.my_codecompanion_utils').get_buffer_unstaged_diff())
" → Should show unstaged diff

" With visual selection (lines 10-20)
:lua local ctx = {start_line=10, end_line=20}; print(require('utils.my_codecompanion_utils').get_buffer_unstaged_diff(ctx))
" → Should show only changes in lines 10-20
```

### Integration Test Workflow

1. **Create test changes:**
   ```bash
   vim lua/test.lua  # Edit file
   git add -p        # Stage partial changes
   # Leave some unstaged
   ```

2. **Test Normal Mode:**
   ```vim
   :CodeCompanionActions → Review Staged Changes
   " Verify: Shows staged diff only
   " Verify: No auto-submit
   ```

3. **Test Visual Mode:**
   ```vim
   V10G30G  " Select lines 10-30
   :'<,'>CodeCompanionActions → Review Unstaged Changes
   " Verify: Shows only lines 10-30
   ```

4. **Test All Changes:**
   ```vim
   :CodeCompanionActions → Review All Changes
   " Verify: Shows both staged and unstaged sections
   ```

5. **Test Errors:**
   - Unsaved buffer → Error message
   - Not in git → Error message
   - No changes → Info message

## Verification

### How to Verify

1. **Environment**: Neovim with CodeCompanion and git repo
2. **Setup**: Make some changes to a file (staged and unstaged)
3. **Commands to run**:
   ```vim
   " Test staged review
   :CodeCompanionActions
   " Select: Review Staged Changes (Current Buffer)
   " Expected: Shows git diff --staged with review prompt
   
   " Test visual mode filtering
   V
   10G
   30G
   :'<,'>CodeCompanionActions
   " Select: Review Unstaged Changes (Current Buffer)
   " Expected: Shows only changes in lines 10-30
   ```

4. **Expected Outcomes**:
   - ✅ Actions appear in CodeCompanionActions picker
   - ✅ Normal mode: Shows full file diff
   - ✅ Visual mode: Shows only selected line range diff
   - ✅ Full file context included (AI has access to entire file)
   - ✅ Structured review format with categories
   - ✅ Manual approval required (not auto-submitted)
   - ✅ Error messages for edge cases

## Benefits

✅ **Fast feedback** - Review changes without leaving Neovim  
✅ **Contextual** - AI has full file context for better analysis  
✅ **Flexible** - Review entire file or just selected lines  
✅ **Structured** - Prioritized categories (bugs first)  
✅ **Safe** - Manual approval required before sending  
✅ **Reusable** - Centralized prompts in `my_ai_prompts.lua`  

## Limitations & Future Enhancements

**Current Limitations:**
- Only reviews current buffer (not multiple files)
- Line numbers reference diff hunks, not absolute file lines
- No branch comparison (e.g., vs main/upstream)

**Potential Enhancements:**
- [ ] Add "Review vs Branch" action (compare against main/upstream)
- [ ] Add focused review actions (security-only, performance-only)
- [ ] Support reviewing entire changesets (multiple files)
- [ ] Configurable review depth (quick vs deep analysis)
- [ ] Integrate with existing PR review workflows

## Configuration

**Auto-submit**: Disabled (manual review required)  
**Available in**: Actions picker (`:CodeCompanionActions`)  
**Not slash commands**: By design (intentional workflow)  
**Visual mode**: Supported (filters diff to selection)  
**Default model**: Uses CodeCompanion default (typically Copilot gpt-5-mini)

To use different model for deeper review:

```lua
-- In lua/plugins/extra/myAi.lua
["Review Staged Changes (Current Buffer)"] = {
  opts = {
    adapter = {
      name = "copilot",
      model = "gpt-4o",  -- More thorough analysis
    },
  },
  -- ...
}
```

## Related

- Task: Add CodeCompanion code review actions
- Files: 
  - [lua/utils/my_ai_prompts.lua](lua/utils/my_ai_prompts.lua)
  - [lua/utils/my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua)
  - [lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua)
- Memory: [docs/memory/codecompanion.md](docs/memory/codecompanion.md) (section 12)

---

**Implementation Date**: 2026-03-11  
**Ready for Review**: Yes  
**Requires User Testing**: Yes
