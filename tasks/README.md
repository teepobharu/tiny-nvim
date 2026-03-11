# Tasks

Tracks active work, ideas, and completed efforts in this Neovim configuration repo.

## Lifecycle

```
drafts/ -> open/ -> wip/ -> review/ -> completed/ -> archive/
```

| Stage      | Meaning                                              |
|------------|------------------------------------------------------|
| drafts/    | Idea or POC, not yet committed to                    |
| open/      | Actively being worked on                             |
| wip/       | Work in progress (optional, for longer tasks)        |
| review/    | Done, pending user verification or testing           |
| completed/ | Finished and verified — kept for reference           |
| archive/   | Abandoned, superseded, or irrelevant                 |

## Projects

Long-running work with dedicated directories (e.g., `cursor-migration/`) lives in `tasks/projects/` and contains multiple related tasks.

## File vs Dir

Use a **dir** (`task-name/README.md`) when a task has multiple files (plan, notes, completion summary, referenced scripts).

Use a **flat file** (`task-name.md`) when it is a simple investigation or single-outcome note.

## Frontmatter

Required on every task file. See [TASK-TEMPLATE.md](TASK-TEMPLATE.md).

## Naming

- Use kebab-case: `subproject-snacks-scope-select-persist.md`
- Be descriptive — avoid generic names like `NEXT-STEPS.md` or `FINAL-STATUS.md`
- Dir-based tasks: dir name = task slug, main file = `README.md`
- Always place files under a stage dir — never at `tasks/` root

## Moving a task

```bash
mv tasks/open/task-name tasks/review/task-name
```

Update the `status:` and `updated:` frontmatter fields after moving.

### Before moving to review/

The task file must have a filled-in **Verification** section (see [TASK-TEMPLATE.md](TASK-TEMPLATE.md)) containing:

- How to verify (approach, environment, preconditions)
- Exact commands to run (bash and/or vim commands)
- A checklist of expected outcomes for the user to tick off

A task without a Verification section is not ready for `review/`.

**IMPORTANT**: Only the USER can move tasks from `review/` to `completed/`.

## File References

**CRITICAL**: All file links in task files must use paths relative to git root WITHOUT `../` prefix.

```markdown
<!-- ✓ CORRECT -->
- [Snacks actions](lua/utils/snacks_actions.lua)
- [Memory doc](docs/memory/snacks_picker.md)

<!-- ✗ WRONG -->
- [Snacks actions](../../lua/utils/snacks_actions.lua)
```

## AI Agents

See [AGENTS.md](AGENTS.md) for the full AI agent workflow guide.
