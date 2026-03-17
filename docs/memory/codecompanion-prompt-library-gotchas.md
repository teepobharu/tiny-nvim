# CodeCompanion Prompt Library Gotchas

As of version v19.x

Living reference for authoring prompts in the `prompt_library` config. Updated as new caveats are found.

## Tool References (`@{...}` syntax)

### Static vs Dynamic Tool Groups

| Group                 | Type              | Registration                                  | When Available                      |
| --------------------- | ----------------- | --------------------------------------------- | ----------------------------------- |
| `@{agent}`            | Static (built-in) | CodeCompanion config                          | Always                              |
| `@{mcp}`              | Static (MCPHub)   | `create_static_tools()` on plugin load        | Always (if MCPHub installed)        |
| `@{<server_name>}`    | Dynamic (MCPHub)  | `servers_updated` / `tool_list_changed` event | Only if MCP server is **connected** |
| `@{<server>__<tool>}` | Dynamic (MCPHub)  | Same as above                                 | Only if MCP server is **connected** |

**Gotcha**: If you reference `@{gkg}` in a prompt and the GKG SSE server isn't running, the reference stays as plaintext — the LLM reads it literally and may try to execute it as a shell command.

**Fix**: Use `@{mcp}` (always available) + explicit `use_mcp_tool(server_name="<server>", tool_name="<tool>", tool_input={...})` calls in the prompt text.

### Naming convention (MCPHub → CodeCompanion)

- Server names are "safe-ified": non-alphanumeric chars → `_` (e.g. `my-server` → `my_server`)
- With `add_mcp_prefix_to_tool_names = false`: group = `server_name`, tool = `server_name__tool_name`
- With `add_mcp_prefix_to_tool_names = true`: group = `mcp__server_name`, tool = `mcp__server_name__tool_name`

## auto_toggle_mcp_servers

`auto_toggle_mcp_servers = true` does **NOT** auto-start servers. It:

1. Makes **disabled** servers visible in the LLM system prompt
2. Teaches the LLM the `toggle_mcp_server` tool exists (on the `mcphub` native server)

To actually start a disabled/stopped server from within a prompt, the LLM must explicitly call:

```
use_mcp_tool(server_name="mcphub", tool_name="toggle_mcp_server", tool_input={server_name="gkg", action="start"})
```

### `toggle_mcp_server` schema guardrail

Common runtime error:
`Missing required parameters: server_name and action`

Root cause: LLM emits malformed `tool_input` for `toggle_mcp_server`.

Prompt template fix:

1. Start with `get_current_servers` (mcphub) to detect whether `gkg` is disabled
2. Only then call `toggle_mcp_server` when needed
3. Enforce exact call shape in prompt text:

```
use_mcp_tool({
  server_name = "mcphub",
  tool_name = "toggle_mcp_server",
  tool_input = { server_name = "gkg", action = "start" }
})
```

4. Add instruction: "If tool error says missing params, retry immediately with corrected payload."

This reduces hallucinated keys and improves model reliability in autonomous prompts.

## Auto-Approve / Auto Tool Mode

### `vim.g.codecompanion_auto_tool_mode = true`

- Set inside the prompt `content` function (before the return)
- Disables approval dialogs for ALL tool calls in that chat session
- Automatically saves buffers modified by tools
- **Gotcha**: This is a global Vim variable — affects ALL open chats in this Neovim instance, not just the current one
- Useful for agentic/autonomous prompts; avoid for prompts that edit user code

### MCPHub `autoApprove` (mcphub.json)

- Per-server, per-tool auto-approve configured in `mcphub.json`
- Example: `"autoApprove": ["list_projects", "toggle_mcp_server"]`
- Independent of `codecompanion_auto_tool_mode` — MCPHub checks its own approval list
- **Gotcha**: Even with `auto_tool_mode = true`, MCPHub may still prompt for approval if the tool isn't in `autoApprove`

## Context Attachment

### `context` field (prompt_library entry)

```lua
context = {
  { type = "file", path = { vim.fn.expand("$HOME/path/to/file.lua") } },
  { type = "url", url = "https://..." },
}
```

- Files and URLs are fetched and attached as context when the prompt opens
- `path` must be a table of strings (not a single string)
- Use `vim.fn.expand()` for `$HOME` / `~` paths — Lua doesn't expand shell vars
- URLs are fetched at prompt open time (blocks briefly)

### `#buffer{watch}` variable

- Reference current buffer with auto-watching: `#buffer{watch}`
- Only works in the prompt `content` string, not in `context` field
- **Gotcha**: Must be placed in the actual message content the LLM sees

## Prompt opts (v19+ syntax changes)

| v18 (old)                        | v19+ (current)                                                           | Notes                                          |
| -------------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------- |
| `strategy = "chat"`              | `interaction = "chat"`                                                   | Both still work but `interaction` is preferred |
| `short_name = "foo"`             | `alias = "foo"`                                                          | `short_name` silently ignored in v19           |
| `adapter = { name = "copilot" }` | `adapter = "copilot"` or `adapter = { name = "copilot", model = "..." }` | String shorthand or table with model override  |
| `strategy = "workflow"`          | `is_workflow = true` in opts                                             | Workflow prompts use `opts.is_workflow` now    |

## Adapter / Model in Prompts

```lua
opts = {
  adapter = {
    name = "copilot",
    model = "gpt-5-mini",
  },
}
```

- Model override **only works** when specified in prompt `opts.adapter` table
- Does NOT work when set in `interactions.chat.adapter` as `{ name = "copilot", model = "..." }` (known bug — needs schema override in `adapters.http` instead)
- **Gotcha**: Claude models cannot have both `temperature` AND `top_p` — will error

## Slash Commands vs Action Palette

| Field                  | Effect                                                            |
| ---------------------- | ----------------------------------------------------------------- |
| `is_slash_cmd = true`  | Available as `/alias` in chat buffer                              |
| `is_slash_cmd = false` | Only appears in Actions palette (`:CodeCompanionActions`)         |
| `auto_submit = true`   | Sends immediately on selection — good for autonomous prompts      |
| `auto_submit = false`  | Opens chat with content pre-filled — user can edit before sending |

## Common Patterns

### Agentic autonomous prompt

```lua
["My Agentic Task"] = {
  interaction = "chat",
  description = "...",
  opts = {
    alias = "my-task",
    is_slash_cmd = true,
    auto_submit = true,
    adapter = { name = "copilot", model = "gpt-5-mini" },
  },
  prompts = {
    {
      role = "user",
      content = function()
        vim.g.codecompanion_auto_tool_mode = true
        return [[@{agent} @{mcp}
Step 0: Ensure server running via toggle_mcp_server...
Step 1: Do the work...]]
      end,
    },
  },
},
```

### Prompt with file context

```lua
["My Context Task"] = {
  interaction = "chat",
  opts = { alias = "ctx-task", is_slash_cmd = true, auto_submit = false },
  context = {
    { type = "file", path = { vim.fn.expand("$HOME/path/file.lua") } },
  },
  prompts = {
    { role = "user", content = "Instructions here..." },
  },
},
```

### RESOLVED: "Missing frontmatter, name or interaction" warnings on slash commands

**Symptom**: Warnings flood the log and UI when opening chat or invoking any slash command:

```log
[WARN] [Prompt Library] Missing frontmatter, name or interaction in `.../actions/builtins/commit.md`
[WARN] [Prompt Library] Missing frontmatter, name or interaction in `.../actions/builtins/explain.md`
...
```

Also shows in `:checkhealth codecompanion`:

```
⚠️ WARNING yaml parser not found
```

**Root cause**: CodeCompanion v19 switched builtin prompts from Lua tables to `.md` files with YAML frontmatter. It uses the `yaml` tree-sitter parser to extract `name`, `interaction`, and other fields from the frontmatter block. Without the parser, frontmatter extraction fails silently and every builtin prompt is treated as invalid.

**Why yaml parser was missing (worktree-specific)**: Each `NVIM_APPNAME` profile has its own parser directory (`~/.local/share/<NVIM_APPNAME>/lazy/nvim-treesitter/parser/`). The worktree profile (`nvimwt3a`) had an empty parser dir because:

1. The treesitter config uses `require("nvim-treesitter").setup(opts)` (Neovim 0.11+ built-in module)
2. The old `require("nvim-treesitter.configs").setup(opts)` is commented out in `lua/plugins/ui.lua:165`
3. The built-in module does **not** honor `ensure_installed` — that feature belongs to the plugin's `configs` module
4. So despite `ensure_installed = { "yaml", "markdown" }` being set in both `myAi.lua` and `codecompanion.lua`, parsers are never auto-installed

The main profile (`nvim3_jelly_tinynvim`) works because its parsers were installed previously and persist in its data dir.

**Fix**: Install parsers manually in the affected profile:

```bash
# Install just yaml (minimum fix)
NVIM_APPNAME=nvimwt3a nvim --headless -c "TSInstall yaml" -c "qa"

# Or install all parsers matching the main profile
NVIM_APPNAME=nvimwt3a nvim --headless -c "TSInstall yaml markdown markdown_inline lua bash vim vimdoc json jsonc diff html javascript jsdoc luadoc luap printf python query regex toml tsx typescript xml" -c "qa"
```

**Long-term note**: If you want `ensure_installed` to auto-install in new profiles, you'd need to re-enable `require("nvim-treesitter.configs").setup(opts)` or add a custom autocmd that calls `:TSInstall` for missing parsers on startup.

### RESOLVED: `vim.g.codecompanion_auto_tool_mode` replaced by per-chat yolo mode

**v18 (removed)**: `vim.g.codecompanion_auto_tool_mode = true` — global, affects all chats, no longer read by v19.

**v19 (current)**: Per-chat-buffer yolo mode via the approvals module.

| Method | Scope | Usage |
|--------|-------|-------|
| `approvals:toggle_yolo_mode(bufnr)` | Single chat buffer | Programmatic (in callbacks) |
| `gty` keymap in chat buffer | Single chat buffer | Interactive toggle |
| `opts.allowed_in_yolo_mode = false` | Per tool | Opt-out specific tools even in yolo |

**Migration pattern** — use `opts.callbacks.on_created` in prompt_library entries:

```lua
-- Helper (define once at top of file)
local function enable_yolo_on_created(chat)
  require("codecompanion.interactions.chat.tools.approvals"):toggle_yolo_mode(chat.bufnr)
end

-- In prompt_library entry
["My Prompt"] = {
  interaction = "chat",
  opts = {
    callbacks = { on_created = enable_yolo_on_created },
  },
  prompts = { ... },
}
```

**Official docs example** ([agentic-workflows](https://codecompanion.olimorris.dev/extending/agentic-workflows#creating-agentic-workflows)) shows it inside `content = function()`:

```lua
content = function()
  local approvals = require("codecompanion.interactions.chat.tools.approvals")
  approvals:toggle_yolo_mode()
  return [[...]]
end,
```

**Why `on_created` callback is more correct**: The docs example calls `toggle_yolo_mode()` without a bufnr, which defaults to `vim.api.nvim_get_current_buf()`. But content functions run **before** `chat.new()` — the current buffer at that point is the user's source buffer, not the chat buffer. Meanwhile, all `is_approved()` checks use the **chat's bufnr** (verified in source):

- `tools/init.lua:244` → `approvals:is_approved(self.bufnr)`
- `tools/orchestrator.lua:279` → `Approvals:is_approved(self.tools.bufnr, ...)`
- `tools/builtin/insert_edit_into_file/init.lua:174` → `approvals:is_approved(opts.chat_bufnr, ...)`

So the docs pattern sets yolo on the **wrong buffer** (source buf ≠ chat buf). It would only work if bufnr numbers happen to collide. Using `opts.callbacks.on_created` guarantees the chat buffer exists and passes `chat.bufnr` explicitly.

**Key v19 yolo_mode behaviors:**
- Respects `allowed_in_yolo_mode = false` per tool (e.g. `run_command` is excluded by default)
- Respects `require_cmd_approval` — yolo overrides it unless tool opts out
- `approvals:reset(bufnr)` clears all approvals for a chat

Commands

- https://codecompanion.olimorris.dev/usage/chat-buffer/slash-commands
- No more quickfix commands ?

Others:

- TODO: create another task and rmeove from this file use plugin history ravitemer/codecompanion-history.nvim
