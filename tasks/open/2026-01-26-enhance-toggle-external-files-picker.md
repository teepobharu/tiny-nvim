**Enhance toggle_external: exclude current cwd from external fd/grep**

- What: update the `toggle_external` behaviour used by file pickers so it first injects ignore/exclude arguments into the underlying `fd` (files) or `rg`/`grep` (grep) command to exclude the current working directory from the external search.
- Why: when toggling to an external search we currently rerun `fd`/`rg` over the same cwd which causes duplicate/irrelevant results (or a confusing UX). Adding exclude args keeps the external search scoped as expected.
- Acceptance: toggling external from a files picker starts an `fd` command that contains `--exclude <path>` (or equivalent) for the current cwd; grep pickers add the matching `--glob '!<path/**'` / `--ignore-file` or `--hidden` rules for ripgrep so the current cwd is excluded; unit/manual test steps below pass.

- Implementation steps:
  - Locate the `toggle_external` helper used by Telescope (likely in `lua/plugins/telescope.lua` or an override in `lua/plugins/extra/mytelescope.lua`).
  - Add a small helper `build_ignore_args(cmd_type, cwd)` that returns an array of CLI args to exclude `cwd` from the search. Example intent:

```lua
-- Example helper (pseudo-code)
local function build_ignore_args(cmd_type, cwd)
  if not cwd or cwd == '' then return {} end
  if cmd_type == 'fd' then
    -- fd supports --exclude <pattern>
    return { '--exclude', vim.fn.fnamemodify(cwd, ':t') }
  elseif cmd_type == 'rg' then
    -- ripgrep supports negated globs
    local rel = vim.fn.fnamemodify(cwd, ':p')
    return { '--glob', string.format('!%s/**', rel) }
  end
  return {}
end
```

  - When `toggle_external` prepares the `fd` command array, call `build_ignore_args('fd', cwd)` and insert the returned args before launching the external process.
  - For grep pickers (ripgrep/grep), do the same using `build_ignore_args('rg', cwd)`.
  - Make sure to use absolute paths or consistent relative paths (use `vim.loop.cwd()` or `vim.fn.getcwd()` to obtain cwd) and properly escape spaces.
  - Keep the change small and in a helper so it can be unit-tested or reverted easily.

- Files to check / update (suggested):
  - `lua/plugins/telescope.lua`
  - `lua/plugins/extra/mytelescope.lua`
  - `lua/utils/telescope_helpers.lua` (create if helpful)

- Test / verify steps:
  1. Open Neovim in a project with nested folders and files.
  2. Run files picker and press the key mapped to `toggle_external`.
  3. Observe the spawned external `fd` command (or check the logs/verbose output) — it must include the `--exclude <cwd>` argument.
  4. Confirm results do not include files under that excluded path.
  5. Repeat for grep pickers and confirm `--glob '!<path/**'` (or equivalent) is present.

- Notes / edge cases:
  - If cwd is root (`/`) or home, avoid excluding it — guard against too-broad excludes.
  - If the picker already contains other exclude rules, merge them cleanly.
  - Ensure escaping of special characters and spaces in paths.

- Priority: high
- Estimate: 1–2 hours to implement + manual verification

- Checklist
  - [ ] Find `toggle_external` implementation
  - [ ] Add `build_ignore_args` helper
  - [ ] Inject args for fd file pickers
  - [ ] Inject args for rg/grep pickers
  - [ ] Add tests or manual verification steps
  - [ ] Document change in `docs/memory/telescope.md` if needed
