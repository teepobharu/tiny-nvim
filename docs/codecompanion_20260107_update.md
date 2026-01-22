# 1. Update to latest version v18.4.1

## TODO

alias not work AM
snacks provider broke ?

## TRIED

**Current version:** v18.4.1 (2026-01-16) ✅
**Previous version:** v17.33.0

Changes reference:

- CHANGELOG: /Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/CHANGELOG.md
- Slash commands: /Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/doc/usage/chat-buffer/slash-commands.md
- Prompt library: /Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/doc/configuration/prompt-library.md
- My config: lua/plugins/extra/myEditor.lua:159-694

---

## Breaking Changes from v17.33.0 → v18.0.0

### 🔴 Critical - Action Required

1. **Workflow strategy syntax changed**
   - Old: `strategy = "workflow"`
   - New: `opts.is_workflow = true`
   - Location: `myEditor.lua:648`
   - Status: ✅ **FIXED** (Applied 2026-01-19)

### ✅ Already Compatible

2. **`strategies` → `interactions`** - Has backward compatibility layer
   - Your config uses `strategies` (myEditor.lua:231-254)
   - Works but consider migrating eventually

3. **Slash commands: `catalog` → `builtin`**
   - Old: `strategies.chat.slash_commands.catalog.buffer`
   - New: `strategies.chat.slash_commands.builtin.buffer`
   - Status: ✅ **FIXED** (Applied 2026-01-19)
   - Your config: myEditor.lua:238, 246

### 📋 Other Changes (Not affecting your config)

4. **Tools API** - `requires_approval` → `require_approval_before`
5. **Adapters** - `condition` → `enabled`
6. **Chat** - `memory` → `rules`

---

## Specific Fixes Applied

### Fix 1: Workflow Syntax (myEditor.lua:648) ✅

**Before:**

```lua
["Setup Test Example"] = {
  strategy = "workflow",  -- ❌ Deprecated
  description = "My workflow",
  opts = {
    adapter = "copilot",
  },
  prompts = { ... }
}
```

**After:**

```lua
["Setup Test Example"] = {
  description = "My workflow",
  opts = {
    is_workflow = true,  -- ✅ v18+ syntax
    adapter = "copilot",
  },
  prompts = { ... }
}
```

### Fix 2: Slash Command Callbacks (myEditor.lua:238, 246) ✅

**Before:**

```lua
["buffer"] = {
  callback = "strategies.chat.slash_commands.catalog.buffer",  -- ❌ Deprecated
  opts = { provider = "snacks" },
},
["file"] = {
  callback = "strategies.chat.slash_commands.catalog.file",  -- ❌ Deprecated
  opts = { provider = "snacks" },
},
```

**After:**

```lua
["buffer"] = {
  callback = "strategies.chat.slash_commands.builtin.buffer",  -- ✅ v18+ syntax
  opts = { provider = "snacks" },
},
["file"] = {
  callback = "strategies.chat.slash_commands.builtin.file",  -- ✅ v18+ syntax
  opts = { provider = "snacks" },
},
```

---

## New Features Worth Exploring

### v18.4.0 (Jan 2026)

- ACP model selection improvements
- Better Copilot model capabilities detection

### v18.3.0 (Dec 2025)

- System prompts can include filepath
- Enhanced tool approvals UX
- Updated Anthropic models

### v18.2.0 (Dec 2025)

- Gemini 3 Flash model support
- Toggle chat with adapter param: `:CodeCompanionChat Toggle adapter=copilot`

### v18.1.0 (Dec 2025)

- Copilot `max_context_window_tokens` parameter
- Mistral reasoning capabilities

---

## Suggestions Summary

### ✅ Completed Fixes (2026-01-19)

1. **Workflow syntax** - myEditor.lua:648
   - Changed `strategy = "workflow"` to `opts.is_workflow = true`

2. **Slash command callbacks** - myEditor.lua:238, 246
   - Changed `catalog` to `builtin` in callback paths

### Optional Improvements

1. 🔄 **Migrate to `interactions`** (optional - backward compat exists)
   - Replace `strategies` with `interactions` in config
   - See myEditor.lua:233-256

2. 🔧 **Fix Agoda adapter auth issue** (commented out at myEditor.lua:203-229)
   - Error: Domain mismatch `.api.openai.com`
   - Related: See lua/utils/my_codecompanion_utils.lua for proper adapter setup

3. 📚 **Explore new features**
   - Test filepath in system prompts
   - Try model selection improvements
   - Consider using adapter params in toggle commands

### Reference Links

- [myEditor.lua](lua/plugins/extra/myEditor.lua:159-694)
- [my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua)
- [CHANGELOG](file:///Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/CHANGELOG.md)

---

# 2. Support custom models similar to Avante

**Status:** ✅ Utilities created - Ready to use

## Implementation

### Created Files

- ✅ [lua/utils/my_ai_constants.lua](lua/utils/my_ai_constants.lua) - Shared constants for all AI tools (models, endpoints, filters)
- ✅ [lua/utils/my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua) - Agoda adapter configurations
- ✅ [lua/utils/my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua) - Inline chat actions with provider/model selection + `fetch_model_helper` from POC

### Pattern & Deduplication

**Shared Constants** ([my_ai_constants.lua](lua/utils/my_ai_constants.lua)):

- Single source of truth for model names, endpoints, and filters
- Eliminates duplication across Avante and CodeCompanion
- Easy to maintain and update models globally
- Includes `fetch_model_helper` function from POC for dynamic model fetching

**Benefits:**

- ✅ Model names defined once, used everywhere
- ✅ AGD endpoints centralized
- ✅ Blacklist/keyword filters shared
- ✅ Type-safe through Lua constants
- ✅ Future AI tools can reuse the same constants

Similar to [lua/utils/my_avante_utils.lua](lua/utils/my_avante_utils.lua:9-67):

- Centralized Agoda-specific adapter configs
- Helper functions for adapter/model management
- Consistent API across AI tools (Avante + CodeCompanion)

### Key Features

#### 1. Adapter Configurations ([my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua))

- Define custom adapters (Agoda endpoints)
- Merge with base adapters
- Helper functions for adapter management

#### 2. Inline Chat Actions ([my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua))

- Trigger inline chat with specific adapter/model
- Generate keymaps for quick model selection
- Support both visual (inline) and normal (switch) modes
- Consistent with Avante keymap pattern
- **NEW:** `fetch_model_helper()` for dynamic model fetching with blacklist/keyword filtering

#### 3. Shared AI Constants ([my_ai_constants.lua](lua/utils/my_ai_constants.lua))

- Model names: `AI.models.gpt.*`, `AI.models.claude.*`, `AI.models.gemini.*`
- Endpoints: `AI.endpoints.agoda.*`
- Filters: `AI.filters.blacklist`, `AI.filters.keywords`
- Defaults: `AI.defaults.adapter`, `AI.defaults.model`
- Helper functions: `AI.filter_models()`, `AI.get_*_models()`

### Usage Example

#### Using Shared Constants

```lua
local AI = require("utils.my_ai_constants")
local cc_actions = require("utils.my_codecompanion_actions")

-- Use constants instead of hardcoded strings
vim.keymap.set("v", "<leader>ASf", function()
  cc_actions.inline_with_adapter(AI.defaults.adapter, AI.models.gpt.GPT_5_MINI)
end, { desc = "CC Inline: GPT-5-mini" })

vim.keymap.set("n", "<leader>ASh", function()
  cc_actions.switch_adapter(AI.defaults.adapter, AI.models.claude.CLAUDE_SONNET_4_5)
end, { desc = "CC Switch: Claude Sonnet 4.5" })

-- Use fetch_model_helper in custom adapter
require("codecompanion").setup({
  adapters = {
    http = {
      openai_agd = function()
        return require("codecompanion.adapters").extend("openai", {
          env = { api_key = AI.env_keys.OPENAI_API_KEY },
          url = AI.endpoints.agoda.OPENAI_PROXY,
          schema = {
            model = {
              default = function(self, opts)
                return cc_actions.fetch_model_helper(self, opts)[1] or AI.models.gpt.GPT_5_2
              end,
              choices = function(self, opts)
                return cc_actions.fetch_model_helper(self, opts)
              end,
            },
          },
        })
      end,
    },
  },
})
```

#### Generate All Keymaps (Recommended)

```lua
-- In your keymaps configuration (e.g., editor_keymaps.lua)
local cc_actions = require("utils.my_codecompanion_actions")

-- Generate all CodeCompanion keymaps with <leader>AS prefix
local codecompanion_keymaps = cc_actions.generate_codecompanion_keymaps()

-- Extend with your existing keymaps
vim.list_extend(your_keymaps, codecompanion_keymaps)
```

#### Keymap Structure

**Copilot models** (`<leader>AS` prefix):

- `<leader>ASf` - GPT-4.1-mini (fast)
- `<leader>ASF` - GPT-5-mini (fast-2)
- `<leader>ASh` - Claude Sonnet 4.5 (heavy)
- `<leader>ASH` - Claude Opus 4.5
- `<leader>ASc` - GPT-5.1-codex-max
- `<leader>ASC` - GPT-5.1-codex-mini

**AGD models** (`<leader>ASS` prefix):

- `<leader>ASSf` - GPT-4.1-mini (AGD)
- `<leader>ASSF` - GPT-5-mini (AGD)
- `<leader>ASSc` - GPT-5.2 (AGD)
- `<leader>ASSh` - Claude 3.7 Sonnet (AGD)
- `<leader>ASSH` - Claude Opus 4.5 (AGD)

**Utilities**:

- `<leader>ASi` - Show current adapter/model

**Mode behavior**:

- **Visual mode** (`v`, `x`): Trigger inline chat with selected text
- **Normal mode** (`n`): Switch default adapter/model

### API Verification & Fixes (20260121)

**Status:** ✅ Fixed - Verified correct CodeCompanion API usage

**Issues Found:**

- ❌ `require("codecompanion").config` returns nil - should use `require("codecompanion.config")`
- ❌ Calling `setup()` multiple times doesn't work for temporary adapter override
- ❌ `CodeCompanionChat Add` command doesn't work for inline chat

**Correct API Pattern (Verified from source):**

1. **Config Access:**

```lua
local config = require("codecompanion.config")
-- Access: config.interactions.chat.adapter, config.adapters.http[adapter_name]
```

2. **Inline Chat with Specific Adapter:**

```lua
-- Create inline instance directly with adapter
local context = require("codecompanion.utils.context").get(bufnr, {})
local adapter = require("codecompanion.adapters").resolve(adapter_config)
adapter.schema.model.default = model  -- Override model

local inline = require("codecompanion.interactions.inline").new({
  adapter = adapter,
  buffer_context = context,
})
inline:prompt(user_input)
```

3. **Chat with Specific Adapter:**

```lua
-- Use params to pass adapter/model (v18+ feature)
require("codecompanion").chat({
  params = { adapter = adapter_name, model = model },
  subcommand = "toggle",
})
```

4. **Switch Default Adapter:**

```lua
-- Directly modify config table
local config = require("codecompanion.config")
config.interactions.chat.adapter = adapter_name
config.interactions.inline.adapter = adapter_name
```

**Updated Implementation:** lua/utils/my_codecompanion_actions.lua:130-234

### Prompt Library Fixes (20260121)

**Status:** ✅ Fixed - Updated all prompts to v18+ syntax

**Issues Fixed:**

1. ✅ `strategy` → `interaction` (7 prompts affected)
2. ✅ `short_name` → `alias` (7 prompts affected)
3. ✅ `opts.adapter` simplified from table to string (7 prompts affected)

**Fixed Prompts:**

- myEditor.lua:296 - "Model GPT mini 5 - G5"
- myEditor.lua:311 - "Codecompanion Context"
- myEditor.lua:355 - "Snacks Nvim Context"
- myEditor.lua:404 - "FZF Context"
- myEditor.lua:454 - "📂 Attach File:Line Refs (t)"
- myEditor.lua:553 - "Generate a Commit Message for Staged Short"
- myEditor.lua:586 - "Review a Staged Commit Message"

**Reference:** Based on official documentation at https://deepwiki.com/olimorris/codecompanion.nvim/9.4-prompt-library

### Next Steps

1. ✅ Create utility modules (COMPLETED)
2. ✅ Verify and fix CodeCompanion API usage (COMPLETED)
3. ✅ Fix prompt_library syntax (COMPLETED)
4. Integrate keymaps into `lua/utils/editor_keymaps.lua`
5. Optional: Create `lua/plugins/extra/myCodecompanion.lua` for adapter overrides
6. Test Agoda adapter authentication

For full implementation details, see:

- [docs/codecompanion_20260107_update_modelsupport.md](docs/codecompanion_20260107_update_modelsupport.md)

---

# 3. Custom Inline Chat - DIGDEEP with Model Selection

**Status:** ✅ Implemented

## Overview

Created inline chat functionality for CodeCompanion with provider/model selection, matching Avante's pattern.

**Requirements (from original):**

- ✅ Bind key to quick inline chat
- ✅ Support inline edit with preselected models:
  - gpt-5-mini (`<leader>ASF`)
  - gpt-4.1-mini (`<leader>ASf`)
  - claude-sonnet-4.5 (`<leader>ASh`)

## Comparison: Avante vs CodeCompanion

| Feature          | Avante (`<leader>rs*`)                  | CodeCompanion (`<leader>AS*`)         |
| ---------------- | --------------------------------------- | ------------------------------------- |
| **Visual mode**  | `edit_with_provider()` - Edit selection | `inline_with_adapter()` - Inline chat |
| **Normal mode**  | `switch_provider()` - Switch config     | `switch_adapter()` - Switch config    |
| **Fast models**  | `<leader>rsf/F`                         | `<leader>ASf/F`                       |
| **Heavy models** | `<leader>rsh/H`                         | `<leader>ASh/H`                       |
| **Codex models** | `<leader>rsc/C`                         | `<leader>ASc/C`                       |
| **AGD models**   | `<leader>rS*`                           | `<leader>ASS*`                        |
| **Info**         | N/A                                     | `<leader>ASi`                         |

## Files Created

- ✅ [lua/utils/my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua) - Main action functions
- ✅ Documentation in section #2 above

## Integration

To enable these keymaps, add to `lua/utils/editor_keymaps.lua`:

```lua
local cc_actions = require("utils.my_codecompanion_actions")
local codecompanion_keymaps = cc_actions.generate_codecompanion_keymaps()
vim.list_extend(editor_keymaps, codecompanion_keymaps)
```

## Quick Actions Available

```lua
local cc_actions = require("utils.my_codecompanion_actions")

-- Quick actions
cc_actions.actions.inline_current()  -- Inline with current selection
cc_actions.actions.chat_toggle()     -- Toggle chat window
cc_actions.actions.inline_fast()     -- Quick inline with GPT-5-mini
cc_actions.actions.inline_heavy()    -- Quick inline with Claude Sonnet 4.5
```

## TO CHECK

possible to attach only ?

- seems like not
- what about chaning model

```sh
require("codecompanion").setup({
  prompt_library = {
    ["Model GPT mini 5 - G5"] = {
      interaction = "chat",
      opts = {
        adapter = "copilot",
        is_slash_cmd = true,
        alias = "gpt5mini_g5m_gfree",
        stop_context_insertion = true,
      },
      prompts = {
        {
          role = "user",
          content = ""
        }
      },
    },
    ["Codecompanion Context"] = {
      interaction = "chat",
      description = "Write documentation for me",
      opts = {
        index = 11,
        adapter = "copilot",
        is_slash_cmd = true,
        auto_submit = false,
        alias = "codecompanion_nvim_context",
        stop_context_insertion = true,
      },
      context = {
        {
          type = "file",
          path = {
            vim.fn.expand("$HOME/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myEditor.lua")
          },
        },
        {
          type = "url",
          url = "https://codecompanion.olimorris.dev/configuration/prompt-library",
        },
      },
      prompts = {
        {
          role = "user",
          content = function()
            vim.g.codecompanion_auto_tool_mode = true
            return [[### Instructions
Your instructions here

### Steps to Follow

You are required to write code with correct usage of the lua settings provided by the documentation
1. Update the code in #buffer{watch} using the @editor tool
2. Make sure you trigger both tools in the same response Specification
3. Follow the given documentation
]]
          end,
        },
      },
    },
    ["Snacks Nvim Context"] = {
      interaction = "chat",
      description = "Write documentation for me",
      opts = {
        index = 11,
        adapter = "copilot",
        is_slash_cmd = true,
        auto_submit = false,
        alias = "snacks_nvim_context",
        stop_context_insertion = true,
      },
      context = {
        {
          type = "file",
          path = {
            vim.fn.expand("$HOME/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myEditor.lua")
          },
        },
        {
          type = "url",
          url = "https://github.com/folke/snacks.nvim/blob/main/docs/picker.md",
        },
        {
          type = "url",
          url = "https://www.reddit.com/r/neovim/comments/1j4e7fq/share_your_custom_snackspicker_sources",
        },
      },
      prompts = {
        {
          role = "user",
          content = function()
            vim.g.codecompanion_auto_tool_mode = true
            return [[### Instructions
Your instructions here

### Steps to Follow

You are required to write code with correct usage of nvim lazy libraries and preferably in lua then fallback to vim if necessary
1. Update the code in #buffer{watch} using the @editor tool
2. Make sure you trigger both tools in the same response Specification
3. Follow the given documentation
]]
          end,
        },
      },
    },
    ["FZF Context"] = {
      interaction = "chat",
      description = "Write documentation for me",
      opts = {
        index = 11,
        adapter = "copilot",
        is_slash_cmd = true,
        auto_submit = false,
        alias = "fzf_context",
        stop_context_insertion = true,
      },
      context = {
        {
          type = "url",
          url = "https://github.com/junegunn/fzf/blob/master/man/man1/fzf.1",
        },
        {
          type = "url",
          url = "https://junegunn.github.io/fzf/releases/0.66.0",
        },
      },
      prompts = {
        {
          role = "user",
          content = function()
            vim.g.codecompanion_auto_tool_mode = true
            return [[### Instructions
Your instructions here

### Steps to Follow

You are required to write code with correct usage of nvim lazy libraries and preferably in lua then fallback to vim if necessary
1. Update the code in #buffer{watch} using the @editor tool
2. Make sure you trigger both tools in the same response Specification
3. Follow the given documentation
]]
          end,
        },
      },
    },
    ["Attach File:Line Refs"] = {
      interaction = "chat",
      opts = {
        is_slash_cmd = false,
        auto_submit = false,
        stop_context_insertion = true,
      },
      description = "Attach references to the chat",
      prompts = {
        {
          role = "user",
          content = function(context)
            context = context or {}
            local bufnr = context.bufnr or vim.api.nvim_get_current_buf()
            local start_line = context.start_line or context.start or (context.range and context.range.start_line)
            local start_col = context.start_col or context.start_col
            local end_line = context.end_line or context.finish or (context.range and context.range.end_line)
            local end_col = context.end_col or context.end_col

            if not start_line then
              local row, col = unpack(vim.api.nvim_win_get_cursor(0))
              start_line = row
              start_col = col
              end_line = row
              end_col = col
            end

            local bufname = context.filepath or vim.api.nvim_buf_get_name(bufnr)
            local relpath = vim.fn.fnamemodify(bufname == "" and vim.api.nvim_buf_get_name(0) or bufname, ":.")

            start_col = start_col or 1
            end_col = end_col or 999

            local attachref
            if start_line and end_line and (start_line ~= end_line or start_col ~= end_col) then
              attachref = string.format("> - file: @%s :L%d:C%d-L%d:C%d", relpath, start_line, start_col, end_line, end_col)
            else
              attachref = string.format("> - file: @%s :L%d:C%d", relpath, start_line, start_col)
            end

            return attachref .. "\n"
          end,
        },
      },
    },
  }
})
```

**Related Resources:**

- https://deepwiki.com/search/how-to-bind-key-to-do-inline-c_1b187fa6-d9be-448a-be94-c77c3e2de23f?mode=fast
