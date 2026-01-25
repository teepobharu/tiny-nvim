# Task Tracking Guide

Simple task tracking system for Claude Code sessions with handoff and verification.

## Task File Structure

Tasks are stored in markdown files under `tasks/` directory:

```
tasks/
└── drafts/      # Task ideas and planning
├── open/        # Approved by user and is ready to be worked on
├── wip/         # Work in progress
├── review/      # Completed, awaiting user verification
├── done/        # Do not move to this unless told to/move by user
```

### Task File Format

Each task file uses frontmatter + markdown:

```markdown
---
title: "Brief task description"
status: "open|wip|review|done|draft"
assignee: "ai|user"
created: 2026-01-24
priority: "high|medium|low"
refs: [plugin commit_ref + tags that is + commit_date ]
[Example] : abcdef [tag:v2.0.1] @2025-01-03 12:00:33 +0700 feat(overseer): move validation to builder, enhance picker UX, add debug util
parent:
  - [Parent Task](tasks/parent.md)
related:
  - [Display name](path/to/file.lua)
  - [Another file](docs/memory/plugin.md)
---

## Objective

Clear statement of what needs to be accomplished

## Checklist

- [ ] Step 1
- [ ] Step 2
- [ ] User verification

## Implementation Notes

Details, approaches, code patterns

## Success Criteria

How to know task is complete
```

### Link Format Rule

**IMPORTANT**: All file links in task files must use paths relative to git root WITHOUT `../` prefix.

```markdown
<!-- ✓ CORRECT: Relative to git root -->

- [Snacks actions](lua/utils/snacks_actions.lua)
- [Memory doc](docs/memory/snacks_picker.md)
- [Plugin config](lua/plugins/mysnacks.lua)

<!-- ✗ WRONG: Do not use ../ relative paths -->

- [Snacks actions](../../lua/utils/snacks_actions.lua)
- [Memory doc](../docs/memory/snacks_picker.md)
```

**Rationale**: Git-root-relative links work consistently regardless of where the task file is located in the directory hierarchy.

## Using Task Tracking

### Create a Task

When starting work on a new feature or refactoring:

```bash
# In Claude Code, use the TaskCreate utility
# Automatically tracked with unique ID
```

### Mark Progress

```bash
# When starting work
TaskUpdate(taskId, status="in_progress")

# When done
TaskUpdate(taskId, status="completed")
```

## Task Completion Template

Each task should include:

1. **Summary** - What was done
2. **Files Modified** - List all changes
3. **Features** - What functionality was added/improved
4. **Verification Checklist** - How to verify the work

### Example: Completed Task

```
✓ Task #1: Refactor goto_file_line() and extract reusable file reference utilities

  Status: COMPLETED

  What was done:
  - Created lua/utils/file_reference.lua with 3 reusable utilities
  - Reduced goto_file_line() from 250 → 80 lines
  - Extracted parsing, resolution, and anchor-jumping logic

  Files Modified:
  ✓ Created: lua/utils/file_reference.lua
  ✓ Modified: lua/config/mykeymaps.lua
  ✓ Modified: docs/misc_nvim.md

  Features:
  - Git-style refs: file#L2, file#L2-L3, file#L2C3
  - IDE-style: file:100:5
  - Smart path priority (git root first vs buffer cwd first)
  - Markdown anchors: file.md#done

  Verification Checklist:
  - [ ] Test gF with IDE-style paths (file:100)
  - [ ] Test gF with git-style paths (file#L100)
  - [ ] Test markdown anchor jumping
  - [ ] No regressions with existing behavior
```

## Handoff & Verification

### Before Handoff to User

1. Create task with clear completion summary
2. Include verification checklist
3. List all modified files with line numbers
4. Document key features and usage

### User Verification

The user can verify work by:

1. Reading task description and verification checklist
2. Running manual tests from the checklist
3. Reviewing modified files
4. Testing edge cases

### Task Status Flow

```
pending → in_progress → completed
```

## Quick Reference

### View All Tasks

```bash
TaskList()
```

### Get Task Details

```bash
TaskGet("1")
```

### Find Completed Tasks

```bash
TaskList()  # Filter by status="completed"
```

## Benefits

✓ **Clear Handoff** - User knows exactly what was done
✓ **Easy Verification** - Checklist items to test
✓ **Code References** - File paths and line numbers should be included (path relative to git) ie [Add autorefresh:test logic](lua/plugins/snacks.lua:L23-L90)
✓ **Progress Tracking** - See what's pending vs completed
✓ **Continuity** - Easy to resume from previous session

## Example Workflow

1. **Session Start**

   ```
   User: "Add dark mode support"
   → TaskCreate() with subject and description
   → TaskUpdate(status="in_progress")
   ```

2. **During Work**

   ```
   → Implement feature
   → Update documentation
   → Add test samples
   ```

3. **Session End**

   ```
   → TaskUpdate(status="completed") with verification checklist
   → User sees clear summary of what to test
   ```

4. **Next Session**
   ```
   User: "Let me verify the dark mode work"
   → TaskGet("1") to review what was done
   → Follow verification checklist
   → Mark any new issues as pending tasks
   ```
