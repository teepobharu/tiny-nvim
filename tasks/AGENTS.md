# AGENTS.md — Tasks Workflow for AI Agents

## Purpose

The `tasks/` directory tracks work in this Neovim configuration repo. Use it to pick up work across sessions, log progress, and record decisions for future reference.

## Directory Structure

```
tasks/
├── projects/   # Long-running projects with dedicated working directories
├── drafts/     # Ideas or POCs, not yet committed to
├── open/       # Actively being worked on
├── wip/        # Work in progress (optional, use for longer tasks)
├── review/     # Done, pending user verification or testing
├── completed/  # Finished — kept for reference
└── archive/    # Abandoned, superseded, or irrelevant
```

## Picking Up a Task

1. Check `tasks/open/` for active work
2. Read the task's `README.md` or `.md` file fully before starting
3. Note the `status:` and `priority:` in frontmatter
4. Update `updated:` date when you make progress

## Creating a Task

- **Single outcome**: `tasks/open/task-name.md` with frontmatter
- **Multi-artifact**: `tasks/open/task-name/README.md` + sibling files
- Use [TASK-TEMPLATE.md](TASK-TEMPLATE.md) as the starting point

## Moving a Task

| From       | To         | When                                      |
|------------|------------|-------------------------------------------|
| drafts/    | open/      | Committed to working on it                |
| open/      | wip/       | Started work (optional, for longer tasks) |
| wip/       | review/    | Work done, needs verification or testing  |
| review/    | completed/ | Verified, tested, accepted by USER        |
| any        | archive/   | Abandoned, superseded, or irrelevant      |

```bash
# Example: complete a task
mv tasks/wip/task-name tasks/review/task-name
# then update status: in frontmatter
```

**IMPORTANT**: Only the USER can move tasks from `review/` to `completed/`. AI agents MUST NOT do this.

## Before moving to review/

You MUST fill in the **Verification** section of the task file before moving it to `review/`. This section is for the user to manually confirm the work.

It must include:
1. **How to verify** — approach, required environment, preconditions
2. **Commands** — exact shell commands to copy-paste and run
3. **Checklist** — concrete expected outcomes as `- [ ]` items

Write the checklist from the user's perspective: what they will see or observe, not what you did. Each item should be independently verifiable.

Example:
```markdown
## Verification

### How to verify
Restart Neovim to load changes. Test in a project with multiple subprojects.

### Commands
```bash
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

```vim
" Test the new feature
:lua print(require("utils.mypath").get_sub_project_dir())
```

### Checklist
- [ ] Picker opens showing subproject list
- [ ] Pressing ENTER changes CWD to selected subproject
- [ ] Status line updates to show new CWD
```

## Naming Conventions

- kebab-case filenames
- Descriptive, not generic — no `NEXT-STEPS.md`, `FINAL-STATUS.md`
- Dir-based tasks: dir name = task slug, entry point = `README.md`

## What NOT To Do

- Do not leave files at `tasks/` root — always place under a stage dir
- Do not create a new file per evolution — update the existing task file
- Do not use placeholder dates (`YYYY-MM-DD`) — fill them in
- Do not scatter one task's files across multiple stage dirs
- Do not move tasks from `review/` to `completed/` — only the USER does this

## Distinction: tasks/ vs docs/

- `tasks/` — ephemeral work tracking, progress notes, checklists
- `docs/` — permanent learnings, issue resolutions, reference material

When a task produces a reusable insight, extract it to `docs/memory/` before closing the task.

## Nvim-Specific Guidelines

### File References

**CRITICAL**: All file links in task files must use paths relative to git root WITHOUT `../` prefix.

```markdown
<!-- ✓ CORRECT: Relative to git root -->
- [Snacks actions](lua/utils/snacks_actions.lua)
- [Memory doc](docs/memory/snacks_picker.md)
- [Plugin config](lua/plugins/extra/myEditor.lua)

<!-- ✗ WRONG: Do not use ../ relative paths -->
- [Snacks actions](../../lua/utils/snacks_actions.lua)
- [Memory doc](../docs/memory/snacks_picker.md)
```

**Rationale**: Git-root-relative links work consistently regardless of where the task file is located.

### Code References

When referencing specific code locations, use the format:
- `file.lua:line` for single line
- `file.lua:L100-L200` for line ranges
- `file.lua:100` also acceptable

Example:
```markdown
- [Implementation](lua/utils/mypath.lua:427-688)
- [Marker constant](lua/utils/mypath.lua:4-22)
```

### Plugin-Related Tasks

When working with plugins, include:

1. **Plugin commit reference** in frontmatter:
   ```yaml
   refs:
     - hash [tag:version] @date commit-message
   ```

2. **Link to docs/memory/** for permanent learnings:
   ```markdown
   related:
     - [Plugin Documentation](docs/memory/plugin-name.md)
   ```

3. **Installed plugin source** for deep investigation:
   ```
   ~/.local/share/nvim3_jelly_tinynvim/lazy/<plugin-name>/
   ```

### Projects vs Tasks

| Type | Location | Purpose |
|------|----------|---------|
| **Project** | `tasks/projects/` | Multi-session work with dedicated working directory |
| **Task** | `tasks/open\|wip\|review/` | Single-session or short work items |

Projects have their own working directories (e.g., `cursor-migration/`) and contain multiple related tasks.

Example project structure:
```
cursor-migration/
├── README.md           # Project documentation
├── configs/            # Configuration samples
├── docker/             # Docker setup
└── samples/            # Code samples/templates
```

Link tasks to projects:
```markdown
parent:
  - [Cursor Migration Project](tasks/projects/cursor-migration.md)
related:
  - [Project Dir](cursor-migration/)
```

## Integration with CLAUDE.md

See root [CLAUDE.md](../CLAUDE.md) for:
- Code style guidelines (stylua, 120 columns, 2-space indent)
- Plugin override patterns (`my*.lua` files)
- LSP configuration (built-in Neovim 0.11+ LSP)
- MCPHub setup and AI tool integration
- File editing guidelines (when to use `my*.lua` overrides)

## Quick Reference

| Need | Command/Location |
|------|------------------|
| Pick up work | Check `tasks/open/` |
| Create task | Use `tasks/TASK-TEMPLATE.md` |
| Move to review | Fill verification section first |
| Document learning | Extract to `docs/memory/` |
| Reference code | Use git-root-relative paths |
| Link plugin source | `~/.local/share/nvim3_jelly_tinynvim/lazy/<name>/` |
