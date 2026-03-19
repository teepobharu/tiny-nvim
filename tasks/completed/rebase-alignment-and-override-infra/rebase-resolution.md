# Rebase Resolution Detail

## Rebase Summary

- Branch: `nvim3wt1`
- Upstream base after rebase: `upstream/main` @ `78ece9f`
- Merge-base before rebase: `8c8ec75`
- Local commits replayed: 93
- Upstream commits absorbed: 50
- Major upstream shift: `snacks.nvim` power workflow -> `mini.nvim` baseline UI modules

## Major Upstream Changes Absorbed

- picker baseline moved to `mini.pick` / `mini.extra`
- UI baseline moved to `mini.files`, `mini.tabline`, `mini.bufremove`, `mini.diff`, `mini.statusline`, `mini.icons`
- terminal baseline moved to `jellydn/tiny-term.nvim`
- theme setup moved behind `lua/config/theme.lua`
- LSP bootstrap moved to per-filetype enable logic
- AI stack changed shape (`sidekick.nvim`, `extra/blink-copilot.lua`, extra-based Claude integrations)

## Conflict Groups That Mattered

### `init.lua`

Resolved toward upstream architecture:
- kept per-filetype LSP setup
- reinserted local startup/default-config hooks
- kept local YAML/marksman additions only where they fit the upstream structure

### `lua/plugins/coding.lua`

Resolved toward upstream plugin ownership:
- removed stale snacks references from lazydev
- accepted upstream move of copilot provider handling out of core config

### `lua/plugins/ui.lua` and snacks split

Resolved toward upstream baseline + local override split:
- accepted upstream mini baseline in core
- kept snacks as local power workflow in `lua/plugins/extra/`
- later local work moved snacks-specific overrides out of `myEditor.lua` into `mySnacks.lua`

### `lua/config/project.lua`

Kept both:
- `project.setup()` from upstream
- `myproject.setup()` for local project helpers and marker-based project settings flow

### `AGENTS.md`

Kept local repo-specific guidance because it is more relevant to this worktree than the generic upstream file.

## Behavior Alignment After the Rebase

### Resolved

- `<leader><space>` picker ownership was corrected by fixing snacks override order.
- `<M-s>` picker persistence behavior was corrected by fixing snacks override order.
- bufferline/gitsigns behavior was restored via `myUi.lua`.
- treesitter module mismatch stopped reproducing on the current plugin version/worktree state.

### Watchlist

- regenerate `lazy-lock.json` after the plugin graph stabilizes
- keep watching Claude terminal/PATH behavior if `claude` CLI exits with code `127`
- keep mini vs snacks responsibility split explicit so later rebases do not reintroduce keymap drift

## Plugin Collision Analysis: mini.ai / mini.pairs / nvim-surround / treesitter-textobjects

Investigated 2026-03-19 — checks for keymap, behavior, and text-object collisions between the four active editing plugins introduced or kept after the rebase.

### Active Plugin Matrix

| Plugin | Source File | Status | Purpose |
|--------|------------|--------|---------|
| mini.ai | `lua/plugins/coding.lua:317-343` | Active (xxMiniCode can mute) | Custom `a/i` textobjects |
| mini.pairs | `lua/plugins/coding.lua:312-316` | Active (xxMiniCode can mute) | Auto-close pairs on insert |
| nvim-surround | `lua/plugins/extra/myEditor.lua:454-470` | Active | Add/change/delete surrounds |
| nvim-treesitter-textobjects | `lua/plugins/extra/myEditor.lua:28` (dep) | Active | Treesitter-based textobject queries |

### Keymap Collision Check

#### nvim-surround default keymaps (from source `config.lua`)

| Mode | Key | Action |
|------|-----|--------|
| Normal | `ys` | Add surround |
| Normal | `yss` | Add surround to line |
| Normal | `yS` | Add surround (linewise) |
| Normal | `ySS` | Add surround to line (linewise) |
| Normal | `ds` | Delete surround |
| Normal | `cs` | Change surround |
| Normal | `cS` | Change surround (linewise) |
| Visual | `s` | Add surround (**overridden to `s` in config, upstream default is `S`**) |
| Visual | `gS` | Add surround (linewise) |
| Insert | `<C-g>s` | Add surround |
| Insert | `<C-g>S` | Add surround (linewise) |

#### mini.ai keymaps (built-in, non-configurable prefix)

| Mode | Key pattern | Action |
|------|-------------|--------|
| Normal/Visual | `a<key>` / `i<key>` | Around/inside textobject |
| Operator-pending | `a<key>` / `i<key>` | Same, used with `d`, `c`, `y`, `v` |

Custom textobject keys: `o` `f` `c` `t` `d` `e` `u` `U` (plus builtin `w`, `b`, `q`, etc.)

#### Treesitter incremental selection

| Mode | Key | Action | Source |
|------|-----|--------|--------|
| Normal/Visual | `<C-space>` | Init/expand selection | `lua/plugins/ui.lua:375` |
| Visual | `<bs>` | Shrink selection | `lua/plugins/ui.lua:378` |

### Collision Verdict

#### NO COLLISIONS FOUND between nvim-surround and mini.ai

- nvim-surround operates on `ys`, `ds`, `cs` prefixes (surround manipulation)
- mini.ai operates on `a`/`i` prefixes (textobject selection)
- These are completely different operator namespaces — no overlap

#### NO COLLISIONS between mini.ai and treesitter-textobjects

- mini.ai provides its own treesitter specs via `ai.gen_spec.treesitter` for `o`, `f`, `c` keys
- nvim-treesitter-textobjects is loaded as a **dependency** only — no explicit `textobjects = { select = {}, move = {}, swap = {} }` config block found
- mini.ai effectively **replaces** the textobject selection role of treesitter-textobjects by wrapping the same `@function.outer`, `@class.outer` queries
- treesitter-textobjects remains needed as the **query provider** (it ships the `textobjects` query files for each language), even though mini.ai handles the keymap layer

#### NO COLLISIONS between mini.pairs and nvim-surround

- mini.pairs operates in **insert mode only** (auto-close `(`, `[`, `{`, `"`, `'`, `` ` ``)
- nvim-surround operates in **normal/visual mode** (wrap/change/delete surrounds)
- Different modes, no overlap

#### visual mode `s` — low-risk override

- nvim-surround config sets `visual = "s"` (override from default `S`)
- This shadows Vim's built-in `s` in visual mode (substitute selected text)
- This is intentional in the config — not a regression from the rebase

### Potential Concerns (Not Collisions)

1. **treesitter-textobjects as unused weight**: Since mini.ai handles all `a/i` textobject keymaps via its own treesitter integration, the nvim-treesitter-textobjects `select`/`move`/`swap` modules are effectively unused. The plugin is still needed for its **query files** but could have its runtime modules disabled if startup time matters.

2. **mini.ai `f` key vs built-in**: mini.ai maps `f` to function textobject (`vaf`, `dif`). This does NOT conflict with Vim's `f` motion because `f` after an operator or `a`/`i` is a textobject key, while standalone `f` is the find-char motion. No issue.

3. **mini.ai `t` key vs built-in**: Similarly, mini.ai maps `t` to HTML tag textobject. Vim's built-in `it`/`at` also targets tags. mini.ai's version **overrides** the built-in with its own pattern-based matcher. This is intentional and generally an upgrade.

4. **xxMiniCode toggle**: If `xxMiniCode` is uncommented in `mydefault-nvim-config.lua`, both mini.ai and mini.pairs get disabled. In that scenario:
   - Auto-pairing stops (no fallback configured)
   - `a/i` textobjects fall back to Vim builtins only (no `o`, `f`, `c`, `d`, `e`, `u`, `U`)
   - nvim-surround and treesitter incremental selection remain unaffected

### Summary

**No keymap or behavior collisions exist** between the four plugins in the current configuration. They operate in distinct namespaces:

- mini.ai → `a/i` textobject namespace
- mini.pairs → insert-mode autopair
- nvim-surround → `ys`/`ds`/`cs` surround namespace
- treesitter-textobjects → query provider (runtime modules unused)

The only intentional override is visual-mode `s` (nvim-surround overriding Vim's substitute), which predates the rebase.

## Practical Takeaways

- upstream `mini.nvim` is the baseline; local `snacks` remains the advanced workflow layer
- behavior regressions usually came from override ordering, not missing features alone
- documenting conflict decisions immediately makes the next rebase far cheaper
