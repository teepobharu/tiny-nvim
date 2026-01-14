local path = require("utils.path")
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
    local outputpipenvpy = vim.fn.systemlist("pipenv --py")

    if vim.v.shell_error == 0 then
      local python_path = ""
      for _, line in ipairs(outputpipenvpy) do
        if line:match("^/") then
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
  local python = vim.fn.exepath("python")
  python = python or vim.fn.exepath("python3")
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
  local state_path = vim.fn.stdpath("state")
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
  local buffer_path = vim.fn.expand("%:p:h")
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
    local relcwd = vim.fn.expand("%:.:h")
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
  local bufnr = vim.fn.bufnr("#")
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
--- Get the closest sub-project directory in a monorepo with metadata
--- Searches for common monorepo markers (package.json, pyproject.toml, etc.)
--- in parent directories up to the git root
---@param fromdir string|nil Starting directory (default: current buffer directory)
---@param return_metadata boolean|nil If true, returns table with metadata; if false, returns just dir path
---@return string|table|nil Returns directory path or {dir, matched_file, project_type, marker_type}
function M.get_sub_project_dir(fromdir, return_metadata)
  local path = require("utils.path")
  local current_file = vim.fn.expand("%:p")
  local current_dir = fromdir or vim.fn.expand("%:p:h")
  local root_dir = path.get_root_directory()

  if not root_dir  then
    print([==[M.get_sub_project_dir#if root_dir:]==], vim.inspect(root_dir)) -- __AUTO_GENERATED_PRINT_VAR_END__
    return return_metadata and { dir = current_dir, matched_file = nil, project_type = "unknown", marker_type = nil } or current_dir
  end

  -- Marker configuration with project type metadata
  local markers = {
    { name = "package.json", type = "path", project_type = "yarn/npm" },
    { name = "pyproject.toml", type = "path", project_type = "python" },
    { name = "Cargo.toml", type = "path", project_type = "rust" },
    { name = "go.mod", type = "path", project_type = "golang" },
    { name = "pom.xml", type = "path", project_type = "maven" },
    { name = "build.gradle", type = "path", project_type = "gradle" },
    { name = ".gitlab-ci.yml", type = "path", project_type = "gitlab" },
    { name = ".git", type = "path", project_type = "git" },
    { name = "%.sln$", type = "pattern", project_type = "dotnet" },
  }

  local dir = current_dir

  while dir and dir ~= "/" and dir ~= root_dir do
    -- print([==[M.get_sub_project_dir#while dir:]==], vim.inspect(dir)) -- __AUTO_GENERATED_PRINT_VAR_END__
    for _, marker in ipairs(markers) do
      if marker.type == "pattern" then
        local ok, files = pcall(vim.fn.readdir, dir)
        if ok then
          for _, file in ipairs(files) do
            if file:match(marker.name) then
              if return_metadata then
                return {
                  dir = dir,
                  matched_file = file,
                  project_type = marker.project_type,
                  marker_type = "pattern",
                }
              end
              return dir
            end
          end
        end
      else
        local file_path = dir .. "/" .. marker.name
        if vim.fn.filereadable(file_path) == 1 or vim.fn.isdirectory(file_path) == 1 then
          if return_metadata then
            return {
              dir = dir,
              matched_file = marker.name,
              project_type = marker.project_type,
              marker_type = "path",
            }
          end
          return dir
        end
      end
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then break end
    dir = parent
  end

  if return_metadata then
    return {
      dir = root_dir,
      matched_file = nil,
      project_type = "gitroot",
      marker_type = nil,
    }
  end
  return root_dir
end

-- vim.keymap.set("n", "<localleader>zt", function()
--   local subdir = M.get_sub_project_dir()
--   Snacks.debug(subdir)
-- end, { desc = "Get Sub-Project Directory" })

function M.get_git_real_filepath(filepath)
  if not filepath or filepath == "" then
    filepath = vim.fn.expand("%:p")
  end
  local git_root = M.get_root_directory_current_buffer()

  if not git_root then
    return nil
  end
  -- testing
  -- local git_root = "/Users/tharutaipree/AgodaGit/fe/trips-web.worktrees/exp-check/libs/cart/trip/src/crossSellWidget/core/store/features/constants/feature.enum.ts"
  -- local filepath = "/Users/tharutaipree/AgodaGit/fe/trips-web.worktrees/exp-check/libs/cart/trip/src/crossSellWidget/core/store/features/constants/feature.enum.ts"
  -- local git_root = "/Users/tharutaipree/AgodaGit/fe/trips-web.worktrees/exp-check"
  local rel_path  = filepath:sub(#git_root + 2)
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
      if vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1 then
        -- macOS: use lsof to get the terminal's current working directory
        cwd_result = vim.fn.systemlist({ "lsof", "-a", "-d", "cwd", "-p", tostring(term_pid), "-Fn" })
        -- lsof output format: n/path/to/cwd
        print([==[M.get_buffer_cwd#if#if#if#for cwd_result:]==], vim.inspect(cwd_result)) -- __AUTO_GENERATED_PRINT_VAR_END__
        for _, line in ipairs(cwd_result) do
        -- __AUTO_GENERATED_PRINT_VAR_START__
          if line:match("^n") then
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
    local term_path = bufname:match("^term://(.-)//[0-9]+:")
    if term_path then
      return vim.fn.expand(term_path) -- Expand ~ if present
    end
  end

  -- For normal buffers, use the buffer's directory
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p:h")
end

return M
