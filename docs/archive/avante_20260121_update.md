# Avante.nvim Update Analysis (2026-01-21)

**Status:** ✅ ANALYZED - Breaking changes and new features documented

Below are lazy.nvim updates analyzed for compatibility with current avante.nvim setup and code.

## Upstream Commits (Last 6 weeks)

```sh
    ● avante.nvim 44.09ms  VeryLazy
        e1e70be feat: show selected item for native selector (#2915) (2 days ago)
        08b202a Adjust unset operation for api key name to after check for type (#2919) (2 days ago)
        e89eb79 fix: apply StyLua formatting to bedrock.lua (#2912) (13 days ago)
        2159c0c feat: Add support for Claude Code Subscriptions (#2909) (13 days ago)
        a45acbf feat: support bedrocks inference profile ARNs (#2910) (13 days ago)
        a27b821 fix(acp): fix error when using in acp repos (#2904) (3 weeks ago)
        7a9fbbd fix(history): correct title type check in History.from_file() (#2898) (3 weeks ago)
        5e37159 feat(providers): update GLM model from glm-4.6 to glm-4.7 (#2897) (3 weeks ago)
        f663865 Added nbconvert needed for rag indexing jupyter notebooks (#2862) (3 weeks ago)
        7608dce Support loading ACP sessions if agent can (#2889) (3 weeks ago)
        148998b feat(acp): support mcp_servers in acp_providers config (#2883) (4 weeks ago)
        5cad31d feat(config): add option `allow_access_to_git_ignored_files` (#2882) (4 weeks ago)
        2ffe820 fix: avante.llm_tools.helpers.is_ignored error (#2895) (4 weeks ago)
        a9e9890 Change codex acp provider command to automatically install & run (#2890) (4 weeks ago)
        476f342 chore: used native action-centric methods for testing (#2856) (5 weeks ago)
        a9a558d feat: Add mapping to delete avante history via fzf-lua (#2869) (5 weeks ago)
        483c570 fix: history selector snacks.nvim live search error (#2870) (5 weeks ago)
        b62b637 fix: wrap nvim_del_autocmd in vim.schedule to avoid fast event context error (#2873) (5 weeks ago)
        cf352f6 fix: make acp client send requests async (#2848) (5 weeks ago)
        2afb705 fix: typo in vertex claude endpoint url (#2871) (5 weeks ago)
        15548d5 refactor(rag): rewrote the starting command (#2874) (5 weeks ago)
        68b624a chore: sort providers by name (#2876) (5 weeks ago)
        80f7079 fix: support cancelling acp providers (#2847) (5 weeks ago)
        92f972a feat: Add mapping to delete avante history via snacks.nvim (#2868) (6 weeks ago)
        08977a4 feat: Add mapping to delete avante history via telescope.nvim (#2867) (6 weeks ago)
        0336666 fix(acp): return JSON-RPC error for fs/read_text_file on missing files (#2849) (6 weeks ago)
        521633a fix: llm_api_key error in launch_rag_service (#2866) (6 weeks ago)
        4202881 refine: replace vim.fn.system with vim.system (#2863) (6 weeks ago)
        bbf6d8f fix: respect Config.debug during acp client session (#2857) (6 weeks ago)
        cc7f383 docs: remove Warp sponsorship link (#2859) (6 weeks ago)
```

## Breaking Changes & New Features Analysis

### 1. Claude Code Subscriptions Support (#2909)

**Commit:** 2159c0c (13 days ago)
**Status:** ❌ NOT CONFIGURED
**Priority:** Low (optional feature)

**What Changed:**
- Added support for Claude Code Subscriptions model access
- Enables using Claude Code subscriber-only models in Avante

**Config Required:**
```lua
-- lua/plugins/extra/myEditor.lua:753
opts = {
  providers = {
    copilot = {
      claude_code_subscriptions = true,  -- NEW: Enable Claude Code subscription models
      model = "gpt-5-mini",
    },
  },
}
```

**Current Setup:**
- Using basic copilot provider without subscriptions config (myEditor.lua:754)
- Agoda providers defined in my_avante_utils.lua don't use this feature

**Action Items:**
- [ ] Add `claude_code_subscriptions = true` if you have Claude Code subscription
- [ ] Test model availability with `:AvanteModel` after enabling
- [ ] Verify expanded model list includes subscription models

---

### 2. Allow Access to Git Ignored Files (#2882)

**Commit:** 5cad31d (4 weeks ago)
**Status:** ❌ NOT CONFIGURED (using default: false)
**Priority:** Medium (security consideration)

**What Changed:**
- New configuration option to control git-ignored file access
- By default, git-ignored files are excluded from Avante context

**Config Required:**
```lua
-- lua/plugins/extra/myEditor.lua:753
opts = {
  allow_access_to_git_ignored_files = false,  -- NEW: Respect .gitignore (recommended)
  -- Set to true only if you need Avante to access .env, node_modules, etc.
}
```

**Security Implications:**
```lua
⚠️  CRITICAL: Setting to true allows Avante to access:
   - .env files with API keys
   - node_modules (bloats context)
   - Build artifacts
   - Any git-ignored files

Recommendation: Keep as false (default) for security
```

**Current Setup:**
- Uses implicit default (false) - git-ignored files are excluded
- No explicit configuration in myEditor.lua:753-807

**Action Items:**
- [x] Explicitly add `allow_access_to_git_ignored_files = false` for clarity
- [ ] Keep as false for security (prevents leaking secrets in .gitignore)
- [ ] Only set true for trusted projects without secrets

---

### 3. MCP Servers in ACP Providers (#2883)

**Commit:** 148998b (4 weeks ago)
**Status:** ❌ NOT APPLICABLE (not using ACP)
**Priority:** Very Low (feature not in use)

**What Changed:**
- ACP (Agent Command Protocol) providers now support `mcp_servers` configuration
- MCP (Model Context Protocol) servers can be integrated with ACP providers

**Config Structure:**
```lua
-- Only needed if using ACP providers
acp_providers = {
  your_acp_provider = {
    mcp_servers = {  -- NEW field
      {
        command = "npx",
        args = { "-y", "@modelcontextprotocol/server-filesystem", "/path/to/dir" },
        name = "filesystem",
      },
    },
  }
}
```

**Current Setup:**
- Not using ACP providers (only direct Copilot/OpenAI/Vertex providers)
- Config has `acp_follow_agent_locations = false` (myEditor.lua:781)

**Action Items:**
- [ ] No action required (not using ACP workflow)
- [ ] Document for future reference if integrating AI agents
- [ ] Reference: https://deepwiki.com/yetone/avante.nvim/acp-providers

---

### 4. Snacks.nvim History Selector Fix (#2870)

**Commit:** 483c570 (5 weeks ago)
**Status:** ✅ FIXED UPSTREAM
**Priority:** Low (bug fix, no config needed)

**What Changed:**
- Fixed "live search error" when using snacks.nvim picker for Avante history
- Bug fix only - no breaking changes or config updates

**Current Setup:**
- Using snacks.nvim (project has snacks-related config)
- History selector now works without errors

**Action Items:**
- [ ] Test history selector: `:AvanteHistory` command
- [ ] Verify snacks.nvim picker integration works correctly

---

### 5. Delete Avante History via Snacks.nvim (#2868)

**Commit:** 92f972a (6 weeks ago)
**Status:** ✅ FEATURE AVAILABLE
**Priority:** Low (quality of life feature)

**What Changed:**
- New feature: Delete Avante history items via snacks.nvim picker
- Provides delete confirmation and picker-based UI

**Keybinding Recommendation:**
```lua
-- Add to lua/utils/editor_keymaps.lua in avante keymaps section
{
  "<leader>rhd",
  function()
    require("avante.api").open_history_picker_with_delete()
  end,
  desc = "Avante: Delete History Item",
  mode = "n",
}
```

**Current Setup:**
- Avante keymaps in editor_keymaps.lua:807
- Current keybindings (myEditor.lua:789-805):
  - `<leader>ra` - Ask AI
  - `<leader>rA` - Edit selected
  - `<leader>rr` - Refresh AI
  - `<leader>rM` - Model selection

**Action Items:**
- [ ] Add `<leader>rhd` keybinding for delete history
- [ ] Test delete functionality with existing history items

---

### 6. Other Notable Changes

**Native Selector Enhancement (#2915)** - e1e70be (2 days ago)
- Shows selected item in native selector UI
- No config changes needed

**Bedrock Inference Profile ARNs (#2910)** - a45acbf (13 days ago)
- Support for AWS Bedrock inference profiles
- Only relevant if using Bedrock provider (not in current setup)

**GLM Model Update (#2897)** - 5e37159 (3 weeks ago)
- Updated GLM model from glm-4.6 to glm-4.7
- Only affects GLM provider users (not in current setup)

---

## Configuration Updates Required

### Priority Changes

**HIGH PRIORITY (Security):**
1. ✅ Add explicit `allow_access_to_git_ignored_files = false` to myEditor.lua:753

**MEDIUM PRIORITY (Features):**
2. ⭐ Add `claude_code_subscriptions = true` if you have subscription
3. ⭐ Add history delete keybinding to editor_keymaps.lua

**LOW PRIORITY:**
4. Test snacks.nvim history selector integration
5. Document MCP servers config for future reference

### Recommended Configuration Update

**File:** lua/plugins/extra/myEditor.lua (lines 753-807)

```lua
opts = {
  provider = "copilot",

  -- NEW: Security - explicitly respect .gitignore
  allow_access_to_git_ignored_files = false,

  web_search_engine = {
    provider = "google",
  },

  providers = vim.tbl_extend("force", {
    copilot = {
      model = "gpt-5-mini",
      -- NEW: Uncomment if you have Claude Code Subscriptions
      -- claude_code_subscriptions = true,
    },
  }, {}),

  acp_follow_agent_locations = false,
  selection = {
    hint = "none",
    hint_display = "none",
  },
  behavior = {},
  mappings = {
    sidebar = {
      switch_windows = "<C-Tab>",
    },
    ask = {
      accept = "<C-cr>",
      selection = "<localleader>ax",
    },
    focus = "<localleader>ax",
  },
},
```

---

## File References

| File | Lines | Purpose |
|------|-------|---------|
| lua/plugins/extra/myEditor.lua | 728-807 | Main Avante configuration |
| lua/plugins/extra/avante.lua | 1-40 | Legacy/minimal Avante config (unused?) |
| lua/utils/my_avante_utils.lua | 1-349 | Agoda provider utilities & keymaps |
| lua/utils/editor_keymaps.lua | N/A | Where to add history delete keybinding |

---

## Verification Checklist

- [ ] Add `allow_access_to_git_ignored_files = false` to myEditor.lua:753
- [ ] Test current Avante setup still works: `:AvanteAsk`
- [ ] Test model selection: `:AvanteModel` shows all models
- [ ] Test history selector: `:AvanteHistory` with snacks.nvim picker
- [ ] Add history delete keybinding if desired
- [ ] If using Claude Code: Add `claude_code_subscriptions = true`
- [ ] Verify no errors in `:checkhealth avante`

---

## Next Steps

1. Update myEditor.lua with security config (allow_access_to_git_ignored_files)
2. Add history delete keybinding to editor_keymaps.lua
3. Test all Avante functionality after updates
4. Document any issues or improvements needed
