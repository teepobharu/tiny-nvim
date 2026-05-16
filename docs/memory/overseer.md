# Overseer.nvim - Task Runner

## Custom Actions (`lua/plugins/extra/myOverseer.lua`)

### Duplicate Task
- Clones task via `task:clone()` and starts as new task with "(copy)" suffix
- Key: `d` in task list

### Copy Actions
- **Copy task command** (`y`): Copies full command string to `+` clipboard
- **Copy task name** (`Y`): Copies task name to `+` clipboard

### Enhanced Render
- Status icons: `󰐪 ` PENDING, `󰐠 ` RUNNING, ` ` SUCCESS, ` ` FAILURE, `󰃔 ` CANCELED, `󰆴 ` DISPOSED
- Uses `overseer.render` helpers for consistent formatting

## Key Mappings (Task List)

| Key | Action |
|-----|--------|
| `<CR>` / `?` | Action picker |
| `<A-d>` | Duplicate task (clone + start immediately) |
| `A` | Clone, open editor to change cmd/name, then start |
| `y` | Copy command |
| `Y` | Copy name |
| `a` | Edit task in-place (existing task) |
| `<C-r>` | Restart |
| `<C-c>` / `<C-s>` | Stop |
| `dd` | Dispose |
| `<A-q>` | Output → quickfix |
| `q` / `<C-q>` | Close |

## `A` — Edit and run as new task (clone flow)

1. Clones task via `task:clone()` → new task with "(copy)" suffix, added to list as PENDING
2. Opens `task_editor` on the **clone** (not the original)
3. On `:w` (submit): starts the edited clone
4. On cancel (`q`/`<C-c>`): force-disposes the pending clone so it doesn't linger

## API Reference

- `task:clone()` - Creates deep copy via `Task.new(self:serialize())`
- `task:serialize()` - Returns `overseer.TaskDefinition` with cmd, cwd, env, strategy, components
- Actions registered via `opts.actions` table with `condition(task)` and `run(task)`
