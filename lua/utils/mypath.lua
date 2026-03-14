local path = require "utils.path"
local M = {}

-- Shared marker configuration for subproject detection
-- Used by both get_sub_project_dir and get_sub_project_dirs_from_root
--
-- Flags:
--   git_ignored  = true  -> file is in global/local gitignore, scanned via fd/find with timeout
--   is_directory = true  -> target is a directory, needs **/<name>/** pattern for git ls-files
--   skip_scan   = true  -> skip pipeline scan, detected via candidate_dirs (e.g. root always added)
--   match_from_within    -> only matches when current buffer is inside the marker directory

M.SUBPROJECT_MARKERS = {
  { name = ".nvim-config.lua", type = "path", project_type = ".nv", git_ignored = true },
  { name = "package.json", type = "path", project_type = "yarn" },
  { name = "pyproject.toml", type = "path", project_type = "python" },
  { name = "Cargo.toml", type = "path", project_type = "rust" },
  { name = "go.mod", type = "path", project_type = "golang" },
  { name = "pom.xml", type = "path", project_type = "maven" },
  { name = "build.gradle", type = "path", project_type = "gradle" },
  { name = "%.sln$", type = "pattern", project_type = "dotnet" },
  { name = { "Clientside", "Serverside" }, type = "path", project_type = "cronos", is_directory = true },
  -- Special marker: only matches when browsing INSIDE .gitlab directory
  -- match_from_within: the .gitlab dir itself becomes the subproject dir
  { name = ".gitlab", type = "path", project_type = ".glab", match_from_within = true, is_directory = true },
  -- .git: skip Pipeline B scan — root is always added as candidate via candidate_dirs[root_dir]
  { name = ".git", type = "path", project_type = "git", is_directory = true, skip_scan = true },
}

-- Module-level cache for get_sub_project_dirs_from_root
local _subproject_cache = {}
local _subproject_cache_generation = 0

-- Function to get the Python path.
-- @param pipenvFallback boolean: If true, falls back to pipenv --py if pyrightconfig.json is not found.
-- @param isLog boolean: If true, logs the Python path using vim.notify.
function M.get_pythonpath(pipenvFallback, isLog)
  -- check for current dir if pyyrgithconfig.json exists and get python path
  local function readpyrightconfig(filepath, pyrightConfigname)
    -- print([==[M.get_pythonpath#readpyrightconfig filepath:]==], vim.inspect(filepath)) -- __AUTO_GENERATED_PRINT_VAR_END__
    local filepathconfig = filepath .. "/" .. (pyrightConfigname or "pyrightconfig.json")
    local content = ""
    if vim.fn.filereadable(filepathconfig) == 1 then
      local config_content = vim.fn.readfile(filepathconfig)
      content = vim.fn.json_decode(table.concat(config_content, "\n"))
    end
    return content
  end
  local config = readpyrightconfig(vim.fn.getcwd())
  local root_dir = path.get_root_directory()
  config = config or readpyrightconfig(root_dir)

  if not config then
    if isLog then
      vim.notify("pyrightconfig exists but not able to read", vim.log.levels.WARN)
    end
  else
    local venvPath = config.venvPath
    if venvPath == nil or vim.fn.empty(venvPath) == 1 then
      if isLog then
        -- __AUTO_GENERATED_PRINT_VAR_START__
        print([==[M.get_pythonpath#if#if#if isLog:]==], vim.inspect(isLog)) -- __AUTO_GENERATED_PRINT_VAR_END__
        vim.notify("pyrightconfig exists but venvPath not found", vim.log.levels.WARN)
      end
    else
      local pythonExeDir = "/bin/python"
      local isVenvAbsPath = string.sub(venvPath, 1, 1) == "/"

      if isVenvAbsPath then
        -- print([==[M.get_pythonpath#if#if#if#if isVenvAbsPath:]==], vim.inspect(isVenvAbsPath)) -- __AUTO_GENERATED_PRINT_VAR_END__
        -- print([==[M.get_pythonpath#if#if#if#if venvPath .. pythonExeDir):]==], vim.inspect(venvPath .. pythonExeDir))
        -- print(
        --   [==[M.get_pythonpath#if#if#if#if#if vim.fn.filereadable(venvPath .. pythonExeDir):]==],
        if vim.fn.filereadable(venvPath .. pythonExeDir) == 1 then
          -- __AUTO_GENERATED_PRINT_VAR_START__
          if isLog then
            vim.notify("Using absolute path from pyrightconfig.json: " .. venvPath, vim.log.levels.INFO)
          end
          return venvPath .. pythonExeDir
        end
      else
        -- Check if venvPath is relative to root_dir
        venvPath = string.gsub(venvPath, root_dir, "")
        if string.sub(venvPath, 1, 1) == "/" then
          venvPath = string.sub(venvPath, 2)
        end
        if string.sub(venvPath, -1) == "/" then
          venvPath = string.sub(venvPath, 1, -2)
        end
        local python_path = root_dir .. "/" .. venvPath .. pythonExeDir
        if isLog then
          vim.notify("Using relative path from pyrightconfig.json: " .. python_path, vim.log.levels.INFO)
        end
        if vim.fn.filereadable(python_path) == 1 then
          return python_path
        end
      end
    end
  end

  -- Fallback to pipenv --py
  if pipenvFallback then
    local outputpipenvpy = vim.fn.systemlist "pipenv --py"

    if vim.v.shell_error == 0 then
      local python_path = ""
      for _, line in ipairs(outputpipenvpy) do
        if line:match "^/" then
          python_path = line
          break
        end
      end
      if isLog then
        vim.notify("python_path from (pipenv --py) = " .. vim.inspect(python_path), vim.log.levels.INFO)
      end
      if vim.fn.filereadable(python_path) == 1 then
        return python_path
      end
    end
  end
  -- Fallback to default python executable
  local python = vim.fn.exepath "python"
  python = python or vim.fn.exepath "python3"
  if isLog then
    if python == "" then
      vim.notify("No python executable found", vim.log.levels.WARN)
    else
      vim.notify("get_pythonpath using default python exe: " .. python, vim.log.levels.INFO)
    end
  end
  return python
end

--- FROM QUICK-CODE-RUNNER :  Get global file path by type : https://github.com/jellydn/quick-code-runner.nvim/blob/main/lua/quick-code-runner/init.lua#L4
--- Get global file path by type
---@param ext string
---@return string
function M.get_global_file_by_type(ext)
  local state_path = vim.fn.stdpath "state"
  local path = state_path .. "/code-runner"

  -- Create code-runner folder if it does not exist
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path)
  end

  return string.format("%s/code-pad.%s", path, ext)
end

---@return string|nil
function M.get_root_directory_current_buffer()
  -- Change directory to the current buffer's directory
  local buffer_path = vim.fn.expand "%:p:h"
  -- lcd buffer_path
  vim.cmd("lcd " .. buffer_path)
  -- Get git root from current buffer
  if path.is_git_repo() then
    return path.get_git_root()
  else
    return buffer_path
  end
end

-- sample usage
-- input ../somefile.txt
-- output = /full/path/to/somefile.txt
function M.getFullPathFromRelativePath(relPath)
  local success, result = pcall(function()
    if relPath:sub(1, 1) == "/" then
      return relPath
    end
    local relcwd = vim.fn.expand "%:.:h"
    local combined = relcwd .. "/" .. relPath
    return vim.fn.fnamemodify(combined, ":p")
  end)

  if not success then
    vim.notify("Error in getFullPathFromRelativePath: input=" .. relPath .. " result=" .. result, vim.log.levels.ERROR)
    return nil
  end

  if vim.fn.filereadable(result) == 0 and vim.fn.isdirectory(result) == 0 then
    -- vim.notify("Invalid path: " .. result, vim.log.levels.WARN)
    return nil
  end

  return result
end

function M.get_previous_buffer_dir()
  local bufnr = vim.fn.bufnr "#"
  if bufnr == -1 then
    return nil
  end
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == "" then
    return nil
  end
  local bufdir = vim.fn.fnamemodify(bufname, ":p:h")
  return bufdir
end

--- Check if a directory is in the ancestor chain from start_dir to end_dir
--- @param dir string Directory to check
--- @param start_dir string Starting directory (e.g., fromdir)
--- @param end_dir string Ending directory (e.g., root_dir)
--- @return boolean
local function is_in_traversal_path(dir, start_dir, end_dir)
  local temp_dir = start_dir
  while temp_dir and temp_dir ~= "/" and temp_dir ~= end_dir do
    if temp_dir == dir then
      return true
    end
    local parent = vim.fn.fnamemodify(temp_dir, ":h")
    if parent == temp_dir then
      break
    end
    temp_dir = parent
  end
  return temp_dir == dir -- Also check end_dir itself
end

--- Helper function to calculate depth from a reference directory
--- @param dir_path string Directory to measure
--- @param ref_dir string Reference directory
--- @return number
local function calculate_depth_from_ref(dir_path, ref_dir)
  local depth = 0
  local temp_dir = dir_path
  while temp_dir and temp_dir ~= "/" and temp_dir ~= ref_dir do
    depth = depth + 1
    local parent = vim.fn.fnamemodify(temp_dir, ":h")
    if parent == temp_dir then
      break
    end
    temp_dir = parent
  end
  return depth
end

--- Helper function to extract mono label from .nvim-config.lua
--- Searches for pattern "-- mono:<label>" and returns the label
--- @param file_path string Path to .nvim-config.lua
--- @return string
local function extract_mono_label(file_path)
  local default_label = ".nv"
  local ok, content = pcall(vim.fn.readfile, file_path)
  if not ok or not content then
    return default_label
  end
  for _, line in ipairs(content) do
    local label = line:match "^%s*%-%-%s*mono:(%S+)"
    if label then
      return label
    end
  end
  return default_label
end

--- Enrich and filter cached results with fromdir-dependent fields
--- @param cached table[] Cached raw results
--- @param root_dir string Git root directory
--- @param fromdir string Reference directory for in_cwd_traversal
--- @param return_metadata boolean|nil
--- @param return_all boolean|nil
--- @param sort_by "nearest"|"depth"|nil Sort strategy
--- @return string|table|string[]|table[]|nil
local function filter_and_enrich_cached_results(cached, root_dir, fromdir, return_metadata, return_all, sort_by)
  local results = {}

  for _, item in ipairs(cached) do
    local enriched = vim.tbl_extend("force", {}, item)
    enriched.in_cwd_traversal = is_in_traversal_path(item.dir, fromdir, root_dir)
    enriched.depth_from_start = calculate_depth_from_ref(item.dir, fromdir)
    table.insert(results, enriched)
  end

  -- Sort based on strategy
  if sort_by == "nearest" then
    -- Tier 1: CWD traversal items first
    -- Tier 2: Depth from fromdir (NEAREST first)
    -- Tier 3: Marker order
    table.sort(results, function(a, b)
      if a.in_cwd_traversal ~= b.in_cwd_traversal then
        return a.in_cwd_traversal
      end
      if a.depth_from_start ~= b.depth_from_start then
        return a.depth_from_start < b.depth_from_start
      end
      return a.marker_index < b.marker_index
    end)
  else
    -- Default: depth from root (existing behavior)
    table.sort(results, function(a, b)
      if a.in_cwd_traversal ~= b.in_cwd_traversal then
        return a.in_cwd_traversal
      end
      if a.depth ~= b.depth then
        return a.depth < b.depth
      end
      return a.marker_index < b.marker_index
    end)
  end

  if return_metadata then
    return return_all and results or results[1]
  else
    local dirs = {}
    for _, result in ipairs(results) do
      table.insert(dirs, result.dir)
    end
    return return_all and dirs or dirs[1]
  end
end

local function systemlist_with_timeout(cmd, opts)
  opts = opts or {}
  if vim.system then
    local proc = vim.system(cmd, {
      cwd = opts.cwd,
      text = true,
    })
    local result = proc:wait(opts.timeout_ms)
    if not result then
      pcall(proc.kill, proc, 15)
      pcall(proc.wait, proc)
      return {}, true
    end
    local stdout = result and result.stdout or ""
    if result.code == 0 then
      return vim.split(stdout, "\n", { trimempty = true }), false
    end
    return {}, false
  end

  if opts.cwd then
    local escaped_cwd = vim.fn.shellescape(opts.cwd)
    local escaped_cmd = {}
    for _, part in ipairs(cmd) do
      table.insert(escaped_cmd, vim.fn.shellescape(part))
    end
    return vim.fn.systemlist(string.format("cd %s && %s 2>/dev/null", escaped_cwd, table.concat(escaped_cmd, " "))),
      false
  end

  return vim.fn.systemlist(cmd), false
end

local function build_fd_brace_glob(names)
  if #names == 1 then
    return names[1]
  end
  return "{" .. table.concat(names, ",") .. "}"
end

local function collect_ignored_marker_paths(root_dir, ignored_file_markers)
  if #ignored_file_markers == 0 or vim.g.subproject_scan_ignored == false then
    return {}
  end

  local timeout_ms = vim.g.subproject_scan_ignored_timeout_ms or 250
  local max_depth = vim.g.subproject_scan_ignored_depth or 4
  local fd_bin = vim.fn.exepath "fd"
  if fd_bin == "" then
    fd_bin = vim.fn.exepath "fdfind"
  end

  if fd_bin ~= "" then
    local paths, timed_out = systemlist_with_timeout({
      fd_bin,
      "--hidden",
      "--absolute-path",
      "--no-ignore-vcs",
      "--max-depth",
      tostring(max_depth),
      "-E",
      ".git",
      "-E",
      "node_modules",
      "-E",
      ".next",
      "-E",
      "dist",
      "-g",
      build_fd_brace_glob(ignored_file_markers),
    }, {
      cwd = root_dir,
      timeout_ms = timeout_ms,
    })
    if timed_out then
      vim.notify(
        string.format("Ignored marker scan timed out after %dms; skipping ignored markers", timeout_ms),
        vim.log.levels.WARN
      )
      return {}
    end
    return paths
  end

  local find_cmd = { "find", root_dir, "-maxdepth", tostring(max_depth), "(" }
  for i, name in ipairs(ignored_file_markers) do
    table.insert(find_cmd, "-name")
    table.insert(find_cmd, name)
    if i < #ignored_file_markers then
      table.insert(find_cmd, "-o")
    end
  end
  vim.list_extend(find_cmd, {
    ")",
    "-not",
    "-path",
    "*/node_modules/*",
    "-not",
    "-path",
    "*/.git/*",
  })
  local paths, timed_out = systemlist_with_timeout(find_cmd, { timeout_ms = timeout_ms })
  if timed_out then
    vim.notify(
      string.format("Ignored marker scan timed out after %dms; skipping ignored markers", timeout_ms),
      vim.log.levels.WARN
    )
    return {}
  end
  return paths
end

--- Get all sub-project directories from git root (entire tree scan)
--- Scans entire git root tree for marker files, not just ancestor chain
--- Returns same metadata as get_sub_project_dir plus in_cwd_traversal flag
--- @param root_dir string|nil Git root directory (default: auto-detect)
--- @param fromdir string|nil Reference directory for in_cwd_traversal flag (default: current buffer dir)
--- @param return_metadata boolean|nil If true, returns table with metadata; if false, returns just dir path(s)
--- @param return_all boolean|nil If true, returns all matches; if false, returns first match only
--- @param sort_by "nearest"|"depth"|nil Sort strategy: "nearest" = by depth_from_start (CWD proximity), "depth" = by depth from root (default)
--- @param opts table|nil Optional settings: { force_refresh = boolean }
--- @return string|table|string[]|table[]|nil Returns directory path(s) or metadata object(s)
--- Metadata includes: dir, matched_file, project_type, marker_type, depth, depth_from_start,
---                   marker_index, is_git_root, in_cwd_traversal, in_submodule, submodule_root
function M.get_sub_project_dirs_from_root(root_dir, fromdir, return_metadata, return_all, sort_by, opts)
  local gitUtil = require "utils.git"
  opts = opts or {}

  -- Auto-detect root_dir and fromdir
  root_dir = root_dir or path.get_root_directory()
  fromdir = fromdir or vim.fn.expand "%:p:h"

  if not root_dir then
    local fallback = return_metadata
        and {
          dir = fromdir,
          matched_file = nil,
          project_type = "unknown",
          marker_type = nil,
          depth = 0,
          depth_from_start = 0,
          marker_index = 999,
          is_git_root = false,
          in_cwd_traversal = true,
          in_submodule = false,
          submodule_root = nil,
        }
      or fromdir
    return return_all and { fallback } or fallback
  end

  -- Cache invalidates when .git mtime changes or when clear_subproject_cache() bumps the
  -- generation counter. Ignored-only markers do not touch .git, so use force_refresh when needed.
  local git_mtime = vim.fn.getftime(root_dir .. "/.git")
  local cache_key = table.concat({ root_dir, tostring(git_mtime), tostring(_subproject_cache_generation) }, ":")
  if not opts.force_refresh and _subproject_cache[cache_key] then
    return filter_and_enrich_cached_results(
      _subproject_cache[cache_key],
      root_dir,
      fromdir,
      return_metadata,
      return_all,
      sort_by
    )
  end

  -- Perform full scan
  local all_results = {}
  local seen_dirs = {}

  -- Helper: check marker match with submodule detection
  local function check_marker_match_with_meta(dir, marker, marker_idx)
    local names = type(marker.name) == "table" and marker.name or { marker.name }
    local matched_files = {}
    local is_dir_marker = marker.is_directory or false

    -- For match_from_within markers, check if dir itself IS the marker directory
    -- e.g. dir=/root/.gitlab and marker.name=".gitlab" → dir IS the marker, not its parent
    if marker.match_from_within and type(marker.name) == "string" then
      local clean_name = marker.name:gsub("/$", "")
      local dir_basename = vim.fn.fnamemodify(dir, ":t")
      if dir_basename == clean_name then
        -- dir IS the marker directory itself — validate fromdir is inside
        local is_inside = fromdir:match("^" .. vim.pesc(dir) .. "/") or fromdir == dir
        if not is_inside then
          return nil
        end

        -- Determine project_type
        local project_type = marker.project_type

        -- Detect submodule info
        local in_submodule = gitUtil.is_in_submodule(dir)
        local submodule_root = in_submodule and gitUtil.get_submodule_root(dir) or nil

        local scan_source = (marker.git_ignored and "ignored") or (is_dir_marker and "dir") or "tracked"

        return {
          dir = dir,
          matched_file = clean_name,
          project_type = project_type,
          marker_type = marker.type,
          depth = calculate_depth_from_ref(dir, root_dir),
          depth_from_start = calculate_depth_from_ref(dir, fromdir),
          marker_index = marker_idx,
          is_git_root = (dir == root_dir),
          in_cwd_traversal = is_in_traversal_path(dir, fromdir, root_dir),
          in_submodule = in_submodule,
          submodule_root = submodule_root,
          scan_source = scan_source,
        }
      end
    end

    for _, raw_name in ipairs(names) do
      local name = raw_name:gsub("/$", "") -- strip trailing /
      local found = false

      if marker.type == "pattern" then
        local ok, files = pcall(vim.fn.readdir, dir)
        if ok then
          for _, file in ipairs(files) do
            if file:match(name) then
              table.insert(matched_files, file)
              found = true
              break
            end
          end
        end
      else
        local target_path = dir .. "/" .. name
        if is_dir_marker then
          found = vim.fn.isdirectory(target_path) == 1
        else
          found = vim.fn.filereadable(target_path) == 1 or vim.fn.isdirectory(target_path) == 1
        end
        if found then
          table.insert(matched_files, name)
        end
      end

      if not found then
        return nil
      end
    end

    -- Resolve the effective subproject directory
    -- match_from_within: the marker dir itself is the subproject (e.g. .gitlab/ not its parent)
    local effective_dir = dir
    if marker.match_from_within and #matched_files > 0 then
      local marker_dir = dir .. "/" .. matched_files[1]
      local is_inside = fromdir:match("^" .. vim.pesc(marker_dir) .. "/") or fromdir == marker_dir
      if not is_inside then
        return nil
      end
      -- The marker directory itself is the subproject
      effective_dir = marker_dir
    end

    -- Determine project_type
    local project_type = marker.project_type
    if marker.name == ".nvim-config.lua" and #matched_files > 0 then
      local config_file = dir .. "/" .. matched_files[1]
      project_type = extract_mono_label(config_file)
    end

    -- Detect submodule info
    local in_submodule = gitUtil.is_in_submodule(effective_dir)
    local submodule_root = in_submodule and gitUtil.get_submodule_root(effective_dir) or nil

    -- Determine scan source for diagnostics
    local scan_source = "tracked"
    if marker.git_ignored then
      scan_source = "ignored"
    elseif is_dir_marker then
      scan_source = "dir"
    end

    return {
      dir = effective_dir,
      matched_file = table.concat(matched_files, ", "),
      project_type = project_type,
      marker_type = marker.type,
      depth = calculate_depth_from_ref(effective_dir, root_dir),
      depth_from_start = calculate_depth_from_ref(effective_dir, fromdir),
      marker_index = marker_idx,
      is_git_root = (effective_dir == root_dir),
      in_cwd_traversal = is_in_traversal_path(effective_dir, fromdir, root_dir),
      in_submodule = in_submodule,
      submodule_root = submodule_root,
      scan_source = scan_source,
    }
  end

  -- Classify markers into scanning pipelines based on flags
  local tracked_file_markers = {} -- Pipeline A: git-tracked files
  local tracked_dir_markers = {} -- Pipeline B: git-tracked directories
  local ignored_file_markers = {} -- Pipeline C: git-ignored files
  local pattern_markers = {} -- Existing pattern matching (unchanged)

  for marker_idx, marker in ipairs(M.SUBPROJECT_MARKERS) do
    if marker.skip_scan then
      -- skip_scan: marker is detected via candidate_dirs (e.g. root always added)
    elseif marker.type == "pattern" then
      local glob = marker.name:gsub("%%.", "*"):gsub("%$$", "")
      table.insert(pattern_markers, { glob = glob, marker = marker, idx = marker_idx })
    elseif marker.type == "path" then
      local names = type(marker.name) == "table" and marker.name or { marker.name }
      local is_dir = marker.is_directory or false
      local is_ignored = marker.git_ignored or false

      for _, name in ipairs(names) do
        local clean_name = name:gsub("/$", "") -- strip trailing / if any
        if is_ignored then
          table.insert(ignored_file_markers, clean_name)
        elseif is_dir then
          table.insert(tracked_dir_markers, clean_name)
        else
          table.insert(tracked_file_markers, clean_name)
        end
      end
    end
  end

  local candidate_dirs = {}
  local shellescape = vim.fn.shellescape
  local escaped_root = shellescape(root_dir)

  -- PIPELINE A: git ls-files for tracked file markers.
  -- Sample on trips-web worktree (TRIPWEB-2701-custom-note-slice, Mar 2026): ~0.38s cold.
  if #tracked_file_markers > 0 then
    local escaped = {}
    for _, m in ipairs(tracked_file_markers) do
      table.insert(escaped, shellescape("**/" .. m))
    end
    local cmd = string.format(
      "git -C %s ls-files --cached --others --exclude-standard -- %s 2>/dev/null",
      escaped_root,
      table.concat(escaped, " ")
    )
    for _, file in ipairs(vim.fn.systemlist(cmd)) do
      candidate_dirs[root_dir .. "/" .. vim.fn.fnamemodify(file, ":h")] = true
    end
  end

  -- PIPELINE B: git ls-files for directory markers, then collapse file hits to unique dirs.
  -- Sample on trips-web worktree (TRIPWEB-2701-custom-note-slice, Mar 2026): ~0.32s cold.
  -- Uses **/<dir>/** pattern to find files inside, then extracts the marker dir
  -- Optimization: pre-compile patterns and deduplicate on first match per directory
  if #tracked_dir_markers > 0 then
    -- Build pre-compiled pattern lookup for each marker name
    local dir_patterns = {}
    for _, m in ipairs(tracked_dir_markers) do
      local esc = vim.pesc(m)
      table.insert(dir_patterns, {
        name = m,
        mid = "/(" .. esc .. ")/", -- matches /Clientside/ mid-path
        start = "^(" .. esc .. ")/", -- matches Clientside/ at start
      })
    end

    local escaped = {}
    for _, m in ipairs(tracked_dir_markers) do
      table.insert(escaped, shellescape("**/" .. m .. "/**"))
    end
    local cmd = string.format(
      "git -C %s ls-files --cached --others --exclude-standard -- %s 2>/dev/null",
      escaped_root,
      table.concat(escaped, " ")
    )
    local seen_dir_candidates = {}
    for _, file in ipairs(vim.fn.systemlist(cmd)) do
      for _, dp in ipairs(dir_patterns) do
        local s, _, match = file:find(dp.mid)
        if not s then
          s, _, match = file:find(dp.start)
        end
        if s and match then
          local prefix = s > 1 and file:sub(1, s - 1) or ""
          local parent_dir = prefix == "" and root_dir or (root_dir .. "/" .. prefix:gsub("/$", ""))
          local key = parent_dir .. "|" .. match
          if not seen_dir_candidates[key] then
            seen_dir_candidates[key] = true
            candidate_dirs[parent_dir] = true
            -- Also add the marker dir itself as candidate (for match_from_within markers)
            candidate_dirs[parent_dir .. "/" .. match] = true
          end
          break -- first marker match wins for this file, skip remaining markers
        end
      end
    end
  end

  -- PIPELINE C: ignored marker scan.
  -- Group ignored names into one command and cap runtime to keep the picker responsive.
  -- Sample on trips-web worktree (TRIPWEB-2701-custom-note-slice, Mar 2026): fd ~0.05s cold,
  -- while find with the same depth cap was ~0.53s cold.
  for _, abs_path in ipairs(collect_ignored_marker_paths(root_dir, ignored_file_markers)) do
    candidate_dirs[vim.fn.fnamemodify(abs_path, ":h")] = true
  end

  -- Pattern markers (%.sln$ etc. - unchanged)
  if #pattern_markers > 0 then
    for _, pm in ipairs(pattern_markers) do
      local cmd = string.format(
        "git -C %s ls-files --cached --others --exclude-standard -- %s 2>/dev/null",
        escaped_root,
        shellescape("**/" .. pm.glob)
      )
      for _, file in ipairs(vim.fn.systemlist(cmd)) do
        candidate_dirs[root_dir .. "/" .. vim.fn.fnamemodify(file, ":h")] = true
      end
    end
  end

  -- Always include git root as candidate
  candidate_dirs[root_dir] = true

  -- Validate each candidate against marker rules
  for dir, _ in pairs(candidate_dirs) do
    for marker_idx, marker in ipairs(M.SUBPROJECT_MARKERS) do
      local match = check_marker_match_with_meta(dir, marker, marker_idx)
      if match and not seen_dirs[match.dir] then
        seen_dirs[match.dir] = true
        table.insert(all_results, match)
      end
    end
  end

  -- Cache the raw results (without fromdir-dependent fields recomputed)
  _subproject_cache[cache_key] = all_results

  -- Sort based on strategy
  if sort_by == "nearest" then
    -- Tier 1: CWD traversal items first
    -- Tier 2: Depth from fromdir (NEAREST first)
    -- Tier 3: Marker order
    table.sort(all_results, function(a, b)
      if a.in_cwd_traversal ~= b.in_cwd_traversal then
        return a.in_cwd_traversal
      end
      if a.depth_from_start ~= b.depth_from_start then
        return a.depth_from_start < b.depth_from_start
      end
      return a.marker_index < b.marker_index
    end)
  else
    -- Default: depth from root (existing behavior)
    table.sort(all_results, function(a, b)
      if a.in_cwd_traversal ~= b.in_cwd_traversal then
        return a.in_cwd_traversal
      end
      if a.depth ~= b.depth then
        return a.depth < b.depth
      end
      return a.marker_index < b.marker_index
    end)
  end

  -- Return in same format as get_sub_project_dir
  if return_metadata then
    return return_all and all_results or all_results[1]
  else
    local dirs = {}
    for _, result in ipairs(all_results) do
      table.insert(dirs, result.dir)
    end
    return return_all and dirs or dirs[1]
  end
end

--- Clear the subproject cache (useful for manual refresh)
function M.clear_subproject_cache(opts)
  opts = opts or {}
  _subproject_cache = {}
  _subproject_cache_generation = _subproject_cache_generation + 1
  if not opts.silent then
    vim.notify("Subproject cache cleared", vim.log.levels.INFO)
  end
end

function M.get_git_real_filepath(filepath)
  if not filepath or filepath == "" then
    filepath = vim.fn.expand "%:p"
  end
  local git_root = M.get_root_directory_current_buffer()

  if not git_root then
    return nil
  end
  -- testing
  -- local git_root = "/Users/tharutaipree/AgodaGit/fe/trips-web.worktrees/exp-check/libs/cart/trip/src/crossSellWidget/core/store/features/constants/feature.enum.ts"
  -- local filepath = "/Users/tharutaipree/AgodaGit/fe/trips-web.worktrees/exp-check/libs/cart/trip/src/crossSellWidget/core/store/features/constants/feature.enum.ts"
  -- local git_root = "/Users/tharutaipree/AgodaGit/fe/trips-web.worktrees/exp-check"
  local rel_path = filepath:sub(#git_root + 2)
  return rel_path
end

--- Get the current working directory for a buffer
--- For terminal buffers, returns the terminal's actual cwd
--- For normal buffers, returns the buffer's directory
---@param bufnr number|nil Buffer number (default: current buffer)
---@return string|nil The working directory path, or nil if it cannot be determined
function M.get_buffer_cwd(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Check if buffer is a terminal buffer
  local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
  if buftype == "terminal" then
    -- Get the terminal's process ID
    local ok, term_pid = pcall(vim.api.nvim_buf_get_var, bufnr, "terminal_job_pid")

    if ok and term_pid then
      -- Try to get the actual cwd from the terminal process
      local cwd_result
      if vim.fn.has "mac" == 1 or vim.fn.has "macunix" == 1 then
        -- macOS: use lsof to get the terminal's current working directory
        cwd_result = vim.fn.systemlist { "lsof", "-a", "-d", "cwd", "-p", tostring(term_pid), "-Fn" }
        -- lsof output format: n/path/to/cwd
        print([==[M.get_buffer_cwd#if#if#if#for cwd_result:]==], vim.inspect(cwd_result)) -- __AUTO_GENERATED_PRINT_VAR_END__
        for _, line in ipairs(cwd_result) do
          -- __AUTO_GENERATED_PRINT_VAR_START__
          if line:match "^n" then
            return line:sub(2) -- Remove 'n' prefix
          end
        end
      else
        -- Linux: read from /proc/<pid>/cwd
        local proc_cwd = "/proc/" .. term_pid .. "/cwd"
        if vim.fn.isdirectory(proc_cwd) == 1 then
          return vim.fn.resolve(proc_cwd)
        end
      end
    end

    -- Fallback: parse cwd from terminal buffer name
    -- Format: term://path//pid:shell or term://path//pid:shell;#toggleterm#N
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local term_path = bufname:match "^term://(.-)//[0-9]+:"
    if term_path then
      return vim.fn.expand(term_path) -- Expand ~ if present
    end
  end

  -- For normal buffers, use the buffer's directory
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p:h")
end

-- Project detection utility moved from utils/snacks_terminal
--- Determine whether a given path or snacks picker item is inside the project directory.
--- Accepts either an item (from snacks picker) or a plain path string.
--- @param item_or_path string|table Snacks picker item or path string
--- @return boolean
function M.is_in_project_dir(item_or_path)
  local uv = vim.uv or vim.loop
  local pathval

  if type(item_or_path) == "table" then
    local ok, util = pcall(function()
      return require("snacks").picker.util
    end)
    if ok and util then
      pathval = util.path(item_or_path)
    else
      pathval = nil
    end
  elseif type(item_or_path) == "string" then
    pathval = item_or_path
  else
    pathval = nil
  end

  if not pathval or pathval == "" then
    return true
  end

  local function normalize(p)
    if not p or p == "" then
      return p
    end
    local ok, real = pcall(function()
      if uv.fs_realpath then
        return uv.fs_realpath(p)
      end
      return vim.fn.fnamemodify(p, ":p")
    end)
    if ok and real and real ~= vim.NIL then
      return real
    end
    return vim.fn.fnamemodify(p, ":p")
  end

  local normalized_path = normalize(pathval)
  if not normalized_path then
    return true
  end

  -- Prefer git root if available
  local project_root
  do
    local ok, git = pcall(function()
      return require("snacks").git
    end)
    if ok and git and git.get_root then
      local cwd = vim.fn.getcwd(0)
      project_root = git.get_root(cwd)
    end
  end

  if not project_root or project_root == "" then
    project_root = vim.fn.getcwd(0)
  end

  project_root = normalize(project_root)
  if project_root:sub(-1) ~= "/" then
    project_root = project_root .. "/"
  end

  if normalized_path:sub(1, #project_root) == project_root then
    return true
  end

  return false
end

-- ============================================================================
-- goto_file_line() - Enhanced file navigation with wrapper stripping & env var expansion
-- Test samples and full documentation: tasks/done/goto_file_line_wrapper_stripping.md
-- Supports: IDE-style (file:100), Git-style (file#L100), markdown anchors,
--           wrapped paths (handles unbalanced/multiple wrappers: `'[file]`, `file`, etc.)
--           env vars ($HOME/file, ${VAR}/file, ~/file)
-- ============================================================================

function M.goto_file_line(open_in_previous_buffer)
  local fileRef = require "utils.file_reference"

  -- Extract file path and line number
  local fileline = vim.fn.expand "<cfile>"
  local current_line = vim.api.nvim_get_current_line()

  -- Get the whole fileline with extra info like :line and :col from current line
  -- Strategy: Find the complete non-whitespace token that contains the cfile path
  local fileline_incurrentline_untilspace = nil
  local escaped_fileline = vim.pesc(fileline)
  for token in current_line:gmatch "%S+" do
    if token:match(escaped_fileline) then
      fileline_incurrentline_untilspace = token
      break
    end
  end

  -- Use the extended version if found, otherwise use the basic fileline
  local target = fileline_incurrentline_untilspace or fileline

  -- Handle visual mode selection
  local inputUtil = require "utils.input"
  if inputUtil.is_visual_mode() then
    target = inputUtil.get_selected_or_cursor_word()
    -- Clean multiline selections to remove newlines and extra spaces
    target = inputUtil.clean_selected_text(target)
  end

  -- Normalize target for common markdown link patterns like [text](file.md#anchor)
  local md_link = target:match "%b()"
  if md_link then
    local inner = md_link:sub(2, -2)
    if inner and inner ~= "" then
      target = inner
    end
  end

  -- Strip non-path characters from start and end (iteratively)
  -- Handles: `file`, 'file', "file", [file], <file>, unbalanced/multiple wrappers
  -- Non-path chars: backticks, quotes, brackets, angle brackets, whitespace
  local prev
  repeat
    prev = target
    target = target:gsub("^[`'\"<%[%]>%(%)%s]+", "") -- strip from start
    target = target:gsub("[`'\"<%[%]>%(%)%s]+$", "") -- strip from end
  until target == prev

  -- Expand environment variables and tilde (like native gf)
  -- Handles: $HOME/file, ${HOME}/file, ~/file, $ENV_VAR/path
  -- Extract base path without line/col/anchor for expansion
  local path_part = target:match "^([^:#]+)" or target

  -- First, manually expand ${VAR} syntax (vim.fn.expand doesn't handle this)
  local expanded_part = path_part:gsub("%${([^}]+)}", function(var)
    return os.getenv(var) or ("${" .. var .. "}")
  end)

  -- Then use vim.fn.expand for $VAR and ~ (standard expansion)
  expanded_part = vim.fn.expand(expanded_part)

  if expanded_part ~= path_part then
    -- If expansion happened, replace the path part in target
    target = target:gsub("^" .. vim.pesc(path_part), expanded_part)
  end
  -- Parse file reference (handles IDE style, git style, anchors, URIs)
  local parsed = fileRef.parse_file_reference(target)
  local path, line, col, anchor = parsed.path, parsed.line, parsed.col, parsed.anchor

  -- Validate and open the file
  if path and path ~= "" then
    -- Resolve path with smart priority logic
    local resolved_path = fileRef.resolve_file_path(path)

    -- Open the file
    if open_in_previous_buffer then
      local current_win = vim.api.nvim_get_current_win()
      if current_win == vim.g.prev_win then
        vim.cmd "vsplit"
      elseif not (vim.g.prev_win and vim.api.nvim_win_is_valid(vim.g.prev_win)) then
        vim.cmd "vsplit" -- in case window already closed ?
      end
    end

    -- Open the file
    vim.cmd("edit " .. vim.fn.fnameescape(resolved_path))

    local is_file_readable = vim.fn.filereadable(resolved_path) == 1
    if not is_file_readable then
      vim.notify("File not found use gf: " .. resolved_path, vim.log.levels.INFO)
      vim.cmd "normal! gf"
    end

    -- Jump to line if provided
    if line and line ~= "" then
      vim.cmd(line)
      -- Jump to column if provided
      if col and col ~= "" then
        vim.cmd("normal! " .. col .. "|")
      end
    end

    -- Jump to anchor if provided (e.g. file.md#section-name)
    if anchor and anchor ~= "" then
      fileRef.jump_to_anchor(anchor)
    end
  else
    -- Fallback to default gf behavior
    vim.cmd "normal! gf"
  end
end

return M
