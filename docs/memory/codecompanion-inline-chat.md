# CodeCompanion Inline Chat - Research & API Reference

## Overview

CodeCompanion's inline chat system allows AI-assisted code editing directly in Neovim buffers. This document details how inline chat is triggered, configured, and controlled programmatically.

---

## 1. Entry Points & Command Definitions

### User Command: `:CodeCompanion <prompt>`

**File**: `lua/codecompanion/commands/init.lua` (lines 50-135)

```lua
{
  cmd = "CodeCompanion",
  callback = function(opts)
    -- Detect slash commands (prompt library)
    if opts.fargs[1] and string.sub(opts.fargs[1], 1, 1) == triggers.mappings.slash_commands then
      local prompt = string.sub(opts.fargs[1], 2)
      if #opts.fargs > 1 then
        opts.user_prompt = table.concat(opts.fargs, " ", 2)
      end
      return codecompanion.prompt(prompt, opts)  -- Routes to prompt library
    end

    -- If no prompt, ask user for input
    if #vim.trim(opts.args or "") == 0 then
      vim.ui.input({ prompt = config.display.action_palette.prompt }, function(input)
        if #vim.trim(input or "") == 0 then
          return
        end
        opts.args = input
        return codecompanion.inline(opts)  -- Triggers inline with user input
      end)
    else
      codecompanion.inline(opts)  -- Triggers inline with provided prompt
    end
  end,
  opts = {
    desc = "Use the CodeCompanion Inline Assistant",
    range = true,           -- Supports visual selections
    nargs = "*",            -- Accepts variable arguments
    complete = function(...) -- Provides completions for adapters, prompts, editor context
      -- Returns: adapter=<name>, /<prompt>, @{editor_context}
    end,
  },
}
```

**Key Points**:
- `:CodeCompanion <prompt>` - inline edit with visual selection
- `:CodeCompanion` - prompts user for input
- `:CodeCompanion /prompt_name` - routes to prompt library
- Supports `range=true` for visual selection
- Completions include adapters, prompt library, and editor context

---

## 2. Programmatic API: `CodeCompanion.inline()`

**File**: `lua/codecompanion/init.lua` (lines 36-45)

```lua
---Run the inline assistant from the current Neovim buffer
---@param args table
---@return nil
CodeCompanion.inline = function(args)
  local context = get_context(api.nvim_get_current_buf(), args)
  local inline = require("codecompanion.interactions.inline").new({ buffer_context = context })
  if inline then
    inline:prompt(args.args)
  end
end
```

### Usage

```lua
require("codecompanion").inline({
  args = "refactor this function to be more efficient",
})
```

**Parameter `args`**:
- `args.args` (string) - the prompt to send to the LLM
- Other fields inherited from context utils

---

## 3. Inline Class: `CodeCompanion.Inline`

**File**: `lua/codecompanion/interactions/inline/init.lua` (lines 178-851)

### Class Definition

```lua
---@class CodeCompanion.Inline
---@field id number The ID of the inline prompt
---@field adapter CodeCompanion.HTTPAdapter The adapter to use
---@field buffer_context CodeCompanion.BufferContext Current buffer state
---@field bufnr number Buffer number for edits
---@field prompts table Messages to send to LLM
---@field classification CodeCompanion.Inline.Classification Placement configuration
```

### Constructor: `Inline.new(args)`

Constructor accepts:
- `args.adapter?` - string name or HTTPAdapter config
- `args.buffer_context` - current buffer context
- `args.chat_context?` - messages from chat buffer
- `args.placement?` - "replace" | "add" | "before" | "new" | "chat"
- `args.prompts?` - external prompts (from prompt library)
- `args.opts?` - additional options
- `args.pre_hook?` - pre-execution hook returning buffer number

**Default Adapter Resolution**:
1. Uses `args.adapter` if provided
2. Falls back to `config.interactions.inline.adapter`
3. Respects `vim.g.codecompanion_adapter` if set
4. Only supports HTTP adapters (not ACP)

### Key Methods

#### `inline:prompt(user_prompt?: string) -> nil`

Initiates the inline prompt workflow. Flow:
1. Builds system prompt with language context
2. Parses special syntax (adapter names, editor context)
3. Adds visual selection as context
4. Submits to LLM
5. Processes output (JSON response)
6. Places code in buffer

#### `inline:set_adapter(adapter: string|table|function) -> nil`

Override the adapter for this inline instance.

#### `inline:parse_special_syntax(prompt: string) -> string`

Extracts and applies adapter overrides from prompt:
- `adapter=<name>` - direct syntax
- `<adapter_name> <prompt>` - legacy first-word syntax

#### `inline:submit(prompts: table) -> nil`

Submits formatted prompts to LLM (disables streaming internally).

#### `inline:done(output: string) -> nil`

Processes LLM response (expects JSON with code, language, placement).

#### `inline:place(placement: string) -> Inline`

Positions cursor for code insertion (replace/add/before/new).

#### `inline:output(code: string) -> nil`

Writes code to buffer at prepared position.

#### `inline:stop() -> nil`

Cancels current request and cleans up.

---

## 4. Adapter Override Methods

### Method 1: Via Constructor Args

```lua
local inline = require("codecompanion.interactions.inline").new({
  buffer_context = context,
  adapter = "gpt4o",
})
```

### Method 2: Via `parse_special_syntax()` in Prompt

```lua
inline:prompt("adapter=claude_code refactor this function")
```

### Method 3: Via Global Variable

```lua
vim.g.codecompanion_adapter = "gpt4o"
require("codecompanion").inline({ args = "refactor this" })
```

**Precedence**:
1. Constructor `args.adapter` (if HTTP)
2. `config.interactions.inline.adapter` (default)
3. `vim.g.codecompanion_adapter` (global override)

---

## 5. Complete Example

```lua
local context_utils = require("codecompanion.utils.context")

local context = context_utils.get(vim.api.nvim_get_current_buf(), {})

local inline = require("codecompanion.interactions.inline").new({
  buffer_context = context,
  adapter = "claude_code",
  placement = "replace",
})

if inline then
  inline:prompt("add error handling to this function")
end
```

---

## 6. Model/Adapter Specification Per-Call

**Inline API**: No built-in model parameter. Use adapter config instead.

**Chat API** (alternative with full support):
```lua
require("codecompanion").chat({
  params = {
    adapter = "claude_code",
    model = "claude-3-5-sonnet",
  },
  user_prompt = "refactor this",
})
```

---

## 7. JSON Response Schema

LLM must return valid JSON:

**With placement**:
```json
{
  "code": "const result = array.map(item => item.value);",
  "language": "javascript",
  "placement": "replace"
}
```

**For chat redirection**:
```json
{
  "placement": "chat"
}
```

**Error response**:
```json
{
  "error": "Unable to complete this request"
}
```

---

## 8. Key Takeaways

- **Programmatic API**: `require("codecompanion").inline({ args = "prompt" })`
- **Adapter Override**: Constructor arg, prompt syntax, or global variable
- **Model Override**: Not directly supported; use chat API
- **Placement Control**: Via constructor or LLM response
- **Streaming**: Disabled internally, re-enabled after
- **Visual Context**: Auto-included for selections
- **JSON Validation**: LLM response must be valid JSON

---

**Last Updated**: 2026-03-29
