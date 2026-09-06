local M = {}

local uv = vim.uv or vim.loop

local instruction_names = {
  [".cursorrules"] = "rule",
  ["agents.md"] = "instruction",
  ["agents.override.md"] = "instruction",
  ["claude.local.md"] = "instruction",
  ["claude.md"] = "instruction",
  ["copilot-instructions.md"] = "instruction",
  ["crush.local.md"] = "instruction",
  ["crush.md"] = "instruction",
  ["gemini.md"] = "instruction",
}

local skipped_directories = {
  [".cache"] = true,
  [".git"] = true,
  [".idea"] = true,
  [".next"] = true,
  [".venv"] = true,
  ["build"] = true,
  ["dist"] = true,
  ["node_modules"] = true,
  ["target"] = true,
  ["vendor"] = true,
  ["venv"] = true,
}

local function normalize(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  return vim.fs.normalize(vim.fn.expand(path))
end

local function path_contains(path, segment)
  return ("/" .. path:lower():gsub("\\", "/") .. "/"):find("/" .. segment .. "/", 1, true) ~= nil
end

local function starts_with_path(path, root)
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

local function infer_agent(path, basename)
  local lower = path:lower():gsub("\\", "/")
  if lower:find("/.claude/", 1, true) or basename:find("claude", 1, true) then
    return "claude"
  elseif lower:find("/.codex/", 1, true) then
    return "codex"
  elseif lower:find("/.cursor/", 1, true) or basename == ".cursorrules" then
    return "cursor"
  elseif lower:find("/.config/opencode/", 1, true) then
    return "opencode"
  elseif lower:find("/.pi/", 1, true) then
    return "pi"
  elseif lower:find("/.github/", 1, true) and basename == "copilot-instructions.md" then
    return "copilot"
  elseif basename:find("gemini", 1, true) then
    return "gemini"
  elseif basename:find("crush", 1, true) then
    return "crush"
  end
  return "all"
end

---Classify a discovered markdown file. Returns nil for unrelated files.
---@param path string
---@param scope? string
---@param root? string
---@param source? table
---@return table|nil
function M.classify_path(path, scope, root, source)
  source = source or {}
  path = normalize(path)
  if not path then
    return nil
  end

  local basename = vim.fs.basename(path):lower()
  local extension = basename:match "%.([^.]+)$"
  local category = source.category or instruction_names[basename]

  if source.category == "skill" then
    if basename ~= "skill.md" then
      return nil
    end
  elseif source.category == "rule" then
    if extension ~= "md" and extension ~= "mdc" and basename ~= ".cursorrules" then
      return nil
    end
  elseif source.category == "instruction" then
    if extension ~= "md" and extension ~= "mdc" and basename ~= ".cursorrules" then
      return nil
    end
  elseif not category then
    if basename == "skill.md" and path_contains(path, "skills") then
      category = "skill"
    elseif path_contains(path, "rules") and (extension == "md" or extension == "mdc") then
      category = "rule"
    elseif source.explicit and (extension == "md" or extension == "mdc") then
      category = "instruction"
    else
      return nil
    end
  end

  return {
    agent = source.agent or infer_agent(path, basename),
    category = category,
    label = source.label,
    root = root,
    scope = source.scope or scope or "project",
  }
end

---Default global instruction sources. Extra sources can be supplied through
---`vim.g.instruction_picker_sources` or `discover({ extra_sources = ... })`.
---@param opts? table
---@return table
function M.default_sources(opts)
  opts = opts or {}
  local home = normalize(opts.home or vim.env.HOME)
  if not home then
    return {}
  end

  local function home_path(...)
    return vim.fs.joinpath(home, ...)
  end

  return {
    {
      path = home_path(".agents", "AGENTS.md"),
      label = "Shared agent instructions",
      agent = "all",
      scope = "global",
      category = "instruction",
    },
    {
      path = home_path("dotfiles", "ai", "agents", "AGENTS.md"),
      label = "Shared agent instructions",
      agent = "all",
      scope = "global",
      category = "instruction",
    },
    {
      path = home_path(".codex", "AGENTS.override.md"),
      label = "Codex override",
      agent = "codex",
      scope = "global",
      category = "instruction",
    },
    {
      path = home_path(".codex", "AGENTS.md"),
      label = "Codex instructions",
      agent = "codex",
      scope = "global",
      category = "instruction",
    },
    {
      path = home_path(".claude", "CLAUDE.md"),
      label = "Claude instructions",
      agent = "claude",
      scope = "global",
      category = "instruction",
    },
    {
      path = home_path(".config", "opencode", "AGENTS.md"),
      label = "OpenCode instructions",
      agent = "opencode",
      scope = "global",
      category = "instruction",
    },
    {
      path = home_path(".pi", "agent", "AGENTS.md"),
      label = "Pi instructions",
      agent = "pi",
      scope = "global",
      category = "instruction",
    },
    {
      path = home_path(".agents", "skills"),
      label = "Shared skills",
      agent = "all",
      scope = "global",
      category = "skill",
    },
    {
      path = home_path(".codex", "skills"),
      label = "Codex skills",
      agent = "codex",
      scope = "global",
      category = "skill",
    },
    {
      path = home_path(".claude", "rules"),
      label = "Claude rules",
      agent = "claude",
      scope = "global",
      category = "rule",
    },
    {
      path = home_path(".cursor", "rules"),
      label = "Cursor rules",
      agent = "cursor",
      scope = "global",
      category = "rule",
    },
    {
      path = home_path(".config", "opencode", "rules"),
      label = "OpenCode rules",
      agent = "opencode",
      scope = "global",
      category = "rule",
    },
  }
end

local function read_lines(path, max_file_bytes)
  local stat = uv.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return nil, "not a readable file"
  end
  if stat.size > max_file_bytes then
    return nil, ("file exceeds %d byte limit"):format(max_file_bytes)
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or type(lines) ~= "table" then
    return nil, "read failed"
  end
  return lines
end

local function summarize(lines)
  local first_text
  local description
  for _, line in ipairs(lines) do
    local heading = line:match "^%s*#+%s*(.-)%s*$"
    if heading and heading ~= "" then
      return heading
    end
    local yaml_description = line:match "^%s*description:%s*(.-)%s*$"
    if yaml_description and yaml_description ~= "" then
      description = yaml_description:gsub('^["\']', ""):gsub('["\']$', "")
    end
    local trimmed = vim.trim(line)
    if not first_text and trimmed ~= "" and trimmed ~= "---" then
      first_text = trimmed
    end
  end
  return description or first_text or ""
end

---Read a catalog file for the copy-content action.
---@param path string
---@param max_file_bytes? integer
---@return string|nil, string|nil
function M.read_content(path, max_file_bytes)
  local lines, err = read_lines(path, max_file_bytes or 2 * 1024 * 1024)
  if not lines then
    return nil, err
  end
  return table.concat(lines, "\n")
end

local function display_path(path, scope, home, project_root)
  if scope == "project" and project_root and starts_with_path(path, project_root) then
    local suffix = path:sub(#project_root + 1)
    return suffix == "" and "." or "." .. suffix
  end
  if home and starts_with_path(path, home) then
    return "~" .. path:sub(#home + 1)
  end
  return path
end

local function scan_directory(root, source, opts, report, on_file)
  local max_depth = opts.max_depth or 10
  local max_nodes = opts.max_nodes or 30000
  local visited_nodes = 0

  local function walk(directory, depth)
    if report.truncated then
      return
    end
    local handle, scan_err = uv.fs_scandir(directory)
    if not handle then
      table.insert(report.errors, { path = directory, error = scan_err or "directory scan failed" })
      return
    end

    local children = {}
    while true do
      local name, kind = uv.fs_scandir_next(handle)
      if not name then
        break
      end
      table.insert(children, { name = name, kind = kind })
    end
    table.sort(children, function(a, b)
      return a.name < b.name
    end)

    for _, child in ipairs(children) do
      visited_nodes = visited_nodes + 1
      if visited_nodes > max_nodes then
        report.truncated = true
        return
      end

      local child_path = vim.fs.joinpath(directory, child.name)
      local kind = child.kind
      if not kind then
        local stat = uv.fs_lstat(child_path)
        kind = stat and stat.type or nil
      end

      if kind == "directory" then
        if depth < max_depth and not skipped_directories[child.name] then
          walk(child_path, depth + 1)
        end
      elseif kind == "file" then
        report.scanned_files = report.scanned_files + 1
        on_file(child_path, source, root)
      end
      -- Nested symlinks are intentionally not followed: configured root symlinks
      -- work, while traversal cannot escape the configured tree or form cycles.
    end
  end

  walk(root, 0)
end

local scope_order = { global = 1, project = 2 }
local category_order = { instruction = 1, rule = 2, skill = 3 }

---Sort catalog rows deterministically.
---@param entries table
---@return table
function M.sort_entries(entries)
  table.sort(entries, function(a, b)
    local a_key = {
      scope_order[a.scope] or 99,
      a.agent or "",
      category_order[a.category] or 99,
      a.display_path or a.path or "",
    }
    local b_key = {
      scope_order[b.scope] or 99,
      b.agent or "",
      category_order[b.category] or 99,
      b.display_path or b.path or "",
    }
    for index = 1, #a_key do
      if a_key[index] ~= b_key[index] then
        return a_key[index] < b_key[index]
      end
    end
    return false
  end)
  return entries
end

local function configured_sources(opts)
  local sources = {}
  if opts.sources then
    vim.list_extend(sources, opts.sources)
  elseif opts.include_defaults ~= false then
    vim.list_extend(sources, M.default_sources(opts))
  end
  if type(vim.g.instruction_picker_sources) == "table" and opts.include_vim_sources ~= false then
    vim.list_extend(sources, vim.g.instruction_picker_sources)
  end
  if type(opts.extra_sources) == "table" then
    vim.list_extend(sources, opts.extra_sources)
  end
  return sources
end

local function resolve_project_root(opts)
  if opts.project_root ~= nil then
    return opts.project_root and normalize(opts.project_root) or nil
  end
  local cwd = normalize(opts.cwd or vim.fn.getcwd())
  if not cwd then
    return nil
  end
  return normalize(vim.fs.root(cwd, ".git") or cwd)
end

---Discover global and project instruction, rule, and skill files.
---@param opts? table
---@return table entries, table report
function M.discover(opts)
  opts = opts or {}
  local home = normalize(opts.home or vim.env.HOME)
  local project_root = resolve_project_root(opts)
  local max_file_bytes = opts.max_file_bytes or 2 * 1024 * 1024
  local report = { errors = {}, missing = {}, scanned_files = 0, truncated = false }
  local entries = {}
  local seen = {}

  local function add_file(path, source, root)
    path = normalize(path)
    if not path then
      return
    end
    local classification = M.classify_path(path, source.scope, root, source)
    if not classification then
      return
    end

    local lines, read_err = read_lines(path, max_file_bytes)
    if not lines then
      table.insert(report.errors, { path = path, error = read_err })
      return
    end

    local canonical = uv.fs_realpath(path) or path
    local dedupe_key = table.concat({ classification.agent, classification.scope, canonical }, "\0")
    if seen[dedupe_key] then
      return
    end
    seen[dedupe_key] = true

    local heading = summarize(lines)
    local shown_path = display_path(path, classification.scope, home, project_root)
    local label = classification.label or vim.fs.basename(path)
    local entry = {
      agent = classification.agent,
      category = classification.category,
      display_path = shown_path,
      file = path,
      heading = heading,
      label = label,
      line_count = #lines,
      path = path,
      scope = classification.scope,
    }
    entry.text =
      table.concat({ entry.agent, entry.scope, entry.category, entry.label, entry.display_path, heading }, " ")
    table.insert(entries, entry)
  end

  for _, original_source in ipairs(configured_sources(opts)) do
    local source = vim.tbl_extend("force", { scope = "global" }, original_source)
    local path = normalize(source.path or source.dir or source[1])
    if path then
      local stat = uv.fs_stat(path)
      if not stat then
        table.insert(report.missing, path)
      elseif stat.type == "file" then
        source.explicit = true
        report.scanned_files = report.scanned_files + 1
        add_file(path, source, path)
      elseif stat.type == "directory" then
        scan_directory(path, source, opts, report, add_file)
      else
        table.insert(report.errors, { path = path, error = "unsupported path type: " .. tostring(stat.type) })
      end
    end
  end

  if project_root then
    local stat = uv.fs_stat(project_root)
    if stat and stat.type == "directory" then
      scan_directory(project_root, { scope = "project" }, opts, report, add_file)
    else
      table.insert(report.missing, project_root)
    end
  end

  return M.sort_entries(entries), report
end

local compact_scope = { global = "g", project = "p" }
local compact_category = { instruction = "md", rule = "r", skill = "sk" }

---Return the available agent filters, starting with the unfiltered view.
---@param entries table[]
---@return string[]
function M.agent_filters(entries)
  local agents = { "all" }
  local seen = { all = true }
  for _, entry in ipairs(entries) do
    local agent = entry.agent
    if agent and not seen[agent] then
      seen[agent] = true
      agents[#agents + 1] = agent
    end
  end
  table.sort(agents, function(a, b)
    if a == "all" then
      return true
    end
    if b == "all" then
      return false
    end
    return a < b
  end)
  return agents
end

---Cycle from the active agent filter to the next available filter.
---@param entries table[]
---@param current? string
---@return string
function M.next_agent_filter(entries, current)
  local agents = M.agent_filters(entries)
  current = current or "all"
  for index, agent in ipairs(agents) do
    if agent == current then
      return agents[(index % #agents) + 1]
    end
  end
  return agents[1]
end

---Filter catalog entries by agent and/or global scope without changing their order.
---@param entries table[]
---@param agent? string
---@param global_only? boolean
---@return table[]
function M.filter_entries(entries, agent, global_only)
  agent = agent or "all"
  local filtered = {}
  for _, entry in ipairs(entries) do
    local matches_agent = agent == "all" or entry.agent == agent or entry.agent == "all"
    if matches_agent and (not global_only or entry.scope == "global") then
      filtered[#filtered + 1] = entry
    end
  end
  return filtered
end

---Build the picker title from the active filters and discovery state.
---@param entries table[]
---@param report table
---@param agent? string
---@param global_only? boolean
---@return string
function M.picker_title(entries, report, agent, global_only)
  local visible = #M.filter_entries(entries, agent, global_only)
  local title = ("Instruction Files (%d/%d)"):format(visible, #entries)
  if agent and agent ~= "all" then
    title = title .. " • " .. agent
  end
  if global_only then
    title = title .. " • global"
  end
  if #report.missing > 0 or #report.errors > 0 then
    title = title .. (" • unavailable %d"):format(#report.missing + #report.errors)
  end
  if report.truncated then
    title = title .. " • scan capped"
  end
  return title
end

local function picker_footer(agent, global_only)
  local scope = global_only and "global" or "all scopes"
  return ("Enter: open • C-y: path • C-l: content • A-s: agent %s • A-g: %s"):format(agent or "all", scope)
end

---Snacks row renderer, exported so its column contract is headless-testable.
---@param item table
---@return table
function M.format_item(item)
  return {
    { "[" .. tostring(item.agent or "all") .. "] ", "SnacksPickerLabel" },
    {
      "[" .. (compact_scope[item.scope] or item.scope or "?") .. "] ",
      item.scope == "global" and "DiagnosticInfo" or "DiagnosticOk",
    },
    { "[" .. (compact_category[item.category] or item.category or "?") .. "] ", "Special" },
    { item.display_path or item.path or "", "SnacksPickerFile" },
    { item.heading ~= "" and (" — " .. item.heading) or "", "Comment" },
  }
end

local function notify_copy(label, value)
  vim.fn.setreg("+", value)
  vim.fn.setreg('"', value)
  vim.notify(label, vim.log.levels.INFO)
end

local function selected_item(picker, item)
  return item or (picker and picker.current and picker:current()) or nil
end

---Open the standalone Snacks instruction-file catalog.
---@param opts? table
---@return any
function M.open(opts)
  opts = opts or {}
  local max_file_bytes = opts.max_file_bytes or 2 * 1024 * 1024
  local entries, report = M.discover(opts)
  if #entries == 0 then
    vim.notify("No instruction files found", vim.log.levels.WARN)
    return nil
  end
  if type(Snacks) ~= "table" or not Snacks.picker or type(Snacks.picker.pick) ~= "function" then
    vim.notify("Snacks picker is unavailable", vim.log.levels.ERROR)
    return nil
  end

  local active_agent = opts.agent or "all"
  local global_only = opts.global_only == true

  local function refresh_filters(picker)
    local agent = picker.opts.instruction_agent or "all"
    local global = picker.opts.instruction_global_only == true
    picker.title = M.picker_title(entries, report, agent, global)
    if picker.opts.win and picker.opts.win.input then
      picker.opts.win.input.footer = picker_footer(agent, global)
    end
    picker:refresh()
  end

  return Snacks.picker.pick {
    source = "instruction_files",
    title = M.picker_title(entries, report, active_agent, global_only),
    instruction_agent = active_agent,
    instruction_global_only = global_only,
    finder = function(picker_opts)
      return M.filter_entries(
        entries,
        picker_opts.instruction_agent or "all",
        picker_opts.instruction_global_only == true
      )
    end,
    supports_live = true,
    format = M.format_item,
    preview = function(ctx)
      return Snacks.picker.preview.file(ctx)
    end,
    confirm = function(picker, item)
      item = selected_item(picker, item)
      if not item then
        return
      end
      picker:close()
      vim.schedule(function()
        vim.cmd.edit(vim.fn.fnameescape(item.path))
      end)
    end,
    actions = {
      instruction_copy_path = function(picker, item)
        item = selected_item(picker, item)
        if item then
          notify_copy("Copied instruction path", item.path)
        end
      end,
      instruction_copy_content = function(picker, item)
        item = selected_item(picker, item)
        if not item then
          return
        end
        local content, err = M.read_content(item.path, max_file_bytes)
        if not content then
          vim.notify("Could not read instruction file: " .. tostring(err), vim.log.levels.ERROR)
          return
        end
        notify_copy("Copied instruction content", content)
      end,
      instruction_cycle_agent = function(picker)
        picker.opts.instruction_agent = M.next_agent_filter(entries, picker.opts.instruction_agent)
        refresh_filters(picker)
      end,
      instruction_toggle_global = function(picker)
        picker.opts.instruction_global_only = not picker.opts.instruction_global_only
        refresh_filters(picker)
      end,
    },
    layout = { preset = "default", preview = { width = 0.55 } },
    win = {
      input = {
        footer = picker_footer(active_agent, global_only),
        keys = {
          ["<C-y>"] = { "instruction_copy_path", mode = { "n", "i" }, desc = "Copy instruction path" },
          ["<C-l>"] = { "instruction_copy_content", mode = { "n", "i" }, desc = "Copy instruction content" },
          ["<M-s>"] = { "instruction_cycle_agent", mode = { "n", "i" }, desc = "Cycle instruction agent" },
          ["<M-g>"] = { "instruction_toggle_global", mode = { "n", "i" }, desc = "Toggle global instructions" },
        },
      },
    },
  }
end

return M
