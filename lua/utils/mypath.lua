local path = require "utils.path"
local M = {}

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
--- Get sub-project directories in a monorepo with metadata (supports multiple results)
--- Searches for common monorepo markers (package.json, pyproject.toml, etc.)
--- in parent directories up to the git root
--- Supports multiple marker matching with AND condition (all markers in array must exist)
--- Results sorted by: 1) depth from fromdir (nearest first), 2) marker order (earlier first)
---@param fromdir string|nil Starting directory (default: current buffer directory)
---@param return_metadata boolean|nil If true, returns table with metadata; if false, returns just dir path(s)
---@param return_all boolean|nil If true, returns all matches sorted by nearest to fromdir; if false, returns first match only
---@return string|table|string[]|table[]|nil Returns directory path(s) or metadata object(s)
--- Metadata includes: dir, matched_file, project_type, marker_type, depth (from git root), depth_from_start (from fromdir), marker_index, is_git_root (boolean)
function M.get_sub_project_dir(fromdir, return_metadata, return_all)
  local path = require "utils.path"
  local current_dir = fromdir or vim.fn.expand "%:p:h"
  local root_dir = path.get_root_directory()

  if not root_dir then
    print([==[M.get_sub_project_dir#if root_dir:]==], vim.inspect(root_dir)) -- __AUTO_GENERATED_PRINT_VAR_END__
    local fallback = return_metadata
        and {
          dir = current_dir,
          matched_file = nil,
          project_type = "unknown",
          marker_type = nil,
          depth = 0,
          depth_from_start = 0,
          marker_index = 999,
          is_git_root = false,
        }
      or current_dir
    return return_all and { fallback } or fallback
  end

  -- Marker configuration with project type metadata
  -- name can be a string or array of strings (AND condition for arrays)
  local markers = {
    { name = "package.json", type = "path", project_type = "yarn" },
    { name = "pyproject.toml", type = "path", project_type = "python" },
    { name = "Cargo.toml", type = "path", project_type = "rust" },
    { name = "go.mod", type = "path", project_type = "golang" },
    { name = "pom.xml", type = "path", project_type = "maven" },
    { name = "build.gradle", type = "path", project_type = "gradle" },
    { name = "%.sln$", type = "pattern", project_type = "dotnet" },
    { name = { "Clientside/", "Serverside/" }, type = "path", project_type = "cronos" },
    -- { name = ".gitlab-ci.yml", type = "path", project_type = "gitlab" },
    -- does it support parent relative marker ?
    -- { name = "../.gitlab", type = "path", project_type = ".glab" }, -- relative backwards not working
    { name = ".git", type = "path", project_type = "git" },
  }

  local results = {}
  local seen_dirs = {}

  -- Helper function to calculate depth from a reference directory (fromdir or git root)
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

  -- Helper function to check if marker matches (handles both string and array names)
  local function check_marker_match(dir, marker, marker_index)
    local names = type(marker.name) == "table" and marker.name or { marker.name }
    local matched_files = {}

    for _, name in ipairs(names) do
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
        local file_path = dir .. "/" .. name
        if vim.fn.filereadable(file_path) == 1 or vim.fn.isdirectory(file_path) == 1 then
          table.insert(matched_files, name)
          found = true
        end
      end

      -- If any name in the array doesn't match, fail the whole marker (AND condition)
      if not found then
        return nil
      end
    end

    -- All names matched, return result
    return {
      dir = dir,
      matched_file = table.concat(matched_files, ", "),
      project_type = marker.project_type,
      marker_type = marker.type,
      depth = calculate_depth_from_ref(dir, root_dir), -- depth from git root
      depth_from_start = calculate_depth_from_ref(dir, current_dir), -- depth from fromdir
      marker_index = marker_index, -- original marker order for secondary sort
      is_git_root = (dir == root_dir), -- flag to indicate if this dir is the git root
    }
  end

  local dir = current_dir

  while dir and dir ~= "/" and dir ~= root_dir do
    -- print([==[M.get_sub_project_dir#while dir:]==], vim.inspect(dir)) -- __AUTO_GENERATED_PRINT_VAR_END__
    for marker_idx, marker in ipairs(markers) do
      local match = check_marker_match(dir, marker, marker_idx)
      if match then
        -- Avoid duplicate directories in results
        if not seen_dirs[match.dir] then
          seen_dirs[match.dir] = true

          if not return_all then
            -- Return first match immediately
            if return_metadata then
              return match
            end
            return match.dir
          else
            -- Collect all matches
            table.insert(results, match)
          end
        end
      end
    end

    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break
    end
    dir = parent
  end

  -- No match found, return git root
  if #results == 0 then
    local fallback = return_metadata
        and {
          dir = root_dir,
          matched_file = nil,
          project_type = "gitroot",
          marker_type = nil,
          depth = 0,
          depth_from_start = calculate_depth_from_ref(root_dir, current_dir),
          marker_index = 999, -- fallback always last in sort order
          is_git_root = true,
        }
      or root_dir
    if return_all then
      return { fallback }
    else
      return fallback
    end
  end

  -- Sort by depth from fromdir (smallest = nearest), then by marker order
  --   How It Works
  --
  -- Example scenario: You have a monorepo with nested projects:
  -- /repo (git root)
  --   /frontend
  --     /packages
  --       /app1          <- package.json (marker index 1)
  --       /app2          <- pyproject.toml (marker index 2)
  --         /nested      <- package.json (marker index 1)
  --
  -- When called from /repo/frontend/packages/app2/nested:
  -- 1. Finds all matching subprojects going up the tree
  -- 2. Sorts by depth_from_start:
  --   - nested (depth 0) comes first
  --   - app2 (depth 1) comes second
  --   - app1 (depth 2) comes third
  --
  table.sort(results, function(a, b)
    if a.depth_from_start == b.depth_from_start then
      -- If same depth from fromdir, use original marker order
      return a.marker_index < b.marker_index
    end
    return a.depth_from_start < b.depth_from_start
  end)
  if return_metadata then
    return return_all and results or results[1] -- return metadata object(s)
  else
    local dirs = {}
    for _, result in ipairs(results) do
      table.insert(dirs, result.dir)
    end
    return return_all and dirs or dirs[1] -- return dir string(s)
  end
end

-- vim.keymap.set("n", "<localleader>zt", function()
--   local subdir = M.get_sub_project_dir()
--   Snacks.debug(subdir)
-- end, { desc = "Get Sub-Project Directory" })

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
