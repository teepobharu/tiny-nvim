# Neo-tree Snacks Keybinds Integration

## Issues & Fixes

- **Issue:** Neo-tree does not natively expose hovered filepath for external actions.
  - **Fix:** Use `neo-tree.sources.manager.get_state('filesystem')` and `tree:get_node()` to get hovered node path.

- **Issue:** Snacks.nvim grep command may require correct escaping of filepaths.
  - **Fix:** Use `vim.fn.fnameescape` for safe command invocation.

- **Issue:** File picker may not include hidden files by default.
  - **Fix:** Pass `{ hidden = true }` to Telescope's `find_files` picker.

- **Issue:** `Snacks.lazygit.log_file()` reads the current buffer path, not the hovered Neo-tree node.
  - **Fix:** Bind Neo-tree `<leader>gf` to `utils.snacks_actions.open_lazygit_log_path(node:get_id())`; the helper opens LazyGit with `--filter` and supports file or directory nodes.

## `<C-o>` Open in External App (Neo-tree) / `gGO` (buffer)

- **Neo-tree:** `<C-o>` → `open_external` command → `utils.open_external.pick(path)`.
- **Buffer:** `gGO` (normal mode) → `utils.open_external.pick_current()` — resolves current buffer path.
- **Picker:** Snacks picker when available; falls back to `vim.ui.select`.
- **Footer:** shows the exact path currently targeted by the picker.
- **Preview:** hidden by default; `<A-p>` toggles a panel that shows a similar executable bash command for the selected app.
- **`<M-y>` / `<A-y>` copies:** bash command string to `+` register (e.g. `cursor /path/to/file`).
- **Path-copy mappings:** `Y`, `Yp`, `YP`, and `YY` copy into unnamed, `+`, and `*` registers.
- **`<M-u>` / `<A-u>` or `-`:** reopen picker for the parent directory of the current target path.
- **Detection:** `vim.fn.executable(cli)` or `vim.uv.fs_stat("/Applications/<App>.app")`. Missing apps hidden.
- **Icons:** one prefix icon only. Editor and IDE apps share ``; browsers use `󰖟`; system default uses a single `󰀻`.

### Apps by Category

| Category | Apps |
|----------|------|
| Editor | Cursor, VSCode, Zed, Sublime Text, Codex |
| IDE | WebStorm, IntelliJ IDEA, PyCharm, GoLand, DataGrip, Rider, Xcode |
| Browser | Chrome, Safari, Firefox, Arc, Microsoft Edge, Default Browser |
| Notes | Obsidian (in vault), Obsidian (seed config + open), Obsidian (hotkeys + profile switcher), Obsidian (copy path + open) |
| File Manager | Finder (reveal) |
| System | System Default |

### Obsidian Smart-Open Logic

Four entries, shown based on context:

1. **Obsidian (in vault)** — shown when path is inside a registered vault (read from `~/Library/Application Support/obsidian/obsidian.json`). Fires `obsidian://open?path=<encoded>`.
2. **Obsidian (seed config + open)** — always shown for files and directories. For files, it seeds the parent directory; for directories, it seeds that directory. Prompts to bootstrap `.obsidian/` from `~/Personal/mynotes/.obsidian/` via `rsync` (excludes workspace files, cache, copilot-index-*.json), skips if `.obsidian/` already exists, then fires `obsidian://open?path=<encoded>`.
3. **Obsidian (hotkeys + profile switcher)** — always shown for files and directories. Minimal seed: copies `hotkeys.json`, writes `community-plugins.json` with only `settings-profiles`, and copies only `.obsidian/plugins/settings-profiles/`. User can then open Obsidian, reload if needed, and switch/load a full profile from the Settings Profiles plugin.
4. **Obsidian (copy path + open)** — shown when path is not inside a known vault. Copies path to clipboard, opens Obsidian app; user manually registers as vault via "Open folder as vault".

**Vault registry:** `~/Library/Application Support/obsidian/obsidian.json` — `vaults` map, each `{path, ts, open}`. Longest-prefix match determines vault membership.

**Seed behavior:** the seed action copies the base `.obsidian/` config with `rsync`; it does **not** symlink the config. The new vault gets its own `.obsidian/` directory after seeding.

**Profile-switcher seed behavior:** copies only the hotkey file and the Settings Profiles plugin files. It writes a minimal `community-plugins.json` so only `settings-profiles` starts enabled; the plugin itself later copies selected profile files into/out of `.obsidian/` when saving/loading a profile, not symlinks.

**Settings-profiles auto-sync:** `rsync` copies `plugins/settings-profiles/data.json` which carries the `devices` map. New vault auto-attaches `main` profile — no manual config.

**Gotcha:** `obsidian://new` URI doesn't create a vault from an existing dir; `obsidian://open` + vault-accept prompt is the correct flow.
**Gotcha:** Exclude `copilot-index-*.json` (80MB) from rsync to keep bootstrap fast.

## References
- [myneotree.lua](../../lua/plugins/myneotree.lua)
- [mysnacks.lua](../../lua/plugins/mysnacks.lua)
- [open_external.lua](../../lua/utils/open_external.lua)
- [tasks/drafts/neotree_snacks_keybinds.md](../../tasks/drafts/neotree_snacks_keybinds.md)

## Manual Verification Checklist
- [ ] `<space>/` in Neo-tree triggers Snacks grep on hovered file/folder
- [ ] `<space>f` in Neo-tree opens file picker (includes hidden files)
- [ ] `<C-o>` in Neo-tree opens external picker with one prefix icon per row and footer path
- [ ] `<leader>gf` in Neo-tree opens LazyGit filtered to the hovered file or directory
- [ ] `<A-p>` in external picker toggles command preview
- [ ] `<A-y>` in external picker copies the selected bash command
- [ ] `<A-u>` or `-` in external picker reopens picker at the parent directory
- [ ] `-` in Neo-tree filesystem moves root up one directory
