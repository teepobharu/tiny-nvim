---@param filepath string
---@return string
local function get_file_content(filepath)
  local file = io.open(filepath, "r")
  if not file then
    error("Could not open file: " .. filepath)
  end
  local content = file:read("*all")
  file:close()
  return content
end

---@param filepath string
---@param content string
---@return string
local function get_namespace(filepath, content)
  -- Extract the namespace from the file content
  local namespace = content:match("namespace%s+([%w%.]+)")
  if not namespace then
    error("Namespace not found in file: " .. filepath)
  end
  return namespace
end

---@param filepath string
---@param content string
---@return string
local function get_class_name(filepath, content)
  -- Extract the class name from the file content
  local class_name = content:match("class%s+([%w_]+)")
  if not class_name then
    -- Fall back to using the file name if class name is not found
    class_name = filepath:match("([^/]+)%.cs$")
  end
  return class_name
end

---@param filepath string
---@return string|nil
local function find_test_project(filepath)
  -- First, check the current directory
  local dir = vim.fn.fnamemodify(filepath, ":h")
  local max_depth = 10
  local depth = 0

  -- Try current directory and parents
  local search_dir = dir
  while search_dir ~= "/" and search_dir ~= "" and depth < max_depth do
    local handle = vim.loop.fs_scandir(search_dir)
    if handle then
      while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then break end
        if type == "file" and name:match("%.csproj$") then
          return search_dir .. "/" .. name
        end
      end
    end

    search_dir = vim.fn.fnamemodify(search_dir, ":h")
    depth = depth + 1
  end

  -- If not found, search sibling directories (common for test projects)
  -- Collect all .csproj files in sibling directories
  local parent_dir = vim.fn.fnamemodify(dir, ":h")
  local current_dir_name = vim.fn.fnamemodify(dir, ":t")
  local project_files = {}

  local handle = vim.loop.fs_scandir(parent_dir)
  if handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end
      if type == "directory" then
        local sibling_dir = parent_dir .. "/" .. name
        local sibling_handle = vim.loop.fs_scandir(sibling_dir)
        if sibling_handle then
          while true do
            local file_name, file_type = vim.loop.fs_scandir_next(sibling_handle)
            if not file_name then break end
            if file_type == "file" and file_name:match("%.csproj$") then
              local full_path = sibling_dir .. "/" .. file_name
              table.insert(project_files, {
                path = full_path,
                name = file_name,
                dir = name,
              })
            end
          end
        end
      end
    end
  end

  -- Prefer projects with matching names (e.g., "Mmb.Tests" -> "MmbUnitTests")
  if #project_files > 0 then
    -- Extract base name for matching (e.g., "Agoda.Cronos.Mmb.Tests" -> "Mmb")
    local test_base = current_dir_name:gsub("^.*%.", ""):gsub("%.Tests?$", ""):gsub("Tests?$", "")

    -- First pass: Find test projects with matching base name
    for _, proj in ipairs(project_files) do
      -- Only consider projects with "Test" in the name
      if (proj.name:match("Test") or proj.dir:match("Test")) and
         (proj.name:find(test_base, 1, true) or proj.dir:find(test_base, 1, true)) then
        return proj.path
      end
    end

    -- Second pass: Return any test project in sibling directories
    for _, proj in ipairs(project_files) do
      if proj.name:match("Test") or proj.dir:match("Test") then
        return proj.path
      end
    end

    -- Last resort: Return first project found (shouldn't happen for test files)
    return project_files[1].path
  end

  -- Fallback: use shell find command in parent directory
  local find_cmd = string.format('find "%s" -maxdepth 2 -name "*.csproj" -type f | head -1', parent_dir)
  local io_handle = io.popen(find_cmd)
  if io_handle then
    local result = io_handle:read("*a")
    io_handle:close()
    if result and result ~= "" then
      return vim.trim(result)
    end
  end

  return nil
end

---@param namespace string
---@param class_name string
---@param method_name string|nil
---@return string
local function generate_dotnet_filter(namespace, class_name, method_name)
  local fully_qualified = namespace .. "." .. class_name
  if method_name and method_name ~= "" and method_name ~= "ALL" then
    return string.format("FullyQualifiedName~%s.%s", fully_qualified, method_name)
  else
    return string.format("FullyQualifiedName~%s", fully_qualified)
  end
end

---@param project_path string
---@param filter string
---@return string
local function generate_dotnet_test_command(project_path, filter)
  return string.format('dotnet test "%s" --filter "%s" --logger "console;verbosity=detailed"', project_path, filter)
end

---@return overseer.TemplateDefinition
return {
  name = "Run DotNet Test",
  description = "Run dotnet test on current C# test file",
  builder = function(params)
    local filepath = vim.fn.expand("%:p")
    local content = get_file_content(filepath)
    local namespace = params.namespace or get_namespace(filepath, content)
    local class_name = params.class_name or get_class_name(filepath, content)
    local method_name = params.method_name

    -- Try to get project path from params first, then search
    local project_path = params.project_path
    if not project_path or project_path == "" then
      project_path = find_test_project(filepath)
    end

    if not project_path or project_path == "" then
      local dir_name = vim.fn.fnamemodify(vim.fn.fnamemodify(filepath, ":h"), ":t")
      local suggested_dir = dir_name:gsub("%.Tests?$", "") .. "UnitTests"

      vim.notify(
        string.format([[Could not find .csproj for: %s

Directory: %s

This test file is NOT part of any project!
Options:
  1. Move file to: ../%s/
  2. Add as <Compile Include="..\%s\%s" /> to a .csproj
  3. Manually enter project path below]],
          vim.fn.fnamemodify(filepath, ":t"),
          vim.fn.fnamemodify(filepath, ":h"),
          suggested_dir,
          dir_name,
          vim.fn.fnamemodify(filepath, ":t")),
        vim.log.levels.WARN
      )
      error("Could not find test project (.csproj) for file: " .. filepath)
    end

    local filter = generate_dotnet_filter(namespace, class_name, method_name)
    local dotnet_command = generate_dotnet_test_command(project_path, filter)
    local cwd = vim.fn.fnamemodify(project_path, ":h")

    vim.notify(
      string.format("Project: %s\nFilter: %s\nCWD: %s",
        vim.fn.fnamemodify(project_path, ":t"),
        filter,
        cwd),
      vim.log.levels.INFO
    )

    ---@type overseer.TaskDefinition
    return {
      cmd = dotnet_command,
      cwd = cwd,
    }
  end,
  --- @type overseer.Params|fun():overseer.Params
  params = function()
    local filepath = vim.fn.expand("%:p")
    local content = get_file_content(filepath)
    local namespace = get_namespace(filepath, content)
    local class_name = get_class_name(filepath, content)
    local project_path = find_test_project(filepath)

    -- Show warning if project not found
    if not project_path or project_path == "" then
      vim.notify(
        string.format("Warning: Could not find .csproj file.\nPlease enter the path manually in the 'Project Path' field."),
        vim.log.levels.WARN
      )
      project_path = ""
    end

    -- Extract test method names from the file (improved patterns)
    local test_methods = {}
    -- NUnit [Test] or [TestCase]
    for method in content:gmatch("%[Tests?%w*%].-public%s+%w+%s+(%w+)%s*%(") do
      table.insert(test_methods, method)
    end
    -- xUnit [Fact]
    for method in content:gmatch("%[Fact%].-public%s+%w+%s+(%w+)%s*%(") do
      table.insert(test_methods, method)
    end
    -- xUnit [Theory]
    for method in content:gmatch("%[Theory%].-public%s+%w+%s+(%w+)%s*%(") do
      table.insert(test_methods, method)
    end

    -- Remove duplicates
    local unique_methods = {}
    local seen = {}
    for _, method in ipairs(test_methods) do
      if not seen[method] then
        table.insert(unique_methods, method)
        seen[method] = true
      end
    end

    -- Add "ALL" option to run all tests in the class
    table.insert(unique_methods, 1, "ALL")

    local def_filter = generate_dotnet_filter(namespace, class_name, "ALL")
    local def_cmd = (project_path and project_path ~= "") and generate_dotnet_test_command(project_path, def_filter) or "No project file found"

    return {
      namespace = {
        type = "string",
        name = "Namespace",
        desc = "The namespace for the test",
        order = 1,
        default = namespace,
        optional = true,
      },
      class_name = {
        type = "string",
        name = "Class Name",
        desc = "The class name for the test",
        order = 2,
        default = class_name,
        optional = true,
      },
      method_name = {
        type = "enum",
        name = "Method Name",
        desc = "The test method to run (or ALL for entire class)",
        order = 3,
        choices = unique_methods,
        default = "ALL",
        optional = true,
      },
      project_path = {
        type = "string",
        name = "Project Path",
        desc = "Path to the .csproj file (required - will search if empty)",
        order = 4,
        default = project_path or "",
        optional = false,  -- Make it required so user must provide if not found
      },
      def_cmd = {
        type = "string",
        name = "Preview Command",
        desc = "Preview of the command to run",
        order = 5,
        default = def_cmd,
        optional = true,
      },
    }
  end,
  components = {
    { "on_complete_notify", system = "always" },
    "default",
  },
  priority = 5,
  condition = {
    filetypes = { "cs" },
    callback = function(task)
      -- Only activate for C# test files
      local filepath = vim.fn.expand("%:p")
      local filename = vim.fn.expand("%:t")

      -- Check if file is a test file (ends with Test.cs or Tests.cs)
      local isTestFile = filename:match("Tests?%.cs$")

      -- Check if file is in a test project directory
      local isInTestDir = filepath:match("UnitTests") or filepath:match("IntegrationTests") or filepath:match("Tests/")

      return isTestFile or isInTestDir
    end,
  },
}
