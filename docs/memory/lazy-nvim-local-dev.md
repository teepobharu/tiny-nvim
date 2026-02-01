# Lazy.nvim Local Development

**Source:** [DeepWiki - lazy.nvim dev/dir fields](https://deepwiki.com/search/what-does-dev-and-dir-field-is_dcd4b58d-b892-4dd9-b13c-88c7a1a0d367?mode=fast)

## Quick Reference

| Field | Purpose | Path | Changes Reflect? |
|-------|---------|------|-----------------|
| `dir` | Point to exact local directory | Absolute/relative path | ✅ Immediately |
| `dev = true` | Use dev directory | `{config.dev.path}/{plugin.name}` | ✅ Immediately |
| *(none)* | Edit installed plugin directly | `~/.local/share/nvim/lazy/<plugin>/` | ✅ Yes, **but updates overwrite** |

## Key Behaviors

### `dir` Field
- **Override everything**: Takes precedence over `[1]` and `url`
- **Absolute control**: Points to any local directory
- **Example**: `{ dir = "~/projects/secret.nvim" }`

### `dev` Field
- **Convenience shortcut**: Uses `config.dev.path` (default `~/projects`)
- **Auto-enable**: Matches patterns in `config.dev.patterns`
- **Resolution**: `{config.dev.path}/{plugin.name}`
- **Example**: `{ "folke/noice.nvim", dev = true }` → `~/projects/noice.nvim`
- **Fallback**: If `dev.fallback = false` (default) and dir doesn't exist, won't fall back to remote

### Direct Edits (No Config)
**You CAN edit installed plugins directly** in `~/.local/share/nvim/lazy/<plugin>/`:
- ✅ Changes reflect on next restart or `:Lazy reload <plugin>`
- ❌ `:Lazy update` **overwrites** your changes
- 💡 Run `:Lazy clear` if changes don't appear (cache issue)

## Workflow Recommendations

```lua
-- Development workflow
{
  "author/plugin.nvim",
  dev = true,  -- Use ~/projects/plugin.nvim
}

-- Temporary testing (will be overwritten by updates)
-- Edit directly: ~/.local/share/nvim3_jelly_tinynvim/lazy/plugin.nvim/

-- Permanent fork/modification
{
  "author/plugin.nvim",
  dir = "~/code/my-fork/plugin.nvim",  -- Safe from updates
}
```

## Caveats
- Some changes (commands, runtimepath) may need full restart even after `:Lazy reload`
- `dev` directory must exist unless `dev.fallback = true`
- Both `dev` and `dir` resolve to local paths - no remote fetch
