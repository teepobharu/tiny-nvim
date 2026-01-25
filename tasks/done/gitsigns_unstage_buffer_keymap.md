---
title: "Add GitSigns unstage buffer keymap"
status: "done"
assignee: "ai"
created: 2026-01-25
priority: "low"
related:
  - [ui.lua](lua/plugins/ui.lua)
  - [gitsigns.md](docs/memory/gitsigns.md)
---

## Objective

Add missing `reset_buffer_index()` keymap to GitSigns configuration for unstaging entire buffers while preserving working directory changes.

## Problem

GitSigns had keymaps for:
- `stage_buffer()` - Stage all hunks (`<leader>ghS`)
- `reset_buffer()` - **Discard** all changes (`<leader>ghR`)
- `undo_stage_hunk()` - Undo last stage in session (`<leader>ghu`)

But was **missing**:
- `reset_buffer_index()` - Unstage all hunks (keeps changes)

This meant users had no way to unstage an entire buffer without losing their changes.

## Changes Summary

### What Was Done

Added `<leader>ghU` keymap to unstage buffer:

```lua
map("n", "<leader>ghU", gs.reset_buffer_index, "Unstage Buffer")
```

### Files Modified

✓ **Modified**: [lua/plugins/ui.lua:302](lua/plugins/ui.lua:302)
  - Added unstage buffer keymap

✓ **Modified**: [docs/memory/gitsigns.md:241-280](docs/memory/gitsigns.md:241)
  - Added comprehensive staging/unstaging keymap documentation
  - Added comparison tables
  - Added workflow examples

## Implementation Details

### Key Differences Between Functions

| Function | Git Equivalent | Keeps Changes? | Affects Index? | Affects Working Dir? |
|----------|---------------|----------------|----------------|---------------------|
| `stage_buffer()` | `git add` | ✅ Yes | Stages | No change |
| `reset_buffer_index()` | `git reset HEAD` | ✅ Yes | Unstages | No change |
| `reset_buffer()` | `git checkout --` | ❌ No | No change | **Discards changes** |
| `undo_stage_hunk()` | (session only) | ✅ Yes | Unstages | No change |

### Mnemonic Convention

Buffer-level operations use **UPPERCASE**:
- `<leader>ghS` - **S**tage buffer (uppercase = whole buffer)
- `<leader>ghU` - **U**nstage buffer (uppercase = whole buffer) ← **NEW**
- `<leader>ghR` - **R**eset buffer (uppercase = DANGEROUS/permanent)

Hunk-level operations use **lowercase**:
- `<leader>ghs` - **s**tage hunk (lowercase = single hunk)
- `<leader>ghu` - **u**ndo stage hunk (lowercase = deprecated)
- `<leader>ghr` - **r**eset hunk (lowercase = single hunk)

## Complete GitSigns Staging Keymaps

### Buffer-Level Operations

| Keymap | Function | Git Equivalent | Destructive? | Description |
|--------|----------|----------------|--------------|-------------|
| `<leader>ghS` | `stage_buffer()` | `git add <file>` | No | Stage all hunks in buffer |
| `<leader>ghU` | `reset_buffer_index()` | `git reset HEAD <file>` | No | Unstage buffer (keeps changes) |
| `<leader>ghR` | `reset_buffer()` | `git checkout -- <file>` | ⚠️ YES | Discard all changes in buffer |

### Hunk-Level Operations

| Keymap | Function | Description |
|--------|----------|-------------|
| `<leader>ghs` | `stage_hunk` | Stage hunk under cursor |
| `<leader>ghr` | `reset_hunk` | Reset hunk under cursor |
| `<leader>ghu` | `undo_stage_hunk` | ⚠️ DEPRECATED - Use stage_hunk on staged signs |

## Workflow Example

```
Working Directory → Index (Staging) → Commit
        ↓               ↓
   Your changes    <leader>ghS (stage_buffer)
        ↓               ↓
<leader>ghR      <leader>ghU (reset_buffer_index)
(DESTRUCTIVE!)   (Safe - keeps changes)
```

## Use Cases

### Use Case 1: Accidental Stage
```
1. Stage entire buffer: <leader>ghS
2. Realize you staged wrong file
3. Unstage safely: <leader>ghU (keeps your edits)
```

### Use Case 2: Selective Commit
```
1. Edit multiple files
2. Stage all: <leader>ghS on each file
3. Review staged changes: git status
4. Unstage one file: <leader>ghU (to re-review later)
5. Commit remaining staged files
```

### Use Case 3: Reset vs Unstage
```
# Wrong approach (loses work):
<leader>ghR  # Discards all changes - DANGEROUS!

# Correct approach (keeps work):
<leader>ghU  # Unstages only - SAFE
```

## Success Criteria

- [x] Keymap added to lua/plugins/ui.lua
- [x] Documentation added to docs/memory/gitsigns.md
- [x] Comparison table shows differences clearly
- [x] Mnemonic pattern documented
- [x] Workflow examples provided

## Verification Checklist

**Test unstaging:**
- [ ] Edit a file and stage it: `<leader>ghS`
- [ ] Verify it's staged: `:!git status`
- [ ] Unstage the buffer: `<leader>ghU`
- [ ] Verify it's unstaged: `:!git status`
- [ ] Verify changes still exist in file (not discarded)

**Test destructive reset (ensure it still works):**
- [ ] Edit a file
- [ ] Reset the buffer: `<leader>ghR`
- [ ] Verify changes are discarded (reverted to HEAD)

**Test hunk operations:**
- [ ] Stage a hunk: `<leader>ghs`
- [ ] Verify only that hunk is staged
- [ ] Undo stage: `<leader>ghu`
- [ ] Verify hunk is unstaged

## Notes

### GitSigns v2.0.0 Context

This keymap addition was done during review of GitSigns v2.0.0 breaking changes. See [docs/memory/gitsigns.md](docs/memory/gitsigns.md) for:
- Breaking changes documentation
- Migration checklist
- statuscolumn support (new in v2.0)

### Deprecated Function Warning

`undo_stage_hunk()` is deprecated in GitSigns v2.0. Users should:
- Use `stage_hunk()` on already-staged signs instead
- Or use `reset_buffer_index()` for full buffer unstaging

---

**Completed**: 2026-01-25
**Verified**: Ready for user testing
