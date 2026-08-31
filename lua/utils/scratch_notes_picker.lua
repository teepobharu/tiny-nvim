local M = {}

local uv = vim.uv or vim.loop

M.source_order = { "daily-work", "daily-personal", "raw-notes", "scratch-files", "all" }
M.daily_sources = { "daily-work", "daily-personal", "raw-notes" }

local source_labels = {
  ["daily-work"] = "work",
  ["daily-personal"] = "personal",
  ["raw-notes"] = "raw",
  ["scratch-files"] = "scratch",
  all = "all",
}

local source_aliases = {
  work = "daily-work",
  ["daily-work"] = "daily-work",
  personal = "daily-personal",
  ["daily-personal"] = "daily-personal",
  raw = "raw-notes",
  ["raw-note"] = "raw-notes",
  ["raw-notes"] = "raw-notes",
  scratch = "scratch-files",
  ["scratch-files"] = "scratch-files",
  all = "all",
}

local function joinpath(...)
  return vim.fs.normalize(vim.fs.joinpath(...))
end

local function nonblank_path(value)
  if type(value) ~= "string" or value:match "^%s*$" then
    return nil
  end
  return value
end

local function first_path(...)
  for index = 1, select("#", ...) do
    local value = nonblank_path(select(index, ...))
    if value then
      return value
    end
  end
  return nil
end

local function env_value(opts, name)
  if opts.env and opts.env[name] ~= nil then
    return nonblank_path(opts.env[name])
  end
  return nonblank_path(vim.env[name])
end

local function resolve_date(opts)
  local ymd = opts.date_ymd or env_value(opts, "SCRATCH_FZF_DATE")
  if type(ymd) ~= "string" or not ymd:match "^%d%d%d%d%d%d%d%d$" then
    ymd = os.date "%Y%m%d"
  end
  return ymd, string.format("%s-%s-%s", ymd:sub(1, 4), ymd:sub(5, 6), ymd:sub(7, 8))
end

local function expand_path(path)
  return vim.fs.normalize(vim.fn.expand(path))
end

local function accepts_markdown(name)
  return name:sub(-3):lower() == ".md"
end

--- Normalize a source name using the same aliases as scratch.fzf.
---@param source? string
---@return string
function M.normalize_source(source)
  return source_aliases[source or "all"] or "all"
end

--- Return the next source in the visible picker cycle.
---@param source? string
---@return string
function M.next_source(source)
  source = M.normalize_source(source)
  for index, key in ipairs(M.source_order) do
    if key == source then
      return M.source_order[(index % #M.source_order) + 1]
    end
  end
  return "daily-work"
end

--- Resolve source roots and today's note paths.
---@param opts? table
---@return table<string, table>
function M.resolve_sources(opts)
  opts = opts or {}
  local home = expand_path(first_path(opts.home, env_value(opts, "HOME"), "~"))
  local dotfiles = expand_path(
    first_path(opts.dotfiles_dir, env_value(opts, "DOTFILES_DIR"), joinpath(home, "dotfiles"))
  )
  local roots = opts.roots or {}
  local ymd, iso = resolve_date(opts)

  local daily_work_root = expand_path(
    first_path(
      roots["daily-work"],
      env_value(opts, "SCRATCH_FZF_DAILY_WORK_ROOT"),
      joinpath(home, "Documents", "daily")
    )
  )
  local daily_personal_root = expand_path(
    first_path(
      roots["daily-personal"],
      env_value(opts, "SCRATCH_FZF_DAILY_PERSONAL_ROOT"),
      joinpath(home, "Personal", "mynotes", "Daily")
    )
  )
  local raw_notes_root = expand_path(
    first_path(
      roots["raw-notes"],
      env_value(opts, "SCRATCH_FZF_RAW_NOTES_ROOT"),
      joinpath(dotfiles, "ai", "agents", "raw", "notes")
    )
  )
  local scratch_root = expand_path(
    first_path(
      roots["scratch-files"],
      env_value(opts, "SCRATCH_FZF_SCRATCH_ROOT"),
      joinpath(dotfiles, ".config", "myscripts", "scratch")
    )
  )

  return {
    ["daily-work"] = {
      key = "daily-work",
      label = source_labels["daily-work"],
      root = daily_work_root,
      max_depth = 2,
      accept = accepts_markdown,
      today = joinpath(daily_work_root, ymd, "user.md"),
      glob = "*.md",
    },
    ["daily-personal"] = {
      key = "daily-personal",
      label = source_labels["daily-personal"],
      root = daily_personal_root,
      max_depth = 1,
      accept = accepts_markdown,
      today = joinpath(daily_personal_root, iso .. ".md"),
      glob = "*.md",
    },
    ["raw-notes"] = {
      key = "raw-notes",
      label = source_labels["raw-notes"],
      root = raw_notes_root,
      max_depth = 1,
      accept = accepts_markdown,
      today = joinpath(raw_notes_root, ymd .. "_raw.md"),
      glob = "*.md",
    },
    ["scratch-files"] = {
      key = "scratch-files",
      label = source_labels["scratch-files"],
      root = scratch_root,
      max_depth = 2,
      accept = function()
        return true
      end,
    },
  }
end

local function scan_source(source)
  local files = {}

  local function walk(dir, depth)
    local handle = uv.fs_scandir(dir)
    if not handle then
      return
    end

    while true do
      local name, kind = uv.fs_scandir_next(handle)
      if not name then
        break
      end

      local path = joinpath(dir, name)
      local child_depth = depth + 1
      if kind == "directory" and child_depth < source.max_depth then
        walk(path, child_depth)
      elseif kind == "file" and child_depth <= source.max_depth and source.accept(name) then
        files[#files + 1] = path
      end
    end
  end

  if uv.fs_stat(source.root) then
    walk(source.root, 0)
  end
  return files
end

local function relative_path(root, path)
  local rel = vim.fs.relpath(root, path)
  return rel or path
end

local function item_for_path(source, path, is_today)
  local stat = uv.fs_stat(path)
  local missing = stat == nil
  local display = vim.fn.fnamemodify(path, ":~")
  local kind = missing and "new" or vim.fn.fnamemodify(path, ":e")
  if kind == "" then
    kind = "file"
  end

  return {
    text = table.concat({ display, source.key, source.label, kind }, " "),
    file = path,
    display = display,
    relative = relative_path(source.root, path),
    scratch_source = source.key,
    source_label = source.label,
    source_order = vim.fn.index(M.source_order, source.key) + 1,
    is_today = is_today == true,
    missing = missing,
    mtime = stat and stat.mtime and stat.mtime.sec or 0,
    size = stat and stat.size or 0,
    empty = not missing and stat.size == 0,
    kind = kind,
  }
end

---Return injected or runtime-native Snacks scratch entries.
---@param opts? table
---@return table[]
local function native_scratch_entries(opts)
  if type(opts and opts.scratch_items) == "table" then
    return opts.scratch_items
  end

  local snacks = rawget(_G, "Snacks")
  local scratch = snacks and snacks.scratch
  if not scratch or type(scratch.list) ~= "function" then
    return {}
  end

  local ok, items = pcall(scratch.list)
  return ok and type(items) == "table" and items or {}
end

---Map a native Snacks scratch entry into the shared multi-source item shape.
---@param source table
---@param scratch table
---@return table|nil
local function item_for_native_scratch(source, scratch)
  local path = scratch and scratch.file
  if type(path) ~= "string" or path == "" then
    return nil
  end

  local stat = scratch.stat or uv.fs_stat(path)
  local missing = stat == nil
  local ft = scratch.ft or vim.fn.fnamemodify(path, ":e")
  if ft == "" then
    ft = "file"
  end
  local display = scratch.name or vim.fn.fnamemodify(path, ":~")
  local text = { display, source.key, source.label, ft }
  if scratch.branch and scratch.branch ~= "" then
    text[#text + 1] = scratch.branch
  end
  if scratch.cwd and scratch.cwd ~= "" then
    text[#text + 1] = scratch.cwd
  end

  return {
    text = table.concat(text, " "),
    file = path,
    display = display,
    relative = relative_path(source.root, path),
    scratch_source = source.key,
    source_label = source.label,
    source_order = vim.fn.index(M.source_order, source.key) + 1,
    is_today = false,
    missing = missing,
    mtime = stat and stat.mtime and stat.mtime.sec or 0,
    size = stat and stat.size or 0,
    empty = not missing and stat.size == 0,
    kind = ft,
    scratch_native = true,
    scratch_ft = ft,
    scratch_branch = scratch.branch,
    scratch_cwd = scratch.cwd,
  }
end

local function collect_one(source)
  local items = {}
  local seen = {}

  local function add(path, is_today)
    if seen[path] then
      return
    end
    seen[path] = true
    items[#items + 1] = item_for_path(source, path, is_today)
  end

  if source.today then
    add(source.today, true)
  end
  for _, path in ipairs(scan_source(source)) do
    add(path, source.today == path)
  end
  return items
end

local function sort_items(items)
  table.sort(items, function(a, b)
    local a_rank = a.is_today and 0 or 1
    local b_rank = b.is_today and 0 or 1
    if a_rank ~= b_rank then
      return a_rank < b_rank
    end
    if a.source_order ~= b.source_order then
      return a.source_order < b.source_order
    end
    if a.mtime ~= b.mtime then
      return a.mtime > b.mtime
    end
    return a.file < b.file
  end)
  return items
end

--- Collect picker items for one source or the aggregate `all` source.
--- Missing source directories are valid and simply return no scanned files;
--- daily sources still expose today's creatable target.
---@param source? string
---@param opts? table
---@return table[]
function M.collect(source, opts)
  opts = opts or {}
  source = M.normalize_source(source)
  local sources = M.resolve_sources(opts)
  local items = {}
  local seen = {}
  local show_empty_scratch = opts.show_empty_scratch ~= false

  local function add(item)
    if not item or seen[item.file] then
      return
    end
    if item.scratch_source == "scratch-files" and item.empty and not show_empty_scratch then
      return
    end
    seen[item.file] = true
    items[#items + 1] = item
  end

  local keys = source == "all" and { "daily-work", "daily-personal", "raw-notes", "scratch-files" } or { source }
  for _, key in ipairs(keys) do
    if key == "scratch-files" then
      for _, scratch in ipairs(native_scratch_entries(opts)) do
        add(item_for_native_scratch(sources[key], scratch))
      end
    end
    for _, item in ipairs(collect_one(sources[key])) do
      add(item)
    end
  end

  return sort_items(items)
end

--- Return roots passed to Snacks grep. Keep missing roots in the list so grep
--- never falls back to searching the current working directory.
---@param source? string
---@param opts? table
---@return string[]
function M.grep_dirs(source, opts)
  opts = opts or {}
  source = M.normalize_source(source)
  local sources = M.resolve_sources(opts)
  local dirs = {}
  local seen = {}
  local function add_dir(dir)
    if dir and dir ~= "" and not seen[dir] then
      seen[dir] = true
      dirs[#dirs + 1] = dir
    end
  end

  local keys = source == "all" and { "daily-work", "daily-personal", "raw-notes", "scratch-files" } or { source }
  for _, key in ipairs(keys) do
    add_dir(sources[key].root)
    if key == "scratch-files" then
      for _, scratch in ipairs(native_scratch_entries(opts)) do
        add_dir(type(scratch.file) == "string" and vim.fs.dirname(scratch.file) or nil)
      end
    end
  end
  return dirs
end

---@param source? string
---@param opts? table
---@return string|nil
function M.grep_glob(source, opts)
  source = M.normalize_source(source)
  if source == "all" then
    return nil
  end
  return M.resolve_sources(opts)[source].glob
end

--- Create today's note for a daily source, mirroring scratch.fzf's mkdir+touch behavior.
---@param source string
---@param opts? table
---@return string|nil path
---@return boolean|string created_or_error
function M.create_today(source, opts)
  source = M.normalize_source(source)
  local config = M.resolve_sources(opts)[source]
  if not config or not config.today then
    return nil, ("Source %s has no daily note target"):format(source)
  end

  if uv.fs_stat(config.today) then
    return config.today, false
  end

  local parent = vim.fs.dirname(config.today)
  vim.fn.mkdir(parent, "p")
  local fd, err = uv.fs_open(config.today, "a", 420)
  if not fd then
    return nil, err or ("Unable to create %s"):format(config.today)
  end
  uv.fs_close(fd)
  return config.today, true
end

local function title(source, mode)
  return ("Scratch Notes [%s] · %s"):format(source_labels[M.normalize_source(source)], mode)
end

local function picker_query(picker, mode)
  local filter = picker.input and picker.input.filter
  if not filter then
    return ""
  end
  return mode == "grep" and (filter.search or "") or (filter.pattern or "")
end

local function open_path(path)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

local function create_and_open(source, runtime)
  local path, created_or_error = M.create_today(source, runtime)
  if not path then
    vim.notify(tostring(created_or_error), vim.log.levels.ERROR)
    return
  end
  if created_or_error == true then
    vim.notify("Created daily note: " .. vim.fn.fnamemodify(path, ":~"), vim.log.levels.INFO)
  end
  open_path(path)
end

local function choose_daily_source(active_source, callback)
  active_source = M.normalize_source(active_source)
  if vim.tbl_contains(M.daily_sources, active_source) then
    callback(active_source)
    return
  end
  vim.ui.select(M.daily_sources, {
    prompt = "Create today's note for:",
    format_item = function(source)
      return source_labels[source]
    end,
  }, callback)
end

local open_files
local open_grep

local function switch_mode(picker, runtime, from_mode)
  local source = picker.opts.scratch_source or "all"
  local query = picker_query(picker, from_mode)
  local show_empty_scratch = picker.opts.scratch_show_empty == true
  picker:close()
  vim.schedule(function()
    if from_mode == "grep" then
      open_files(runtime, source, query, show_empty_scratch)
    else
      open_grep(runtime, source, query, show_empty_scratch)
    end
  end)
end

local function cycle_source(picker, runtime, mode)
  local next_source = M.next_source(picker.opts.scratch_source)
  picker.opts.scratch_source = next_source
  picker.title = title(next_source, mode)
  if mode == "grep" then
    picker.opts.dirs = M.grep_dirs(next_source, runtime)
    picker.opts.glob = M.grep_glob(next_source, runtime)
  end
  picker:refresh()
  vim.notify("Scratch source: " .. next_source, vim.log.levels.INFO)
end

local function create_today_action(picker, runtime)
  local active_source = picker.opts.scratch_source or "all"
  picker:close()
  vim.schedule(function()
    choose_daily_source(active_source, function(source)
      if source then
        create_and_open(source, runtime)
      end
    end)
  end)
end

local function footer(mode, show_empty_scratch)
  local mode_label = mode == "grep" and "files" or "grep"
  local empty_label = mode == "files" and (show_empty_scratch and " • A-e: empty on" or " • A-e: empty off") or ""
  return ("A-s: source • A-g: %s%s • C-n: today • Enter: open/create"):format(mode_label, empty_label)
end

local function toggle_empty_scratch_files(picker)
  picker.opts.scratch_show_empty = not picker.opts.scratch_show_empty
  if picker.opts.win and picker.opts.win.input then
    picker.opts.win.input.footer = footer("files", picker.opts.scratch_show_empty)
  end
  picker:refresh()
  vim.notify(
    "Empty scratch files: " .. (picker.opts.scratch_show_empty and "shown" or "hidden"),
    vim.log.levels.INFO
  )
end

local function actions(runtime, mode)
  return {
    scratch_cycle_source = function(picker)
      cycle_source(picker, runtime, mode)
    end,
    scratch_switch_mode = function(picker)
      switch_mode(picker, runtime, mode)
    end,
    scratch_create_today = function(picker)
      create_today_action(picker, runtime)
    end,
    scratch_toggle_empty = function(picker)
      toggle_empty_scratch_files(picker)
    end,
  }
end

local function keys(mode)
  local result = {
    ["<M-s>"] = { "scratch_cycle_source", mode = { "n", "i" }, desc = "Cycle scratch source" },
    ["<M-g>"] = { "scratch_switch_mode", mode = { "n", "i" }, desc = "Toggle scratch grep" },
    ["<C-n>"] = { "scratch_create_today", mode = { "n", "i" }, desc = "Create today's note" },
  }
  if mode == "files" then
    result["<M-e>"] = { "scratch_toggle_empty", mode = { "n", "i" }, desc = "Toggle empty scratch files" }
  end
  return result
end

---Return compact metadata labels for a multi-source scratch item.
---@param item table
---@return string
function M.format_label(item)
  local labels = { "[" .. item.source_label .. "]" }
  local state = item.missing and "new" or (item.is_today and "today" or "")
  if state ~= "" then
    labels[#labels + 1] = "[" .. state .. "]"
  end
  if item.scratch_native then
    labels[#labels + 1] = "[" .. item.scratch_ft .. "]"
    if item.scratch_branch and item.scratch_branch ~= "" then
      labels[#labels + 1] = "[" .. item.scratch_branch .. "]"
    end
    if item.scratch_cwd and item.scratch_cwd ~= "" then
      labels[#labels + 1] = "[cwd:" .. vim.fn.fnamemodify(item.scratch_cwd, ":~") .. "]"
    end
  end
  return table.concat(labels, " ")
end

local function format_item(item)
  return {
    { M.format_label(item), "SnacksPickerLabel" },
    { " " },
    { item.display, item.missing and "Comment" or "SnacksPickerFile" },
  }
end

local function preview_item(ctx)
  if not ctx.item.missing then
    return Snacks.picker.preview.file(ctx)
  end
  ctx.preview:reset()
  ctx.preview:set_title "New daily note"
  ctx.preview:set_lines({
    "This note does not exist yet.",
    "",
    "Path: " .. ctx.item.display,
    "Source: " .. ctx.item.scratch_source,
    "",
    "Press Enter to create and edit it.",
    "Press <C-n> to choose a daily source explicitly.",
  })
  return true
end

open_files = function(runtime, source, pattern, show_empty_scratch)
  source = M.normalize_source(source)
  return Snacks.picker.pick {
    source = "scratch_multi",
    title = title(source, "files"),
    scratch_source = source,
    scratch_show_empty = show_empty_scratch == true,
    pattern = pattern ~= "" and pattern or nil,
    show_empty = true,
    matcher = { sort_empty = false },
    finder = function(opts)
      local collect_opts = vim.deepcopy(runtime)
      collect_opts.show_empty_scratch = opts.scratch_show_empty
      return M.collect(opts.scratch_source, collect_opts)
    end,
    format = format_item,
    preview = preview_item,
    confirm = function(picker, item)
      if not item then
        return
      end
      picker:close()
      vim.schedule(function()
        if item.missing then
          create_and_open(item.scratch_source, runtime)
        else
          open_path(item.file)
        end
      end)
    end,
    actions = actions(runtime, "files"),
    win = {
      input = {
        footer = footer("files", show_empty_scratch == true),
        keys = keys "files",
      },
    },
  }
end

open_grep = function(runtime, source, search, show_empty_scratch)
  source = M.normalize_source(source)
  return Snacks.picker.grep {
    title = title(source, "grep"),
    scratch_source = source,
    scratch_show_empty = show_empty_scratch == true,
    dirs = M.grep_dirs(source, runtime),
    glob = M.grep_glob(source, runtime),
    search = search ~= "" and search or nil,
    hidden = true,
    ignored = true,
    show_empty = true,
    actions = actions(runtime, "grep"),
    win = {
      input = {
        footer = footer "grep",
        keys = keys "grep",
      },
    },
  }
end

--- Open the multi-source scratch picker.
---@param opts? {source?: string, mode?: "files"|"grep", query?: string, roots?: table, date_ymd?: string}
---@return snacks.Picker?
function M.open(opts)
  opts = vim.deepcopy(opts or {})
  local source = M.normalize_source(opts.source or "all")
  local mode = opts.mode == "grep" and "grep" or "files"
  local query = opts.query or ""
  local show_empty_scratch = opts.show_empty_scratch == true
  opts.source, opts.mode, opts.query, opts.show_empty_scratch = nil, nil, nil, nil
  if mode == "grep" then
    return open_grep(opts, source, query, show_empty_scratch)
  end
  return open_files(opts, source, query, show_empty_scratch)
end

return M
