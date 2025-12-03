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

--- Get the closest sub-project directory in a monorepo
--- Searches for common monorepo markers (package.json, pyproject.toml, etc.)
--- in parent directories up to the git root
---@return string|nil
function M.get_sub_project_dir()
  local path = require("utils.path")
  local current_file = vim.fn.expand("%:p")
  local current_dir = vim.fn.expand("%:p:h")
  local root_dir = path.get_root_directory()

  if not root_dir then
    return current_dir
  end

  -- Common project markers for monorepos
  local markers = {
    "package.json",
    "pyproject.toml",
    "Cargo.toml",
    "go.mod",
    "pom.xml",
    "build.gradle",
    ".gitlab-ci.yml",
    ".git",
  }

  -- Walk up from current directory to root
  local dir = current_dir
  while dir ~= root_dir and dir ~= "/" do
    for _, marker in ipairs(markers) do
      if vim.fn.filereadable(dir .. "/" .. marker) == 1 then
        return dir
      end
    end
    dir = vim.fn.fnamemodify(dir, ":h")
  end

  -- Fallback to root directory
  return root_dir
end

return M
