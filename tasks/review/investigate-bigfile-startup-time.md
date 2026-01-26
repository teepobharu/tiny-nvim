---
title: "Investigate startup time for large lsp.log with bigfile handling"
status: "review"
assignee: "ai"
created: 2026-01-25
priority: "medium"
related:
  - [snacks config](lua/plugins/snacks.lua)
  - [myEditor notes](lua/plugins/extra/myEditor.lua)
  - [init.lua](init.lua)
---

## Objective

Measure startup time when opening a large file (`lsp.log`, 100MB) using the current config, compare with Snacks bigfile disabled, and capture a clean baseline.

## Investigation Summary

### What Was Done

- Used headless `nvim --startuptime` runs to measure startup with a 100MB file.
- Compared current config (Snacks bigfile enabled) vs temporary toggle (bigfile disabled).
- Captured a clean baseline with `--clean`.

### Commands Used

```sh
# With current config (Snacks bigfile enabled)
NVIM_APPNAME=nvim3_jelly_tinynvim nvim --headless -n -i NONE \
  --startuptime /tmp/nvim-startup-with-bigfile.log \
  /Users/tharutaipree/.local/state/nvim3_jelly_tinynvim/lsp.log +qa

# With Snacks bigfile disabled (temporary toggle in config)
NVIM_APPNAME=nvim3_jelly_tinynvim nvim --headless -n -i NONE \
  --startuptime /tmp/nvim-startup-without-bigfile.log \
  /Users/tharutaipree/.local/state/nvim3_jelly_tinynvim/lsp.log +qa

# Clean baseline
nvim --headless --clean -n -i NONE \
  --startuptime /tmp/nvim-startup-clean.log \
  /Users/tharutaipree/.local/state/nvim3_jelly_tinynvim/lsp.log +qa
```

## Results

**Target file:** `/Users/tharutaipree/.local/state/nvim3_jelly_tinynvim/lsp.log` (100MB)

| Scenario | NVIM STARTED time |
| --- | --- |
| Snacks bigfile enabled | 1758.912 ms |
| Snacks bigfile disabled | 1040.253 ms |
| `--clean` baseline | 165.147 ms |

**Bigfile trigger:** `FileType bigfile` autocommands were present in the enabled run.

## Files Modified

None (Snacks bigfile was toggled temporarily and restored).

## Implementation Notes

- `--startuptime` writes to the path you pass; use a separate log file (not `lsp.log`) to avoid overwriting or polluting the log.
- Snacks bigfile currently adds ~700ms to startup in this scenario, but it also disables expensive features for large files.

## Success Criteria

- [x] Startup times captured for enabled/disabled bigfile and clean baseline
- [x] Bigfile detection confirmed in the enabled run
- [x] No config changes left behind after testing

## Verification Checklist

- [ ] Re-run the commands above and confirm similar timings on your machine
- [ ] Verify that opening `lsp.log` interactively no longer freezes when bigfile is enabled
