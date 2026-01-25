---@param filepath string
---@param content string
---@return string
local function get_package_name(filepath, content)
  -- Extract the package name from the file content
  local package_name = content:match "package%s+([%w%.]+)"
  if not package_name then
    error("Package name not found in file: " .. filepath)
  end
  return package_name
end

---@param filepath string
---@return string
local function get_file_content(filepath)
  print([==[get_file_content filepath:]==], vim.inspect(filepath)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local file = io.open(filepath, "r")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  if not file then
    error("Could not open file: " .. filepath)
  end
  local content = file:read "*all"
  file:close()
  return content
end

---@param filepath string
---@param content string
---@return string
local function get_class_name(filepath, content)
  local class_name = content:match "class%s+([%w_]+)"
  if not class_name then
    -- Fall back to using the file name if class name is not found
    -- presentation/legacy-navigation/src/test/kotlin/com/agoda/mobile/consumer/screens/home/BottomNavPageMapperImplTest.kt
    -- to get the class name BottomNavPageMapperImplTest
    class_name = filepath:match "([^/]+)%.kt$"
  end
  return class_name
end

---@param filepath string
---@return string
local function get_module(filepath)
  -- __AUTO_GENERATED_PRINT_VAR_START__
  -- FIX: m2 = "myzxc-zxc/asdzxc/test/zxc/ag"
  -- local mmpatht = "/Users/tharutaipree/AgodaGit/fe/client-android/presentation/legacy-navigation/src/test/taga/framework/src/main/kotlin/com/agoda/mobile/taga/Store.kt"
  -- print(mmpatht:match("([^/]+)test"))
  -- print(m2:match("([^/]+)/test"))
  -- local module = filepath:match("^(.-)/src/test/")
  -- if module and not module:match("^android%-client") then module = ":" .. module:gsub("/", ":") end

  -- Extract the module from the path
  -- expected to be :presentation:legacy-navigation
  -- presentation/legacy-navigation/src/test/kotlin/com/agoda/mobile/consumer/screens/home/BottomNavPageMapperImplTest.kt
  -- local relpath = vim.fn.expand("%:p:h")
  print([==[get_module filepath:]==], vim.inspect(filepath)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local gitroot = require("utils.path").get_git_root()
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[get_module gitroot:]==], vim.inspect(gitroot)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local relpath = filepath:gsub(vim.pesc(gitroot) .. "/?", "")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[get_module relpath:]==], vim.inspect(relpath)) -- __AUTO_GENERATED_PRINT_VAR_END__

  -- local module = relpath:match("([^/]+)/([^/]+)/src/test/")
  local module = relpath:match "(.*)/src/test/"
  print([==[get_module module:]==], vim.inspect(module)) -- __AUTO_GENERATED_PRINT_VAR_END__
  if module then
    module = ":" .. module:gsub("/", ":")
  else
    error("Module not found in file: " .. filepath)
  end
  return module
end

local function generate_gradle_test_command(filepath)
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[generate_gradle_test_command filepath:]==], vim.inspect(filepath)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local file = io.open(filepath, "r")
  if not file then
    error("Could not open file: " .. filepath)
  end
  local content = file:read "*all"
  file:close()

  -- Extract the package name from the file content
  local package_name = content:match "package%s+([%w%.]+)"
  if not package_name then
    error("Package name not found in file: " .. filepath)
  end

  -- Extract the class name from the file content
  -- Extract the module from the path
  local module = filepath:match "([^/]+)/([^/]+)/src/test/"
  module = ":" .. module:gsub("/", ":")
  -- presentation/legacy-navigation/src/test/kotlin/com/agoda/mobile/consumer/screens/home/BottomNavPageMapperImplTest.kt
  -- kotlin
  -- to get the module :presentation:legacy-navigation

  -- Construct the command
  local gradle_command =
    string.format("./gradlew %s:testBaidumapDebugUnitTest --tests %s.%s", module, package_name, class_name)

  -- Return the command
  return gradle_command
end
-- ./gradlew :presentation:legacy-navigation:testBaidumapDebugUnitTest, --tests, com.agoda.mobile.consumer.screens.home.BottomNavPageMapperImplTest

local function generate_test_command(module, test_module, package_name, class_name)
  class_name = class_name == "ALL" and "" or class_name
  if class_name and class_name ~= "" then
    return string.format('./gradlew %s:%s --tests "%s.%s"', module, test_module, package_name, class_name)
  else
    return string.format("./gradlew %s:%s", module, test_module)
  end
end
-- path of test is in presentation/legacy-navigation/src/test/kotlin/com/agoda/mobile/consumer/screens/home/BottomNavPageMapperImplTest.kt
-- The command to run the test is ./gradlew :presentation:legacy-navigation:testBaidumapDebugUnitTest --tests com.agoda.mobile.consumer.screens.home.BottomNavPageMapperImplTest
--
-- Try to run the test on the current file ie.
local function generate_gradle_command1()
  -- Define the module and task
  local module = ":presentation:legacy-navigation"
  local task = "testBaidumapDebugUnitTest"

  -- Extract the package and class name from the current file
  local package_name = "com.agoda.mobile.consumer.screens.home"
  local class_name = "BottomNavPageMapperImplTest"

  -- Construct the command
  local gradle_command = string.format("./gradlew %s:%s --tests %s.%s", module, task, package_name, class_name)

  -- Return the command
  return gradle_command
end

---@return overseer.TemplateDefinition
return {
  name = "Run Android test",
  description = "run android test on current file",
  tags = { "agoda", "custom", require("overseer").TAG.TEST, require("overseer").TAG.RUN },
  builder = function(params)
    local current_file = vim.fn.expand "%:p"
    local match = current_file:match "src/test/"
    if not match then
      error("This template only works for test files in src/test/. Current file: " .. current_file)
    end

    -- FIX: 20250402 20250402
    -- 02:43:36 msg_show E5108: Error executing lua: .../lua/overseer/template/agoda/android_client/and_test.lua:17: bad argument #1 to 'open' (string expected, got nil)
    -- stack traceback:
    -- 	[C]: in function 'open'
    -- 	.../lua/overseer/template/agoda/android_client/and_test.lua:17: in function 'get_file_content'
    -- 	.../lua/overseer/template/agoda/android_client/and_test.lua:108: in function 'builder'
    -- 	...igrate/lazy/overseer.nvim/lua/overseer/template/init.lua:251: in function 'build_task_args'

    local filepath = vim.fn.expand "%:p"
    local content = get_file_content(filepath)
    local package_name = params.package_name or get_package_name(filepath, content)
    -- local class_name = params.class_name == "ALL" and "" or params.class_name
    local module = params.module or get_module(filepath)

    -- Construct the command
    if module:find "legacy%-navigation" and params.test_module ~= "testBaidumapDebugUnitTest" then
      vim.notify(
        string.format("Replacing params.test_module with '%s' for legacy-navigation module", params.test_module),
        vim.log.levels.WARN
      )
      params.test_module = "testBaidumapDebugUnitTest"
    end
    vim.notify(string.format("Using params.test_module: '%s'", params.test_module), vim.log.levels.INFO)
    local gradle_command = generate_test_command(module, params.test_module, package_name, params.class_name)

    print([==[builder gradle_command:]==], vim.inspect(gradle_command)) -- __AUTO_GENERATED_PRINT_VAR_END__

    -- ./gradlew :presentation:legacy-navigation:testBaidumapDebugUnitTest, --tests, com.agoda.mobile.consumer.screens.home.BottomNavPageMapperImplTest
    -- ./gradlew :presentation:legacy-navigation --tests com.agoda.mobile.consumer.screens.home.BottomNavPageMapperImplTest
    -- path of test is in presentation/legacy-navigation/src/test/kotlin/com/agoda/mobile/consumer/screens/home/BottomNavPageMapperImplTest.kt
    -- The command to run the test is ./gradlew :presentation:legacy-navigation:testBaidumapDebugUnitTest --tests com.agoda.mobile.consumer.screens.home.BottomNavPageMapperImplTest
    ---@type overseer.TaskDefinition
    return {
      cmd = gradle_command,
    }
  end,
  --- @type overseer.Params|fun():overseer.Params
  params = function()
    Snacks.debug "params"
    local filepath = vim.fn.expand "%:p"
    local content = get_file_content(filepath)
    local module = get_module(filepath)
    local package_name = get_package_name(filepath, content)
    local class_name = get_class_name(filepath, content)
    local test_module = "testDebugUnitTest"
    Snacks.debug(class_name)
    if module:find "legacy%-navigation" and test_module ~= "testBaidumapDebugUnitTest" then
      test_module = "testBaidumapDebugUnitTest"
    end

    local classname_choices = {
      class_name,
      "*",
      "ALL",
    }
    local classname_choices_with_num_prefix = {}
    -- start from 1
    for i, name in ipairs(classname_choices) do
      table.insert(classname_choices_with_num_prefix, string.format("%d. %s", i, name))
    end
    vim.list_extend({ "Select class name to run test:" }, classname_choices_with_num_prefix)
    table.insert(classname_choices_with_num_prefix, "")
    local classname_selection = vim.fn.inputlist(classname_choices_with_num_prefix)
    if classname_selection > 0 and classname_selection <= #classname_choices then
      class_name = classname_choices[classname_selection]
    end
    print([==[classname_selection, class_name:]==], classname_selection, vim.inspect(class_name)) -- __AUTO_GENERATED_PRINT_VAR_END__

    local def_final_cmd = generate_test_command(module, test_module, package_name, class_name)
    return {
      package_name = {
        type = "string",
        name = "Package Name",
        desc = "The package name for the test",
        order = 1,
        default = package_name,
        optional = true,
      },
      name = {
        type = "enum",
        name = "Class Name.TestName",
        desc = "The class name for the test",
        order = 2,
        choices = classname_choices,
        validate = function(value)
          return true
        end,
        default = class_name,
        optional = true,
      },
      module = {
        type = "string",
        name = "Module",
        desc = "The module for the test",
        order = 3,
        default = module,
        optional = true,
      },
      test_module = {
        type = "enum",
        name = "test module command",
        desc = "Select test module command",
        order = 5,
        choices = {
          "testBaidumapDebugUnitTest",
          "testDebugUnitTest",
        },
        validate = function(value)
          return true
        end,
        default = test_module,
        -- optional = false, -- make non optional to see modal before run
        optional = true,
      },
      def_final_cmd = {
        type = "string",
        name = "final command",
        desc = "Preview of command",
        order = 6,
        validate = function(value)
          return true
        end,
        default = def_final_cmd,
        optional = true,
      },
    }
  end,
  components = {
    -- {
    -- "on_output_quickfix", -- will output to quickfix
    -- errorformat = vim.o.grepformat,
    -- open = true,
    -- open = not params.bang,
    -- open_height = 8,
    -- items_only = true,
    -- },
    -- We don't care to keep this around as long as most tasks
    -- { "on_complete_dispose", timeout = 30 },
    { "on_complete_notify", system = "always" },
    "default",
  },
  condition = {
    filetype = { "kotlin" },
    -- Note: v2 removed condition callbacks - validation moved to builder
  },
}
