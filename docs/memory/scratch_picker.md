# Multi-source Scratch Picker

## Entry points

- `<leader>nS` opens [scratch_notes_picker.lua](../../lua/utils/scratch_notes_picker.lua).
- `<leader>ns` remains the native `Snacks.scratch.select()` picker.
- `<leader>no` remains the native `Snacks.scratch()` buffer creator.
- The standalone `scripts/everything.fzf/scratch.fzf` workflow still coexists as the richer CLI fallback.

## Sources and controls

The picker mirrors the CLI roots and environment overrides:

| Source | Default root | Today's target |
|---|---|---|
| `daily-work` | `~/Documents/daily` | `YYYYMMDD/user.md` |
| `daily-personal` | `~/Personal/mynotes/Daily` | `YYYY-MM-DD.md` |
| `raw-notes` | `~/dotfiles/ai/agents/raw/notes` | `YYYYMMDD_raw.md` |
| `scratch-files` | `~/dotfiles/.config/myscripts/scratch` | none |

- `<A-s>` cycles `daily-work -> daily-personal -> raw-notes -> scratch-files -> all` and refreshes in place.
- `<A-g>` switches between the file catalog and `Snacks.picker.grep`; grep is restricted to the active source roots.
- `<A-e>` shows or hides zero-byte entries in the `scratch-files` source. They start hidden to keep the catalog useful when scratch buffers are first created.
- `<C-n>` creates today's note for the active daily source, or prompts for a daily source from `all`/`scratch-files`.
- Missing daily roots still show a creatable `[new]` row. Missing scratch roots return an empty list without errors.
- Blank or whitespace-only path overrides are treated as unset, matching the
  CLI's `${VAR:-default}` behavior and preventing daily targets from resolving
  under the filesystem root.

## Implementation caveats

- File mode uses a dynamic finder so source cycling rescans the filesystem without stacking picker windows.
- File and grep modes close/reopen only when the finder type changes; the visible query is carried between `filter.pattern` and `filter.search`.
- Grep always receives explicit roots, including missing ones. An empty `dirs` list would make Snacks grep fall back to the current working directory.
- The file preview delegates to Snacks' file previewer so it displays real content; missing daily targets use a small creation preview.
- Keep source discovery and date/path helpers independent from the UI so they remain testable with temporary roots.
- `scratch-files` merges the configured filesystem root with `Snacks.scratch.list()` at runtime. Native entries are de-duplicated by file path and preserve their filetype, branch, CWD, and byte-size metadata for filtering and compact labels.

## Verification

```bash
NVIM_APPNAME=nvimwt3a nvim --headless -u NONE -i NONE \
  --cmd 'set rtp^=/Users/tharutaipree/dotfiles/.config/nvimwt3a' \
  -l tests/test_scratch_notes_picker.lua
```

Manual picker behavior still requires user verification in `NVIM_APPNAME=nvimwt3a`.
