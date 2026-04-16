# CodeCompanion Native Prompt Library Research

## Overview

CodeCompanion **has NATIVE support** for loading prompts from markdown files on disk. The prompt library system is deeply integrated into the plugin and supports full configuration of tools, agents, MCP servers, and rules per prompt.

## 1. Native Markdown Support

### Enabled Via Config

```lua
-- In codecompanion config
prompt_library = {
  markdown = {
    dirs = {
      -- Absolute paths or functions returning paths
      vim.fn.expand("~/.config/nvim/prompts"),
      function(context) return vim.fn.expand("~/dotfiles/prompts") end,
    },
  },
}
```

### How It Works (Initialization Flow)

1. **Plugin startup** → `lua/codecompanion/actions/init.lua:set_items()`
2. **Scans directories** → `markdown.load_from_dir(dir, context)` (line 86-91 in `actions/init.lua`)
3. **Loads all `.md` files** → `file_utils.scan_directory(dir, { patterns = "*.md", max_depth = 5 })`
4. **Parses each file** → `markdown.parse_file(path, context)` with YAML frontmatter extraction
5. **Registers in action palette** → Inserted into cached actions with `is_markdown = true` flag
6. **User selects prompt** → `Actions.resolve(item, context)` → `Interactions:start(interaction_type)`
7. **Creates chat/inline/workflow** → Tools, servers, and rules are attached to the chat buffer

**Source**: `lua/codecompanion/actions/init.lua:85-92`, `markdown.lua:18-41`

---

## 2. Full Prompt Entry Schema

Based on source code analysis and tests, here is the COMPLETE schema for a prompt_library entry (both Lua and markdown):

### Markdown Format (Top-level Fields in YAML Frontmatter)

```yaml
---
# REQUIRED fields
name: String
interaction: chat|inline|workflow|cli  # formerly "strategy"

# OPTIONAL fields
description: String
adapter:
  name: String
  model: String  # Optional model override

# Tools / Agents
tools:
  - tool_name_1
  - tool_name_2
  # Special groups:
  # - agent
  # - mcp (MCPHub)
  # - <server_name> (specific MCP server)
  # - <server>__<tool> (specific tool)

mcp_servers:
  - server_name_1
  - server_name_2

rules:
  - rule_group_1
  - rule_group_2
  # Special: "none" to disable

# Context attachment
context:
  - type: file
    path:
      - lua/path/file1.lua
      - lua/path/file2.lua
    # OR
    path: lua/path/file.lua  # Single file as string
  - type: url
    url: https://example.com
    # OR (for multiple)
    url:
      - https://example1.com
      - https://example2.com

# Options
opts:
  alias: String               # Slash command name: /<alias>
  auto_submit: Boolean        # Auto-submit on selection
  is_slash_cmd: Boolean       # Register as /slash command
  user_prompt: Boolean        # Show user input dialog
  stop_context_insertion: Boolean
  modes:                      # Visual selection modes
    - v
    - n
  adapter:                    # Can also be here (overrides top-level)
    name: String
    model: String
  is_workflow: Boolean        # For workflow interaction
  enabled: Boolean            # Show in action palette?
  callbacks:                  # Chat buffer callbacks
    on_created: Function
    on_before_submit: Function
    on_submitted: Function
    # ... etc
  pre_hook: Function          # Execute before chat creation
  index: Number               # Sort order in palette (if set)
  slash_cmd: Boolean          # Legacy (v18)
  # ... other custom opts
---
```

### Lua Format (Equivalent)

In `lua/plugins/extra/codecompanion.lua` or similar:

```lua
["Prompt Name"] = {
  name = "Prompt Name",
  interaction = "chat",  -- or "inline", "workflow", "cli"
  description = "Description shown in action palette",
  
  -- Tools / Agents
  tools = {
    "run_command",
    "insert_edit_into_file",
    "agent",         -- Tool group
    "mcp",           -- MCPHub all tools
    "gkg",           -- MCP server by name (if connected)
    "gkg__search",   -- Specific tool from MCP server
  },
  
  -- MCP Servers
  mcp_servers = {
    "tavily-mcp",
    "filesystem",
  },
  
  -- Rules / system prompt contexts
  rules = {
    "default",       -- Built-in rules
    "my_custom_rule",
    -- or: rules = "none" to disable
  },
  
  -- Context attachment
  context = {
    { type = "file", path = { vim.fn.expand("$HOME/path/file.lua") } },
    { type = "url", url = "https://example.com" },
  },
  
  -- Options
  opts = {
    alias = "my-alias",      -- /my-alias in chat
    auto_submit = true,      -- Auto-submit on selection
    is_slash_cmd = true,     -- Register as slash command
    user_prompt = false,     -- No user input dialog
    stop_context_insertion = true,
    modes = { "v" },         -- Only in visual mode
    is_workflow = false,
    adapter = {
      name = "copilot",
      model = "gpt-4.1",
    },
    callbacks = {
      on_created = function(chat)
        -- Called when chat buffer is created
      end,
      on_before_submit = function(chat, message)
        -- Called before message is sent
      end,
    },
  },
  
  -- Prompts (can be table of {role, content} or function)
  prompts = {
    {
      role = "system",
      content = "System prompt text",
      opts = { visible = false },  -- Hide from chat buffer
    },
    {
      role = "user",
      content = function(context)
        return "Dynamic prompt using " .. context.filetype
      end,
      opts = { contains_code = true },
    },
  },
}
```

---

## 3. How Tools Are Attached Per Prompt

### Method 1: `tools` Field (String Array)

Tools are **statically specified** as a list of tool names:

```yaml
tools:
  - run_command
  - insert_edit_into_file
  - read_file
```

**Flow**:
1. Prompt is selected → `Actions.resolve(item, context)`
2. `get_tools(selected)` extracts `selected.tools` array
3. Passed to `Chat.new({ ..., tools = selected.tools, ... })`
4. In chat init → `lua/codecompanion/interactions/chat/init.lua:591-603`
   - If `args.tools == "none"`, skip loading
   - Otherwise, iterate and register each tool

**Source**: `lua/codecompanion/interactions/chat/init.lua:591-611`, `lua/codecompanion/interactions/init.lua:20-22`

### Method 2: Tool Groups (Predefined Collections)

CodeCompanion has **built-in tool groups** that bundle related tools:

```lua
-- From config.lua:105-177
tools = {
  groups = {
    ["agent"] = {
      description = "Agent - Can run code, edit code and modify files on your behalf",
      system_prompt = function(group, ctx) ... end,
      tools = {
        "ask_questions",
        "create_file",
        "delete_file",
        "file_search",
        "get_changed_files",
        "get_diagnostics",
        "grep_search",
        "insert_edit_into_file",
        "read_file",
        "run_command",
      },
    },
    ["files"] = {
      description = "Tools related to creating, reading and editing files",
      prompt = "I'm giving you access to ${tools} to help you perform file operations",
      tools = {
        "create_file",
        "delete_file",
        "file_search",
        "get_changed_files",
        "grep_search",
        "insert_edit_into_file",
        "read_file",
      },
    },
  },
}
```

**To use a group in a prompt**:

```yaml
tools:
  - agent    # Expands to all agent tools
  - files    # Expands to all file tools
```

### Method 3: MCP-Based Tools

CodeCompanion integrates MCP servers as tool sources. Tools are **dynamically registered** when servers connect:

```yaml
mcp_servers:
  - tavily-mcp    # Start server
  - filesystem

tools:
  - mcp           # All MCP tools from active servers
  - gkg           # Tools from "gkg" MCP server (if connected)
  - gkg__search   # Specific tool: server="gkg", tool="search"
```

**Naming convention** (from `docs/memory/codecompanion-prompt-library-gotchas.md:23-26`):
- Server names are "safe-ified": `my-server` → `my_server`
- With `add_mcp_prefix_to_tool_names = false`:
  - Group: `server_name`
  - Tool: `server_name__tool_name`
- With `add_mcp_prefix_to_tool_names = true`:
  - Group: `mcp__server_name`
  - Tool: `mcp__server_name__tool_name`

**Important**: MCPHub tools are **only available when the server is connected**.

**Source**: `lua/codecompanion/interactions/init.lua:24-29`, MCPHub integration docs

### Method 4: Inline Tool References in Prompt Text

Tools can be **referenced in the prompt content** using `@{...}` syntax:

```markdown
## user

@{agent} @{mcp}

Please search for information about ${topic} and summarize findings.
```

The `@{...}` placeholders are replaced with:
- Tool descriptions
- System prompts from tool groups
- Available MCP tool schemas

**Gotcha** (from gotchas doc): If `@{gkg}` is referenced and GKG isn't running, the LLM sees it as plaintext and may try to execute it as a shell command.

---

## 4. Tool Registration & Execution Flow

### Registration (Chat Buffer Initialization)

```
Interactions:chat() 
  → get_tools(selected) 
  → Chat.new({ tools = [...], mcp_servers = [...] })
    → chat/init.lua:494 
      → Tools.new({ chat = self, ... })
        → tools/init.lua (registry & orchestrator)
          → Registers each tool with approval manager
```

**Key code** (chat/init.lua:591-611):
```lua
if args.tools ~= "none" then
  for _, tool_name in pairs(config.interactions.chat.tools.opts.default_tools or {}) do
    self.tools:register(tool_name)
  end
  if args.tools then
    for _, tool in pairs(args.tools) do
      self.tools:register(tool)  -- Register from prompt.tools array
    end
  end
end

if args.mcp_servers == "none" then
  -- Skip MCP setup
elseif args.mcp_servers then
  helpers.start_mcp_servers(self, args.mcp_servers)  -- From prompt.mcp_servers
end
```

### Execution in Chat

Tools are invoked by the LLM via **tool calls** (structured JSON):

1. LLM generates: `use_mcp_tool(...)` or similar
2. Parser extracts tool calls
3. Approval manager checks: `is_approved(bufnr, tool_name, ...)`
4. Tool executor runs the tool
5. Output returned to LLM

---

## 5. MCP Servers Per Prompt

The `mcp_servers` field **auto-starts** specified servers:

```yaml
mcp_servers:
  - tavily-mcp
  - filesystem
```

**Flow** (interactions/init.lua:155):
```lua
mcp_servers = get_mcp_servers(self.selected),
  → Chat.new({ ..., mcp_servers = [...] })
    → chat/init.lua:604-611
      → helpers.start_mcp_servers(self, args.mcp_servers)
```

**Important differences**:
- `mcp_servers` in prompt = **auto-start** these servers for this chat
- `auto_toggle_mcp_servers = true` in config = make disabled servers visible to LLM, teach it the `toggle_mcp_server` tool (doesn't auto-start)

---

## 6. Rules Per Prompt

Rules are **context files** that get injected as system prompts:

```yaml
rules:
  - default      # Built-in: .clinerules, .cursorrules, CLAUDE.md, etc.
  - my_rule      # Custom rule group
  - none         # Disable all rules for this prompt
```

**Structure** (from config.lua:937-1029):
```lua
rules = {
  default = {
    description = "Collection of common files for all projects",
    files = {
      ".clinerules",
      ".cursorrules",
      ".goosehints",
      ".rules",
      { path = "CLAUDE.md", parser = "claude" },
      "~/.claude/CLAUDE.md",
    },
    is_preset = true,
  },
  -- Custom rules...
},
```

**How rules become prompts** (interactions/init.lua:34-47):
```lua
function get_callbacks(selected)
  local rules = selected.rules or opts.rules
  if rules and rules ~= "none" then
    local rules_cb = rules_helpers.add_callbacks(callbacks, rules)
    if rules_cb then
      callbacks = rules_cb
    end
  end
  return callbacks
end
```

Rules are converted to **callbacks** that inject rule content into the system prompt.

---

## 7. Context Attachment

The `context` field in a prompt attaches **files or URLs** to the chat:

```yaml
context:
  - type: file
    path:
      - lua/codecompanion/health.lua
      - lua/codecompanion/http.lua
  - type: file
    path: lua/codecompanion/schema.lua  # Can be string or array
  - type: url
    url: https://example.com
```

**How it works** (interactions/init.lua:77-104):
```lua
function Interactions.add_context(prompt, chat)
  local context = prompt.context
  if not context or vim.tbl_isempty(context) then
    return
  end

  local slash_commands = require("codecompanion.interactions.chat.slash_commands")
  
  vim.iter(context):each(function(item)
    if item.type == "file" or item.type == "symbols" then
      if type(item.path) == "string" then
        return slash_commands.context(chat, item.type, { path = item.path })
      elseif type(item.path) == "table" then
        for _, path in ipairs(item.path) do
          slash_commands.context(chat, item.type, { path = path })
        end
      end
    elseif item.type == "url" then
      -- Similar logic for URLs
    end
  end)
end
```

Files/URLs are **fetched when the prompt is opened** (before chat buffer is created).

---

## 8. Placeholders in Prompts

### Built-in Placeholders

Prompts can use dynamic placeholders resolved at runtime:

```markdown
# In markdown or Lua prompts

Please explain this code from buffer ${context.bufnr}:

````${context.filetype}
${context.code}
````
```

**Available placeholders** (from test examples):
- `${context.filetype}` - Current file type
- `${context.bufnr}` - Buffer number
- `${context.cwd}` - Current working directory
- `${context.code}` - Selected code
- `${context.<any_context_field>}` - Any field in context

### File-Based Placeholders

Lua files in the **same directory as the markdown prompt** can define custom placeholders:

```
prompts/
  my_prompt.md
  context.lua     # Loaded and variables available as ${context.field}
  utils.lua       # Loaded and variables available as ${utils.field}
```

**context.lua**:
```lua
return {
  helper_function = function(args)
    return "Dynamic value"
  end,
  static_value = "constant",
}
```

**In prompt**:
```
${context.helper_function}
${utils.static_value}
```

**Source**: `markdown.lua:274-345`, specifically `load_file_from_dir()` function

---

## 9. Interaction Types

Each prompt specifies an `interaction` type, which determines how it executes:

### `interaction: chat`

Opens a **chat buffer** (persistent, multi-turn):
- User can send multiple messages
- LLM can use tools
- Supports slash commands
- Rules are loaded as system prompts

```lua
{
  interaction = "chat",
  tools = { "run_command", "insert_edit_into_file" },
  mcp_servers = { "gkg" },
  rules = { "default" },
  prompts = { ... },
}
```

### `interaction: inline`

Makes **inline edits** in the current buffer:
- Quick single-turn operation
- LLM response replaces selected text or creates new buffer
- No tools by default

```lua
{
  interaction = "inline",
  prompts = { ... },
}
```

### `interaction: workflow`

Multi-stage **sequential prompts** with approvals:
- First stage sends initial messages
- Subsequent stages triggered via callbacks/events
- Each stage can have different adapters, tools, rules

**Markdown syntax for workflows**:
```yaml
opts:
  is_workflow: true
```

**In prompts** (multiple `## user` blocks are treated as stages):
```markdown
## system
System prompt

## user
Stage 1 prompt

## user
```yaml options
auto_submit: true
```
Stage 2 prompt

## user
Stage 3 prompt
```

### `interaction: cli`

Runs in a **terminal interaction** (less common).

**Source**: `lua/codecompanion/interactions/init.lua:108-279`

---

## 10. Example: Complete Markdown Prompt with All Features

```yaml
---
name: Advanced Code Analysis
description: Analyze code with MCP tools and custom rules
interaction: chat

adapter:
  name: copilot
  model: gpt-4.1

tools:
  - agent          # Built-in tool group (includes run_command, edit, read, etc.)
  - mcp            # All MCP tools
  - gkg__search    # Specific tool from GKG server

mcp_servers:
  - gkg
  - tavily-mcp

rules:
  - default
  - my_custom_analysis_rules

context:
  - type: file
    path:
      - src/main.rs
      - src/lib.rs
  - type: url
    url: https://docs.rust-lang.org/book/

opts:
  alias: analyze-code
  auto_submit: false
  is_slash_cmd: true
  modes:
    - v
  adapter:
    name: copilot
    model: gpt-5-mini
  callbacks:
    on_created: |function
      -- Enable auto-approval for file reads
      require("codecompanion.interactions.chat.tools.approvals")
        :toggle_yolo_mode(chat.bufnr)
    end
---

## system

You are an expert Rust code reviewer. Use the available tools to:
1. Search for similar patterns in the codebase using @{gkg}
2. Run tests with @{agent}
3. Analyze performance characteristics

## user

Please analyze this Rust code for potential improvements:

````rust
${context.code}
````

Focus on:
- Memory safety
- Performance
- Idiomatic Rust patterns
```

---

## 11. Markdown Parsing Details

### YAML Frontmatter Extraction

CodeCompanion uses **Tree-sitter YAML parser** to extract frontmatter:

```lua
local ok, parser = pcall(vim.treesitter.get_string_parser, content, "yaml")
if not ok then return end

local query = vim.treesitter.query.get("yaml", "prompt_library")
local tree = parser:parse()
-- ... iterate captures and decode with yaml.decode_node()
```

**Requirements**:
- `yaml` Tree-sitter parser must be installed
- `markdown` Tree-sitter parser must be installed (for prompt content)

**Missing parser error** (from gotchas doc):
```
[WARN] [Prompt Library] Missing frontmatter, name or interaction
[WARN] yaml parser not found
```

**Fix**: Install parsers in the current `NVIM_APPNAME` profile:
```bash
NVIM_APPNAME=nvim3_jelly_tinynvim nvim --headless -c "TSInstall yaml markdown" -c "qa"
```

**Source**: `markdown.lua:80-140`

### Prompt Content Parsing

After frontmatter, the **markdown content** is parsed as chat messages:

```markdown
## system

System message content (visible: false by default)

## user

User message content
```

Allowed roles:
- `system` - System prompt (typically hidden)
- `user` - User message

**Special**: YAML code blocks can provide options:

````markdown
## user

```yaml opts
auto_submit: true
```

Message content here...
````

**Source**: `markdown.lua:165-268`

---

## 12. Key Limitations & Gotchas

### 1. MCP Tools Only Available When Server Connected

```yaml
tools:
  - gkg  # ❌ Will fail if GKG isn't running
  - mcp  # ✅ Always available (but generic)
```

**Fix**: Use `@{mcp}` in text and explicit tool calls:
```
use_mcp_tool(server_name="gkg", tool_name="search", tool_input={...})
```

### 2. `vim.g.codecompanion_auto_tool_mode` (v18) Removed

**v18 code**:
```lua
content = function()
  vim.g.codecompanion_auto_tool_mode = true
  return [[@{agent} ...]]
end,
```

**v19+ (current)**:
```lua
opts = {
  callbacks = {
    on_created = function(chat)
      require("codecompanion.interactions.chat.tools.approvals")
        :toggle_yolo_mode(chat.bufnr)
    end,
  },
}
```

### 3. YAML Tree-Sitter Parser Required

Without `yaml` parser, all markdown prompts fail to load with "Missing frontmatter" warnings.

### 4. Path Expansion in `context` Field

Lua `~` and `$HOME` are **NOT expanded** automatically. Use `vim.fn.expand()`:

```yaml
# ❌ Won't work
context:
  - type: file
    path: ~/.config/nvim/init.lua

# ✅ Works
# (In Lua config, not markdown)
context = {
  { type = "file", path = { vim.fn.expand("~/.config/nvim/init.lua") } },
}
```

### 5. Markdown Files Must Have Exact Frontmatter

**Requirements**:
1. YAML frontmatter block at start (lines starting with `---`)
2. `name` field (required, displayed in action palette)
3. `interaction` field (required, one of: chat, inline, workflow, cli)
4. If not present → "Missing frontmatter..." warning, prompt skipped

---

## Summary: Full Prompt Entry Schema

### Frontmatter Fields (YAML / Lua)

| Field | Type | Required | Purpose |
|-------|------|----------|---------|
| `name` | String | ✓ | Display name in action palette |
| `interaction` | Enum | ✓ | chat, inline, workflow, cli |
| `description` | String | | Shown in action palette |
| `adapter` | Table | | `{ name: String, model: String }` |
| `tools` | Array[String] | | Tool names to register |
| `mcp_servers` | Array[String] | | MCP servers to start |
| `rules` | Array[String] | | Rule groups to load |
| `context` | Array[Table] | | Files/URLs to attach |
| `opts` | Table | | Configuration options |
| `opts.alias` | String | | Slash command name |
| `opts.auto_submit` | Boolean | | Auto-send on selection |
| `opts.is_slash_cmd` | Boolean | | Register /command |
| `opts.is_workflow` | Boolean | | Mark as workflow |
| `opts.user_prompt` | Boolean | | Show input dialog |
| `opts.stop_context_insertion` | Boolean | | Don't auto-attach visual selection |
| `opts.modes` | Array[String] | | Filter by editor mode (v, n, i, etc.) |
| `opts.callbacks` | Table | | `{ on_created, on_before_submit, ... }` |
| `prompts` | Array[Table] | ✓ | `[{ role, content, opts }]` |

### Prompts Sub-structure

```lua
prompts = {
  {
    role = "system"|"user",  -- Message role
    content = String|Function, -- Message text or function(context)
    opts = {
      visible = Boolean,     -- Show in chat?
      contains_code = Boolean,
      -- ... custom opts ...
    },
  },
}
```

---

## How to Use This in Your Config

### Simplest: Enable Markdown Prompt Directory

```lua
-- In lua/plugins/extra/codecompanion.lua
return {
  "olimorris/codecompanion.nvim",
  opts = {
    prompt_library = {
      markdown = {
        dirs = {
          vim.fn.expand("~/.config/nvim/prompts"),
        },
      },
    },
  },
}
```

Then create `~/.config/nvim/prompts/my_prompt.md`:

```yaml
---
name: My Custom Prompt
interaction: chat
description: My first markdown prompt
tools:
  - read_file
  - insert_edit_into_file
---

## system

You are helpful.

## user

Please fix this code:

````lua
${context.code}
````
```

### Advanced: Mixed Lua + Markdown

```lua
opts = {
  prompt_library = {
    -- Lua-based prompts (in config)
    ["Lua Prompt"] = {
      interaction = "chat",
      tools = { "agent" },
      prompts = { ... },
    },
    
    -- Markdown-based prompts (on disk)
    markdown = {
      dirs = {
        vim.fn.expand("~/.config/nvim/prompts"),
        function(ctx)
          if ctx.filetype == "rust" then
            return vim.fn.expand("~/.config/nvim/prompts/rust")
          end
        end,
      },
    },
  },
}
```

---

## References

**Source code**:
- `lua/codecompanion/actions/init.lua` - Prompt loading & resolution
- `lua/codecompanion/actions/markdown.lua` - Markdown parsing
- `lua/codecompanion/actions/prompt_library.lua` - Schema resolution
- `lua/codecompanion/interactions/init.lua` - Tools/MCP attachment
- `lua/codecompanion/interactions/chat/init.lua` - Chat buffer initialization
- `lua/codecompanion/config.lua` - Default config & tool groups

**Tests**:
- `tests/actions/test_markdown.lua` - Comprehensive test cases
- `tests/actions/test_prompt_library.lua` - Prompt library tests

**Examples**:
- `lua/codecompanion/actions/builtins/` - Built-in markdown prompts
- `lua/codecompanion/actions/builtins/explain.md` - Simple example
- `lua/codecompanion/actions/builtins/code_workflow.md` - Workflow example

**Documentation**:
- `docs/memory/codecompanion-prompt-library-gotchas.md` - Known issues & fixes
