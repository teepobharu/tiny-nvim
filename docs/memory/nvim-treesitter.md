# Tree-sitter parser and query compatibility

## Lua `Invalid field name "operator"` (2026-11-03)

Neovim 0.12.4 reported this whenever Lua highlighting started:

```text
Query error at 74:3. Invalid field name "operator":
  operator: _ @operator)
```

The daily profile had an old generated parser at
`stdpath("data")/lazy/nvim-treesitter/parser/lua.so` (August 2026,
revision marker `db16e76558122e834ee214c8dc755b4a3edc82a9`). It took precedence
over Neovim's bundled parser and did not expose the `operator` field used by
the highlight query. The installed nvim-treesitter checkout was `c9f9ed6c`.

The exact error reproduced under `-u NONE` with only the parser and query
runtime paths: lazy-local-patcher and Noice were not loaded. Noice displayed
the error; this reproduction does not indicate a failed plugin patch.

### Recovery applied

1. Reproduced the failure with a copy of the stale parser in an isolated
   `NVIM_APPNAME=nvim_ts_fix` worktree profile.
2. Removed the override in that isolated profile. Neovim's bundled ABI 15 Lua
   parser compiled all six query groups: highlights, folds, indents, injections,
   locals, and textobjects. A Lua sample parsed and produced 18 highlight captures.
3. Moved only the daily profile's stale `parser/lua.so` and its
   `parser-info/lua.revision` marker into
   `stdpath("state")/treesitter-backups/20261103-033106/`. The backup includes
   metadata and a SHA-256 checksum. Nothing was deleted from the backup.
4. Repeated the same query/highlighter checks against the daily profile's runtime
   paths. They passed with the bundled Lua parser selected automatically.

No plugin update, lockfile change, patch reapplication, or Homebrew binary
modification was needed. Existing Neovim processes may retain the loaded old
parser: save work and reopen the affected editor instance to load the fix.

### Diagnose before updating

Inspect the actual ordered parser candidates and query sources:

```vim
:lua print(vim.inspect(vim.api.nvim_get_runtime_file("parser/lua.*", true)))
:lua print(vim.inspect(vim.treesitter.query.get_files("lua", "highlights")))
:lua print(vim.inspect(vim.treesitter.language.inspect("lua").fields))
:lua assert(vim.treesitter.query.get("lua", "highlights"))
```

An installed plugin revision does not establish parser compatibility: generated
parsers can survive plugin updates, and a bundled parser can be shadowed by a
stale plugin or site parser. Validate query compilation before selecting a
replacement; the bundled-parser result above is specific to the versions tested.

For a future managed reinstall, update only Lua using the installed plugin's
documented installer and verify the resulting parser path and queries. The
current nvim-treesitter installer invokes `tree-sitter build`; that CLI was absent
from the diagnostic shell, so a parser rebuild was not used for this repair.
Do not use a blanket `Lazy sync` to diagnose this error because it also touches
unrelated locally patched plugins.

Upstream guidance: [nvim-treesitter installation and parser updates](https://github.com/nvim-treesitter/nvim-treesitter#installation).
