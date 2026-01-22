-- NOTE (DO NOT REMOVE): Snacks picker requirements and expectations
-- The prompt helper requirements:
-- 1. be able to read prompt files from configured directories
--     vim.fn.expand("$HOME/Personal/mynotes/Extras/Template/copilot-custom-prompts/"),
    -- vim.fn.expand("$HOME/AgodaGit/tools/trip-ai-tools/prompt/"),
    -- vim.fn.expand("$HOME/AgodaGit/tools/trip-ai-tools/instruction/"),
-- 2. be able to filter files by patterns like "*.prompt.md", "*.instructions.md"
-- 3. show a picker UI to select from the found prompt files
-- 4. show a preview of the selected prompt file content
-- 5. Sort the list by parent directory and filename
-- 6. on selection, read the file content, strip any YAML frontmatter, and paste at the current cursor position
-- 7. keybind support
--  - Below is same as normal files mappings in neovim (reuse or create new if not possible)
--  - Ctrl-v to open selected prompt file in a vertical split 
--  - Ctrl-s to open selected prompt file in a horizontal split
--  - New mappings below
--  - None right now
--  8. UI guidelines, preview pane is open by default, show 50% of the preview in conjunction with main axis the list is shown
-- - Requires the "Snacks" picker plugin exposing an API compatible with:
--     Snacks.picker.pick { ... }  -- used in this module
-- - Expected options/behavior of Snacks.picker.pick used here:
--     * items: array of tables { text = string, name = string, parent = string, file = string }
--     * title: string
--     * format: can be "text" or a function; this code uses "text"
--         format = function(item, picker)
--   sample fns
    --   return {
    --     { "[" .. (item.text or "") .. "]", "SnacksPickerTitle" },
    --     { " - ", "Comment" },
    --     { item.detail or "", "Normal" },
    --   }
    -- end,
--     * layout: supports preset "vscode" and preview = { width = number, height = number }
--     sample : https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/picker/config/layouts.lua#L163
--     * preview: function(ctx) -> either:
--         - return true after writing to ctx.buf (ctx.buf must be a valid buffer id), or
--         - return { text = string, ft = string } as preview content
--       The preview function is passed ctx with ctx.item and ctx.buf.
--     * mappings: table mapping key strings to functions (picker, item) -> void
--     * actions: table with confirm = function(picker, item) -> void
-- - The preview function in this module relies on:
--     * ctx.buf being a valid buffer id (nvim_buf_* APIs are used)
--     * `vim.api.nvim_buf_set_lines`, `vim.api.nvim_buf_set_option`,
--       `vim.api.nvim_buf_add_highlight`, `vim.api.nvim_buf_is_valid`
--     * a named namespace created via vim.api.nvim_create_namespace
--     * ability to set buffer filetype via vim.bo[buf].filetype
-- - File discovery expects Neovim vim.fn functions:
--     * vim.fn.globpath, vim.fn.isdirectory, vim.fn.filereadable, vim.fn.fnamemodify,
--       vim.fn.readfile, vim.fn.expand, vim.fn.globmatch
-- - The code uses vim.pesc for safe pattern escaping; ensure your Neovim version provides vim.pesc
--   (or adapt into a fallback if using older Neovim).
-- - Notifications and UI fallbacks:
--     * Uses vim.notify for warnings
--     * Falls back to vim.ui.select if Snacks is not available (earlier versions may rely on this)
-- - Misc:
--     * The module uses standard Lua / Neovim APIs; ensure Neovim >= 0.5 (better with 0.7+) for full API support.
-- NOTE (DO NOT REMOVE): This comment documents runtime requirements for the Snacks picker integration.

local M = {}
local preview_ns = vim.api.nvim_create_namespace("prompts_helper_preview")

-- Default configuration
-- Support both a single prompt_dir (backwards compatible) and prompt_dirs (array)
M.config = {
  prompt_dirs = {
    vim.fn.expand("$HOME/Personal/mynotes/Extras/Template/copilot-custom-prompts/"),
    vim.fn.expand("$HOME/AgodaGit/tools/trip-ai-tools/prompt/"),
    vim.fn.expand("$HOME/AgodaGit/tools/trip-ai-tools/instruction/"),
    -- per-dir override: match any markdown in these folders
    { dir = vim.fn.expand("$HOME/dotfiles/claude/commands/"), patterns = { "*.md" } },
    { dir = vim.fn.expand("$HOME/dotfiles/claude/agents/"), patterns = { "*.md" } },
  },
  patterns = { "*.prompt.md", "*.instructions.md" },
  timeout_ms = 60000,
}


-- Read file content and return as string
---@param path string File path to read
---@return string Content of the file
local function readfile(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines then
    return ""
  end
  return table.concat(lines, "\n")
end

-- Strip YAML frontmatter from content
---@param s string Content with potential frontmatter
---@return string Content without frontmatter
local function strip_frontmatter(s)
  if not s then return "" end
  -- If starts with YAML frontmatter '---', remove until the closing '---'
  if s:match("^%s*%-%-%-") then
    local s_idx, e_idx = s:find("%-%-%-", 1)
    if e_idx then
      local s2, e2 = s:find("%-%-%-", e_idx + 1)
      if e2 then
        return s:sub(e2 + 1):gsub("^%s+", "")
      end
    end
  end
  return s
end

-- Get list of prompt files from configured directories or explicit files
---@param opts? table Optional config override { prompt_dir, prompt_dirs, patterns }
---@return table List of prompt file paths
function M.get_prompt_files(opts)
  opts = opts or {}

  -- Resolve directories / paths list with precedence:
  -- opts.prompt_dirs -> opts.prompt_dir -> M.config.prompt_dirs -> M.config.prompt_dir
  local dirs = nil
  if opts.prompt_dirs then
    dirs = opts.prompt_dirs
  elseif opts.prompt_dir then
    dirs = { opts.prompt_dir }
  elseif M.config and M.config.prompt_dirs then
    dirs = M.config.prompt_dirs
  elseif M.config and M.config.prompt_dir then
    dirs = { M.config.prompt_dir }
  else
    dirs = {}
  end

  -- global patterns default (can be overridden per-entry)
  local patterns_global = opts.patterns or (M.config and M.config.patterns) or { "*" }
  local files = {}

  for _, entry in ipairs(dirs) do
    if not entry or entry == "" then goto continue end

    -- Support table entries with per-directory patterns:
    -- { dir = "/path/to/dir", patterns = { "*.md" } }
    -- Also allow { path = "..." } or { "/path/to/dir" }
    local path = nil
    local entry_patterns = nil
    if type(entry) == "table" then
      path = entry.dir or entry.path or entry[1]
      entry_patterns = entry.patterns
    else
      path = entry
    end

    if not path or path == "" then goto continue end

    local patterns = entry_patterns or patterns_global

    -- Debug: print path and patterns
    print(string.format("[DEBUG] Processing path: %s", vim.inspect(path)))
    print(string.format("[DEBUG] Patterns: %s", vim.inspect(patterns)))
    print(string.format("[DEBUG] isdirectory result: %s", vim.inspect(vim.fn.isdirectory(path))))

    -- If path is a directory, use globpath to find pattern matches
    if vim.fn.isdirectory(path) == 1 then
      print(string.format("[DEBUG] Path is directory, globbing..."))
      for _, pat in ipairs(patterns) do
        local ok = vim.fn.globpath(path, pat, false, true)
        print(string.format("[DEBUG] Pattern '%s' found %d files", pat, (ok and type(ok) == "table") and #ok or 0))
        if ok and type(ok) == "table" and #ok > 0 then
          print(string.format("[DEBUG] Adding files: %s", vim.inspect(ok)))
          vim.list_extend(files, ok)
        end
      end
      goto continue
    end

    -- If path is a file and readable, include it if it matches one of the patterns
    if vim.fn.filereadable(path) == 1 then
      local basename = vim.fn.fnamemodify(path, ":t")
      for _, pat in ipairs(patterns) do
        -- Use globmatch for pattern matching against the basename
        if vim.fn.globmatch(basename, pat) == 1 then
          table.insert(files, path)
          break
        end
      end
      goto continue
    end

    ::continue::
  end

  print(string.format("[DEBUG] Total files found: %d", #files))
  print(string.format("[DEBUG] Files: %s", vim.inspect(files)))
  return files
end


-- Select a prompt using Snacks picker and call callback with content
---@param opts? table Optional config { prompt_dirs, prompt_dir, patterns, timeout_ms, callback }
---@param callback? function Function to call with selected content
function M.select_prompt(opts, callback)
  opts = opts or {}
  local files = M.get_prompt_files(opts)

  if vim.tbl_isempty(files) then
    local msg = "No prompt files found in configured prompt_dirs"
    if opts.prompt_dir then
      msg = msg .. ": " .. opts.prompt_dir
    elseif M.config.prompt_dir then
      msg = msg .. ": " .. M.config.prompt_dir
    end
    vim.notify(msg, vim.log.levels.WARN)
    if callback then callback(nil) end
    return
  end

    local items = {}
    for _, f in ipairs(files) do
      local basename = vim.fn.fnamemodify(f, ":t")
      local dir = vim.fn.fnamemodify(f, ":h")
      local parts = {}
      for part in dir:gmatch("[^/]+") do table.insert(parts, part) end
      local last_two = ""
      if #parts >= 2 then
        last_two = parts[#parts-1] .. "/" .. parts[#parts]
      elseif #parts == 1 then
        last_two = parts[1]
      else
        last_two = dir
      end
      -- store basename and parent; formatting will render parent separately
      table.insert(items, { text = basename, name = basename, parent = last_two, file = f })
    end

    -- sort by parent directory then name
    table.sort(items, function(a, b)
      if a.parent == b.parent then
        return (a.name or "") < (b.name or "")
      end
      return (a.parent or "") < (b.parent or "")
    end)


  -- Use Snacks picker with a larger preview and custom preview renderer (if available)
  local function launch_snacks()
    Snacks.picker.pick {
      source = "select",
      supports_live = true,
      title = "Select Prompt File (c-y copy)",
      items = items,
      format = function(item, picker)
        -- Use the pre-computed parent directory (last 2 parts)
        local parent = item.parent or ""
        return {
          { parent .. " ", "Comment" },
          { item.text or "", "SnacksPickerTitle" },
        }
      end,


      layout = {
        preset = "default",
        -- preset = "vscode",
        hidden = false,
        layout = {
          backdrop = false,
          height = 0.9,
        },
      },
      preview_custom_donotremove = function(ctx)
        local item = ctx and ctx.item
        if not item or not item.file then return nil end

        local file = vim.fn.expand(item.file)
        local basename = vim.fn.fnamemodify(file, ":t")
        local dir = vim.fn.fnamemodify(file, ":h")

        -- compute last two path components
        local parts = {}
        for part in dir:gmatch("[^/]+") do table.insert(parts, part) end
        local last_two = ""
        if #parts >= 2 then
          last_two = parts[#parts-1] .. "/" .. parts[#parts]
        elseif #parts == 1 then
          last_two = parts[1]
        else
          last_two = dir
        end

        local ok, lines = pcall(vim.fn.readfile, file)
        if not ok or not lines then lines = { "" } end

        local header = basename .. "  (" .. last_two .. ")"
        local preview_lines = {}
        table.insert(preview_lines, header)
        table.insert(preview_lines, string.rep("-", math.max(10, #header)))
        for _, l in ipairs(lines) do table.insert(preview_lines, l) end

        if ctx and ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) then
          pcall(vim.api.nvim_buf_set_option, ctx.buf, "modifiable", true)
          vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, preview_lines)
          -- dim the last_two portion using Comment highlight
          local patt = "%(" .. vim.pesc(last_two) .. "%)"
          local s, e = header:find(patt)
          if s and e then
            pcall(vim.api.nvim_buf_add_highlight, ctx.buf, preview_ns, "Comment", 0, s-1, e)
          end
          -- set filetype for syntax highlighting in preview (use buffer API)
          pcall(function()
            local ft = vim.fn.fnamemodify(file, ":e")
            if ft and ft ~= "" then pcall(vim.api.nvim_buf_set_option, ctx.buf, "filetype", ft) end
          end)

          pcall(vim.api.nvim_buf_set_option, ctx.buf, "modifiable", false)
          return true
        end

        return { text = table.concat(preview_lines, "\n"), ft = vim.fn.fnamemodify(file, ":e") }
      end,
      -- mappings: ctrl-v opens vsplit, s opens horizontal split
      win = {
        list = {
          keys = {}
        },
        input = {
          keys = {
            ["<C-y>"] = { 'copy_content', mode = { 'n', 'i' }, desc = "Copy Prompt Content" },
            ["<CR>"] = { 'paste_content', mode = { 'n', 'i' }, desc = "Paste Prompt Content" },
          },
        },
      },
      actions = {
        -- confirm = function(picker, item)
        -- __AUTO_GENERATED_PRINT_VAR_START__
        copy_content = function(picker, item)
          -- Copy the selected prompt (without frontmatter) to system clipboard and unnamed register
          if not item or not item.file then
            picker:close()
            Snacks.notify.warn("No prompt selected to copy")
            return
          end
          local c = readfile(item.file)
          c = strip_frontmatter(c)
          -- Safely set system and primary clipboard registers
          pcall(function()
            vim.fn.setreg('+', c)
            vim.fn.setreg('*', c)
            -- also set unnamed register for immediate pasting
            vim.fn.setreg('"', c)
            Snacks.notify.warn("Successfully copied prompt to clipboard from" .. item.file)
          end)

          picker:close()
          vim.notify("Prompt copied to clipboard", vim.log.levels.INFO)
        end,
        paste_content = function(picker, item)
          if not item or not item.file then
            picker:close()
            if callback then callback(nil) end
            return
          end
          local c = readfile(item.file)
          c = strip_frontmatter(c)
          picker:close()
          if callback then callback(c) end
        end,
      },
    }
  end

  -- If Snacks picker is available use it, otherwise fall back to vim.ui.select
  if type(Snacks) == "table" and Snacks.picker and type(Snacks.picker.pick) == "function" then
    launch_snacks()
  else
    -- fallback: use vim.ui.select (no preview)
    local ui_items = {}
    for _, it in ipairs(items) do
      table.insert(ui_items, it)
    end
    local ui_opts = {
      prompt = "Select Prompt File",
      format_item = function(it)
        local full = vim.fn.fnamemodify(it.file or "", ":p")
        return (it.text or "") .. "  " .. (full or "")
      end,
    }

    vim.ui.select(ui_items, ui_opts, function(choice)
      if not choice or not choice.file then
        if callback then callback(nil) end
        return
      end
      local c = readfile(choice.file)
      c = strip_frontmatter(c)
      if callback then callback(c) end
    end)
  end

end

-- Select and paste prompt at cursor position
---@param opts? table Optional config { prompt_dirs, prompt_dir, patterns, paste_mode }
function M.select_and_paste_prompt(opts)
  opts = opts or {}

  M.select_prompt(opts, function(content)
    if not content or content == "" then
      return
    end
    local content = vim.split(content, "\n")
    -- if content line is more than 10 then set mark
    if #content > 10 then
      vim.api.nvim_command("normal! m'")
    end
    vim.api.nvim_put(content, 'c', true, true)
  end)
end

return M

-- looks good but help improve this
-- 1. the item list format still not show last 2 part of the parent dir 
-- 2. preview height should be longer

