---
title: "Exploratory scope for MCPHub instruction files catalog view"
status: open
priority: low
created: 2026-07-10
updated: 2026-07-10
refs: []
related:
  - [MCPHub.nvim Source](https://github.com/ravitemer/mcphub.nvim)
  - [MCPHub Memory Doc](docs/memory/mcphub.md)
  - [Instruction Files Config Task](tasks/open/mcphub-instruction-files-config.md)
---

## Objective

Explore the scope and feasibility of adding a catalog list view to MCPHub.nvim that surfaces all AI agent instruction files (AGENTS.md, CLAUDE.md, etc.) with file paths, content preview, and openable actions.

## Research

### Why this matters

There is no single place to browse all the instruction files that guide AI agents across the system. They are scattered across 8+ locations (see "Data source design" below). Having a catalog view inside MCPHub (or as a separate picker) would let the user quickly find, preview, and edit these files from one place.

### MCPHub.nvim UI architecture

#### View system

MCPHub uses a **class-based view inheritance model** rooted in `lua/mcphub/ui/views/base.lua`:

- **`View` base class** ([base.lua:L1-L350](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/base.lua)):
  - Each view gets a parent `ui` (the `MCPHub.UI` instance), a `name`, `keymaps` table, and `interactive_lines` array.
  - Views register keymaps via `View:add_keymap(key, action, desc, silent)` ([base.lua:L93-L103](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/base.lua)).
  - The lifecycle is: `before_enter()` -> `draw()` (which calls `render()`) -> `after_enter()`. On leave: `before_leave()` -> `after_leave()`.
  - `draw()` ([base.lua:L293-L347](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/base.lua)): Clears the buffer, calls `render()` for content, `render_footer()` for keymaps, adds padding to fill window height, renders each `NuiLine` to the buffer with extmarks for highlights.
  - Line tracking: `View:track_line(line_nr, type, context)` ([base.lua:L179-L185](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/base.lua)) populates `interactive_lines`, which is queried on cursor move to show EOL virtual-text hints.

- **UI singleton** ([ui/init.lua:L1-L280](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/init.lua)):
  - `UI:new(opts)` creates one buffer + one floating window, holds a table of view instances.
  - View names are defined as `ViewName` enum ([ui/init.lua:L26-L31](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/init.lua)):
    ```lua
    local ViewName = {
        MAIN = "main",
        LOGS = "logs",
        HELP = "help",
        CONFIG = "config",
        MARKETPLACE = "marketplace",
    }
    ```
  - Views are initialized in `UI:init_views()` ([ui/init.lua:L123-L138](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/init.lua)):
    ```lua
    function UI:init_views()
        local MainView = require("mcphub.ui.views.main")
        self.views = {
            main = MainView:new(self),
            logs = require("mcphub.ui.views.logs"):new(self),
            help = require("mcphub.ui.views.help"):new(self),
            config = require("mcphub.ui.views.config"):new(self),
            marketplace = require("mcphub.ui.views.marketplace"):new(self),
        }
        self.current_view = "main"
    end
    ```
  - View switching via `UI:switch_view(view_name)` ([ui/init.lua:L247-L261](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/init.lua)): Calls `before_leave()`/`after_leave()` on old view, sets `current_view`, then `before_enter()`/`draw()`/`after_enter()` on new view.

#### Header / tab bar

The header with navigation buttons is rendered by `Text.render_header()` in [utils/text.lua:L169-L218](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/text.lua):

```lua
local btn_list = {
    { key = "H", label = "Hub", view = "main" },
    { key = "M", label = "Marketplace", view = "marketplace" },
    { key = "C", label = "Config", view = "config" },
    { key = "L", label = "Logs", view = "logs" },
    { key = "?", label = "Help", view = "help" },
}
```

Each button is rendered as `[ K Label ]` with selected/inactive highlight groups. The buttons are centered in the window. Adding a 6th button requires adding an entry here and ensuring the window is wide enough (or the header wraps).

Global navigation keymaps are set up in `UI:setup_keymaps()` ([ui/init.lua:L155-L182](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/init.lua)):

```lua
map("H", function() self:switch_view("main") end, "Switch to Home view")
map("M", function() self:switch_view("marketplace") end, "Switch to Marketplace")
map("C", function() self:switch_view("config") end, "Switch to Config view")
map("L", function() self:switch_view("logs") end, "Switch to Logs view")
map("?", function() self:switch_view("help") end, "Switch to Help view")
```

#### Row rendering pattern

Rows use `NuiLine` (a text composition utility) with `Text.pad_line()` for consistent horizontal padding. Interactive rows are tracked via `View:track_line()` and show hints on hover. See [renderer.lua:L130-L210](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/renderer.lua) for the `render_cap_section()` function which is the canonical pattern for rendering lists of interactive items with icons, names, and tracked line mappings.

#### State management

Global state lives in [state.lua](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/state.lua):
- Pub-sub pattern: `State:subscribe(callback, types)` and `State:notify_subscribers(changes, type)`.
- The UI subscribes to state changes and re-renders when relevant keys change ([ui/init.lua:L75-L102](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/init.lua)).
- For an instruction files view, you'd likely scan files at view-enter time rather than watching state — similar to how the `HelpView` loads content on each `render()` call.

### Current `l` key behavior in the main view

In `MainView` ([views/main.lua](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/main.lua)):

- **Browse mode** (default): `l` is mapped to `self:handle_action()` ([main.lua:L338-L340](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/main.lua)).
- **Capability mode** (when viewing tools/resources/prompts): `l` is mapped to `self.active_capability:handle_action()` ([main.lua:L280-L286](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/main.lua)).

`handle_action()` dispatches based on the line type (obtained from `self:get_line_info(line)` which queries `interactive_lines`):

| Line Type | `l` Action | Code Reference |
|-----------|-----------|----------------|
| `server` (connected) | Toggle expand/collapse capabilities | [main.lua:L300-L330](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/main.lua) |
| `server` (unauthorized) | Open OAuth authorization URL | [main.lua:L331-L340](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/main.lua) |
| `tool`/`resource`/`resourceTemplate`/`prompt` | Enter capability mode (open test/preview interface) | [main.lua:L354-L370](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/main.lua) |
| `customInstructions` | Open custom instructions editor | [main.lua:L371-L373](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/main.lua) |
| `workspace` | Toggle expand/collapse workspace details | [main.lua:L377-L393](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/main.lua) |
| `create_server` | Enter create server capability | [main.lua:L342-L352](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/main.lua) |
| `add_server` | Open server config editor | [main.lua:L374-L375](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/main.lua) |
| `breadcrumb` | Show prompts preview | [main.lua:L292-L294](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/main.lua) |

Key aliases: `<CR>` and `o` are aliased to `l` in browse mode ([main.lua:L385-L388](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/main.lua)).

### Approaches evaluated

#### Approach A: New MCPHub tab (6th tab)

Create a dedicated `InstructionsView` that lists all instruction files.

**Implementation:**

1. **Create `lua/mcphub/ui/views/instructions.lua`** — a new view class inheriting from `View`. Pattern to follow: `HelpView` ([views/help.lua](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/help.lua)) is the simplest reference — it uses sub-tabs and renders static/dynamic markdown content.
2. **Register in `UI:init_views()`** ([ui/init.lua:L123-L138](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/init.lua)):
   ```lua
   instructions = require("mcphub.ui.views.instructions"):new(self),
   ```
3. **Add header button** — Add entry to `btn_list` in [text.lua:L183-L193](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/text.lua):
   ```lua
   { key = "I", label = "Instructions", view = "instructions" },
   ```
4. **Add global keymap** — In [ui/init.lua:L155-L182](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/init.lua):
   ```lua
   map("I", function() self:switch_view("instructions") end, "Switch to Instructions view")
   ```
5. **Data source** — The view would need to scan for instruction files (see "Data source design" below).
6. **Content preview** — Use existing `Text.render_markdown()` ([text.lua:L220-L270](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/text.lua)) for preview rendering. For a list view, each row would show: file path (truncated/relative), associated tool/agent (e.g., "claude", "pi", "codex", "cursor"), scope (global / project / repo), brief description from first heading.
7. **Openable actions** — On `l` press for an instruction row: **Edit in buffer** (`vim.cmd("edit " .. filepath)` same as Config view's `e` action), **Preview in split** (open file in a horizontal split within the MCPHub window), **Copy content** (read and copy file content to clipboard), **Toggle active** (if tracking which instructions are "active" for a given session).

**Estimated complexity:** Medium. ~150-250 lines of Lua for the view, ~20 lines across 2 files for registration/header. The main complexity is in the file scanning logic and organizing results into a useful hierarchy.

**Risks:**
- 6 header buttons may overflow on narrower windows. The header is centered and each button is ~15-20 chars wide with spacing. 6 buttons = ~120 chars minimum, which may exceed 0.8 * columns on smaller windows.
- Adding to MCPHub's core views requires modifying upstream code (or forking), unless done as a local patch in `patches/`.

#### Approach B: Integrate into Config view

The existing Config view ([views/config.lua](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/config.lua)) already shows config files in a tab-bar. Could add an "Instructions" sub-tab alongside the config file tabs.

**Pros:** No new header button needed, minimal UI changes, stays under the `C` key.
**Cons:** Config view is specifically for JSON config files; mixing instruction files there is semantically mixed. Would need to extend `ConfigView:before_enter()` to discover and include instruction files in the tab list.

**Estimated complexity:** Low-Medium. ~100 lines, mostly file scanning + tab rendering.

#### Approach C: Snacks picker (Recommended first step)

Instead of a new MCPHub tab, create a **Snacks picker** that scans and lists instruction files. This would be a standalone Neovim command in the user's config, not touching MCPHub at all.

**Implementation sketch:**
```lua
-- lua/utils/instruction_picker.lua
local function open_instructions_picker()
    local instructions = {
        { path = "~/.agents/AGENTS.md", label = "Shared Agents", scope = "global" },
        { path = "~/.claude/settings.json", label = "Claude Settings", scope = "global" },
        { path = "./.config/nvim3_jelly_tinynvim/AGENTS.md", label = "Nvim Config", scope = "project" },
        -- ... dynamically scanned
    }

    Snacks.picker.files({
        title = "Instruction Files",
        items = instructions,
        -- custom renderer for path, label, scope columns
    })
end
```

**Pros:**
- Zero changes to MCPHub source (no upstream dependency)
- Snacks picker already supports search, filtering, column display
- Can be bound to any key in the user's Neovim config
- Doesn't compete with MCPHub's tab real estate
- Can integrate with existing file opening workflows

**Cons:**
- Not part of the MCPHub UI — user would need a separate key binding
- Less "batteries included" than an MCPHub view (no built-in markdown rendering, but Snacks picker can open files directly)

### Data source design

The catalog would scan these paths:

```lua
local instruction_paths = {
  -- Global (shared)
  { path = "~/.agents/AGENTS.md", label = "Shared Agents", agent = "all", scope = "global" },
  { path = "~/.agents/skills/", label = "Shared Skills", agent = "all", scope = "global" },

  -- Per-agent global
  { path = "~/.claude/settings.json", label = "Claude Settings", agent = "claude", scope = "global" },
  { path = "~/.codex/AGENTS.md", label = "Codex Instructions", agent = "codex", scope = "global" },
  { path = "~/.config/opencode/AGENTS.md", label = "OpenCode Instructions", agent = "opencode", scope = "global" },
  { path = "~/.cursor/rules/shared.mdc", label = "Cursor Rules", agent = "cursor", scope = "global" },
  { path = "~/.pi/agent/AGENTS.md", label = "pi Instructions", agent = "pi", scope = "global" },

  -- Neovim-specific
  { path = "~/.config/nvim3_jelly_tinynvim/AGENTS.md", label = "Nvim Config", agent = "nvim", scope = "project" },
  { path = "~/.config/nvim3_jelly_tinynvim/tasks/AGENTS.md", label = "Nvim Tasks", agent = "nvim", scope = "project" },

  -- MCPHub-specific
  { path = "~/dotfiles/ai/mcp/mcphub.json", label = "MCPHub Config", agent = "mcphub", scope = "global" },
}
```

Each entry shows: file path, associated agent/tool, scope (global/project), and line count or brief description.

### Research gaps

1. **Instruction file discovery logic** — No canonical list exists. Would need to be defined based on the user's specific setup. A configurable list in `opts.instructions.paths` would be ideal but doesn't exist yet.
2. **Header width overflow** — Adding a 6th button may break on narrow windows. The current code has no wrapping or truncation logic for the header buttons. This would need to be tested empirically.
3. **MCPHub version compatibility** — User is on v6.2.0. If MCPHub adds more tabs in a future version, conflicts could arise. A local patch approach would need maintenance.
4. **Performance of file scanning** — If scanning a large number of paths, the view `render()` could become slow. Caching at `before_enter()` time would help, but this wasn't analyzed in detail.

## Success Criteria

- [ ] Feasibility assessment completed with specific code references
- [ ] Recommended approach documented with pros/cons
- [ ] Data source (instruction file paths) cataloged
- [ ] Row design and actions defined
- [ ] If Approach C (Snacks picker) is chosen: prototype ready for testing

## Verification

### How to verify

N/A — This is an exploratory/scoping task. Deliverable is the assessment document itself.

### Checklist

- [ ] Three approaches evaluated with code-level references
- [ ] Recommended approach identified
- [ ] Implementation scope estimated (lines of code, files affected)
- [ ] Risks and constraints documented
- [ ] Follow-up task created for implementation (if applicable)

## References

- [MCPHub.nvim GitHub](https://github.com/ravitemer/mcphub.nvim) — Primary source
- [UI init.lua](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/init.lua) — View registration, keymaps
- [Base view class](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/base.lua) — Rendering pipeline
- [Main view](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/main.lua) — `l` key dispatch
- [Header rendering](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/text.lua) — Tab bar buttons
- [Config view](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/config.lua) — Reference for file tabs
- [Help view](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/ui/views/help.lua) — Simplest view reference
- [Renderer](https://github.com/ravitemer/mcphub.nvim/blob/main/lua/mcphub/utils/renderer.lua) — Row rendering pattern
- Research brief: `/tmp/mcphub-research-2.md` — full research output from this session
- [Related task: Instruction Files Config](tasks/open/mcphub-instruction-files-config.md) — Companion task for config-side changes
