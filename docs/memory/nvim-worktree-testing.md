# Neovim Worktree Testing — Isolated Profile Model

## How It Works

Neovim's `NVIM_APPNAME` env var controls which config, data, state, and cache directories are used. By setting it to the **worktree directory name**, you get a fully isolated Neovim profile that shares no runtime state with the main daily-driver profile.

This repo uses **git worktrees** so the same codebase can have multiple branches checked out simultaneously. Combined with `NVIM_APPNAME`, each worktree directory becomes an independent Neovim environment.

## Profile Layout

| Profile | NVIM_APPNAME | Git Branch | Purpose |
|---------|-------------|------------|---------|
| **Main** | `nvim3_jelly_tinynvim` | `main` | Daily driver — stable, production config |
| **Worktree** | `nvimwt3a` | `nvim3wt1` | Testing, POCs, plugin upgrades, patches |

## Path Mapping

Each `NVIM_APPNAME` resolves to its own set of XDG directories:

| XDG path | Main (`nvim3_jelly_tinynvim`) | Worktree (`nvimwt3a`) |
|----------|-------------------------------|----------------------|
| `stdpath("config")` | `~/.config/nvim3_jelly_tinynvim/` | `~/.config/nvimwt3a/` |
| `stdpath("data")` | `~/.local/share/nvim3_jelly_tinynvim/` | `~/.local/share/nvimwt3a/` |
| `stdpath("state")` | `~/.local/state/nvim3_jelly_tinynvim/` | `~/.local/state/nvimwt3a/` |
| `stdpath("cache")` | `~/.cache/nvim3_jelly_tinynvim/` | `~/.cache/nvimwt3a/` |
| Lazy plugins | `~/.local/share/nvim3_jelly_tinynvim/lazy/` | `~/.local/share/nvimwt3a/lazy/` |

**Key insight**: Lazy.nvim installs plugins into `stdpath("data")/lazy/`, so each profile has its own independent set of installed plugins with their own versions and lock files.

## Workflow

### 1. Make changes in the worktree

Edit files in `~/.config/nvimwt3a/` (the worktree on branch `nvim3wt1`). This is the same git repo as the main config — just a different branch checkout.

### 2. Test with the worktree profile

```bash
NVIM_APPNAME=nvimwt3a nvim
```

This starts Neovim using:
- Config from `~/.config/nvimwt3a/` (the worktree code)
- Plugin data from `~/.local/share/nvimwt3a/lazy/` (separate from main)

### 3. First-time setup for worktree profile

The first time you run with a new `NVIM_APPNAME`, Lazy.nvim will install plugins fresh:

```bash
# Interactive
NVIM_APPNAME=nvimwt3a nvim
# Then :Lazy install or :Lazy sync

# Or headless
NVIM_APPNAME=nvimwt3a nvim --headless -c "Lazy install" -c "qa"
```

### 4. Merge to main when verified

Once changes are tested and stable on the worktree branch, merge to `main`:

```bash
git checkout main
git merge nvim3wt1
```

The main profile (`NVIM_APPNAME=nvim3_jelly_tinynvim`) will pick up the changes on next `:Lazy sync`.

## Gotchas

### Don't put worktree-specific files in the main profile directory

Files that depend on `stdpath("config")` (like `patches/` for `lazy-local-patcher.nvim`) must live in the correct config directory. If you're testing in the worktree profile, the file must be at `~/.config/nvimwt3a/patches/`, NOT at `~/.config/nvim3_jelly_tinynvim/patches/`.

### Plugin versions can diverge

Each profile has its own `lazy-lock.json` and plugin installations. The worktree profile can have `codecompanion.nvim` at v19 while the main profile stays at v18. This is intentional — it's the whole point of isolated testing.

### DIGDEEP: Plugin source code location

When investigating plugin source code, use the correct data path for the profile you're working with:

```
~/.local/share/$NVIM_APPNAME/lazy/<plugin-name>/
```

- Main: `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/`
- Worktree: `~/.local/share/nvimwt3a/lazy/codecompanion.nvim/`

### Git worktree management

```bash
# List worktrees
git worktree list

# The worktree .git file is a pointer, not a directory:
cat ~/.config/nvimwt3a/.git
# gitdir: /path/to/.git/modules/.config/nvim3_jelly_tinynvim/worktrees/nvim3wt1
```

---

**Last Updated**: 2026-03-16
