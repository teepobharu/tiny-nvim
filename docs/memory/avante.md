# Avante.nvim Memory Bank

## Recent Updates (2026-01-24)

### Critical New Features

#### 1. Claude Code Subscriptions (commit 2159c0c)
**What**: Enterprise-grade AI capabilities integration
**Why**: Better rate limits, performance, and features for Claude Code subscribers
**Config**: Automatic - no changes needed if using `provider = "copilot"`

#### 2. MCP Servers Support (commit 148998b)
**What**: Model Context Protocol servers in `acp_providers` config
**Pattern**:
```lua
opts = {
  acp_providers = {
    -- Add custom MCP servers here
  },
  acp_follow_agent_locations = false, -- Already set in myEditor.lua:805
}
```
**Use Case**: Extend avante with custom tools/services via MCP protocol

#### 3. Git Ignored Files Access (commit 5cad31d)
**Config Option**: `allow_access_to_git_ignored_files`
**Current Setting**: `false` (myEditor.lua:777) ✅ SECURE
**Why It Matters**: Prevents AI from accessing:
- `.env` files (secrets)
- `node_modules` (noise)
- Build artifacts
- Other gitignored sensitive files
**Recommendation**: Keep as `false` unless explicitly needed

#### 4. ACP Session Loading (commit 7608dce)
**What**: Resume previous coding agent sessions
**Benefit**: Persistent workflow without reinitializing context
**Status**: Available if using ACP providers (codex, claude_code)

#### 5. History Management (commits a9e9890, 483c570, 92f972a)
**New**: Delete history via multiple pickers:
- fzf-lua mapping
- snacks.nvim mapping
- telescope mapping
**Use**: Better session cleanup and management

---

## Current Configuration

**File**: lua/plugins/extra/myEditor.lua:746-832

```lua
opts = {
  provider = "copilot",  -- ✅ Works with new features

  -- Security ✅
  allow_access_to_git_ignored_files = false,

  -- ACP settings ✅
  acp_follow_agent_locations = false,

  -- UI/UX ✅
  selection = {
    enabled = true,
    hint_display = "none",
  },

  -- Web search ✅
  web_search_engine = {
    provider = "google",
  },

  -- Providers (merged with Agoda utils)
  providers = vim.tbl_extend("force", {
    copilot = { model = "gpt-5-mini" },
  }, {}),

  -- Keymaps
  mappings = {
    files = { add_current = "<leader>aC" },
    toggle = {
      debug = "<leader>rd",
      selection = "<localleader>ax",
    },
    focus = "<localleader>ax",
  },
}
```

**Separate Config**: lua/plugins/extra/avante.lua (older, simpler)
- Basic setup with `<leader>r` mappings
- render-markdown integration for Avante filetype

---

## Caveats & Patterns

### 1. Two Config Files
**Issue**: avante configured in TWO places:
- `lua/plugins/extra/myEditor.lua` (main, comprehensive)
- `lua/plugins/extra/avante.lua` (older, basic)

**Recommendation**: Consolidate or clearly document which is primary

### 2. Blink.cmp Integration
**Pattern** (myEditor.lua:1269-1301):
```lua
sources = {
  providers = {
    avante_commands = { score_offset = 1000 },  -- Highest
    avante_mentions = { score_offset = 900 },   -- High
    avante_files = { score_offset = 800 },      -- Medium-high
  },
  per_filetype = {
    AvanteInput = {
      inherit_defaults = true,
      "avante_commands", "avante_mentions", "avante_files"
    },
  },
}
```
**Why**: Proper completion in Avante input buffer

### 3. Provider Selection
**Keymaps** (myEditor.lua:1139-1150):
- `<leader>rs` - Pick Avante models
- `<leader>rS` - Pick custom Avante models

**Pattern**: Switch providers on-the-fly without config changes

### 4. Security Best Practice
**Always set**:
```lua
allow_access_to_git_ignored_files = false
```
**Unless**: Explicitly testing with ignored files in trusted projects

---

## Common Issues & Solutions

### Issue: Avante not showing completions in input
**Solution**: Check blink.cmp per_filetype config includes avante sources

### Issue: Provider not working
**Solution**:
1. Check `:checkhealth avante`
2. Verify API keys in environment
3. Test with different provider (copilot vs openai vs claude)

### Issue: History not deletable
**Solution**: Use new history delete mappings (check picker docs)

---

## Testing Checklist

After updates:
- [ ] `:checkhealth avante`
- [ ] Open Avante chat and test current provider
- [ ] Verify file attachment works
- [ ] Test selection mode with `<localleader>ax`
- [ ] Try history management features
- [ ] Validate git-ignored files are not accessible

---

## References

- **Main Config**: lua/plugins/extra/myEditor.lua:746-832
- **Alt Config**: lua/plugins/extra/avante.lua
- **Blink Integration**: lua/plugins/extra/myEditor.lua:1269-1301
- **Source**: ~/.local/share/nvim/lazy/avante.nvim
- **Docs**: https://github.com/yetone/avante.nvim
- **DeepWiki**: https://deepwiki.com/yetone/avante.nvim

---

**Last Updated**: 2026-01-24
**Plugin Version**: Latest (multiple recent commits)
**Status**: CONFIGURED ✅ SECURE ✅
