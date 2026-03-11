---
title: "Short descriptive task title"
status: draft | open | wip | review | completed | archive
priority: high | medium | low
created: YYYY-MM-DD
updated: YYYY-MM-DD
refs: # Optional: plugin commit info
  # Example: abcdef [tag:v2.0.1] @2025-01-03 12:00:33 +0700 feat(overseer): enhance picker UX
parent: # Optional: for sub-tasks
  - [Parent Task](tasks/projects/parent-name.md)
related:
  - [Display Name](path/to/file.lua)
  - [Another file](docs/memory/plugin.md)
---

## Objective

Clear statement of what needs to be accomplished and why.

## Context

Background information, related files, plugins involved, and relevant history.

## Implementation Plan

- [ ] Step 1
- [ ] Step 2
- [ ] Step 3

## Success Criteria

How to know the task is complete. What does "done" look like?

## Verification

> **REQUIRED** before moving to `review/`. Fill this section so the user can
> manually verify your work by following these instructions.

### How to verify

Describe the verification approach: what environment is needed (e.g., restart
Neovim, check specific picker, test in a certain project type), what
preconditions must be met, and what to look for.

### Commands

```bash
# Exact shell commands to run
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

```vim
" Exact Neovim commands to run
:Lazy check
:lua print(vim.inspect(require("utils.mypath").some_function()))
```

### Checklist

Write from the user's perspective — what they will observe, not what you did.

- [ ] Expected outcome A is observed (be specific)
- [ ] Expected outcome B is observed (be specific)
- [ ] No regressions in related functionality
- [ ] Feature works in both normal and edge cases

## References

- [Related documentation](docs/memory/plugin.md)
- [Implementation](lua/plugins/extra/my_plugin.lua:100-150)
- [Upstream source](~/.local/share/nvim3_jelly_tinynvim/lazy/plugin-name/)
