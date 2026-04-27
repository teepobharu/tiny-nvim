local FiletypeConfigurations = {
  lua = {
    {
      name = "luafile",
      -- cmd = { "nvim", "--headless", "+luafile $file", "+q" },
      cmd = { "nvim", "--headless", "-c luafile $file", "+q" },
      prerequisite = "Neovim must be installed and in PATH",
      content_patterns = { "vim." }, -- Specific Bun patterns
      is_match_with_content_only = false,
      executable_check = "nvim",
      comment_syntax = "--",
    },
    {
      name = "lua",
      cmd = { "lua", "$file" },
      prerequisite = "lua must be installed and in PATH",
      executable_check = "lua",
      comment_syntax = "--",
    },
  },
  go = {
    {
      name = "go",
      cmd = { "go", "run", "$file" },
      prerequisite = "go must be installed and in PATH",
      executable_check = "go",
    },
  },
  python = {
    {
      name = "python",
      cmd = { "python", "$file" },
      prerequisite = "python must be installed and in PATH",
      executable_check = "python",
    },
  },
  perl = {
    {
      name = "perl",
      cmd = { "perl", "$file" },
      prerequisite = "perl must be installed and in PATH",
      executable_check = "perl",
    },
  },
  sh = {
    {
      name = "sh",
      cmd = { "sh", "$file" },
      prerequisite = "sh or bash must be installed and in PATH",
      executable_check = "sh",
      comment_syntax = "#", -- For shell scripts
    },
  },
  json = {
    {
      name = "jq",
      cmd = { "jq", ".", "$file" },
      prerequisite = "jq must be installed and in PATH",
      executable_check = "jq",
    },
  },
  cs = {
    {
      name = "dotnet-run-file",
      cmd = { "dotnet", "run", "$file" },
      prerequisite = ".NET 10+ SDK (single-file execution via run-file feature)",
      executable_check = "dotnet",
      comment_syntax = "//",
      content_patterns = { "#:package", "Console%." },
      is_match_with_content_only = false,
    },
    {
      name = "dotnet-script",
      cmd = { "dotnet", "script", "$file" },
      prerequisite = "dotnet-script tool (dotnet tool install -g dotnet-script)",
      executable_check = "dotnet",
      comment_syntax = "//",
    },
  },
  deno = {
    {
      name = "deno",
      cmd = { "deno", "run", "--allow-all", "$file" },
      prerequisite = "deno must be installed and in PATH",
      executable_check = "deno",
      comment_syntax = "//",
    },
  },
  javascript = {
    {
      name = "bun",
      cmd = { "bun", "$file" },
      prerequisite = "bun must be installed and in PATH",
      executable_check = "bun",
      comment_syntax = "//",
      content_patterns = { "Bun.serve", "Bun.file", 'from "bun"' }, -- Specific Bun patterns
      is_match_with_content_only = false,
    },
    {
      name = "deno",
      cmd = { "deno", "run", "--allow-all", "$file" },
      prerequisite = "deno must be installed and in PATH",
      executable_check = "deno",
      comment_syntax = "//",
      content_patterns = { "Deno%.", "import.*https://denoland" }, -- Specific Deno patterns
      is_match_with_content_only = false,
    },
    {
      name = "node",
      cmd = { "node", "$file" },
      prerequisite = "node must be installed and in PATH",
      executable_check = "node",
      comment_syntax = "//",
    },
  },
  typescript = {}, -- extend below
  -- Default/fallback for unknown filetypes
  default = {
    {
      name = "fallback",
      cmd = { "sh", "$file" },
      prerequisite = "sh or bash must be installed and in PATH (used as a generic fallback)",
      executable_check = "sh",
    },
  },
}

local shebang = require "utils.shebang"

FiletypeConfigurations.typescript = vim.list_extend(FiletypeConfigurations.javascript, {
  {
    name = "tsc",
    cmd = { "tsc", "$file" },
    prerequisite = "TSC must be installed and in PATH",
    executable_check = "tsc",
    comment_syntax = "//",
  },
})

local debg = require "utils.user_debug"
local dbg = debg.dbg
-- debg.on()

local function get_best_runner(file, ft)
  local shebang_info = shebang.detect(file)
  if shebang_info.has_shebang then
    return "shebang"
  end

  local candidates = FiletypeConfigurations[ft] or FiletypeConfigurations.default
  local best_score = -1
  local best_runner = nil

  for _, runner_def in ipairs(candidates) do
    local executable = runner_def.executable_check or runner_def.cmd[1]
    if vim.fn.executable(executable) == 1 then
      local content_patterns = runner_def.content_patterns or {}
      local content_match_required = #content_patterns > 0
      local match_count = 0
      local matched_lines = {}
      local has_content_match = not content_match_required

      if content_match_required then
        local content = vim.fn.readfile(file)
        for lineno, line in ipairs(content) do
          local code_part = line
          if runner_def.comment_syntax then
            local comment_start = string.find(line, runner_def.comment_syntax)
            if comment_start then
              code_part = string.sub(line, 1, comment_start - 1)
            end
          end

          for _, pattern in ipairs(content_patterns) do
            if string.find(code_part, pattern) then
              match_count = match_count + 1
              table.insert(matched_lines, { lineno = lineno, line = line, pattern = pattern })
              break
            end
          end
        end
        has_content_match = match_count > 0
      end

      print(vim.inspect {
        runner = runner_def.name,
        has_content_match = has_content_match,
        match_count = match_count,
        matched_lines = matched_lines,
      })

      local should_update_score = has_content_match or runner_def.is_match_with_content_only == false
      if should_update_score and match_count > best_score then
        best_score = match_count
        best_runner = runner_def.name
      end
    end
  end

  -- For debug: store best_matches somewhere if needed, e.g., vim.g.last_runner_matches = best_matches
  dbg([==[get_best_runner best_runner:]==], vim.inspect(best_runner)) -- __AUTO_GENERATED_PRINT_VAR_END__
  return best_runner
end

local get_runner_by_ft_and_name = function(ft, name)
  local candidates = FiletypeConfigurations[ft] or FiletypeConfigurations.default
  for _, runner_def in ipairs(candidates) do
    if runner_def.name == name then
      return runner_def
    end
  end
  return nil
end

local function append_unique(tbl, value)
  for _, item in ipairs(tbl) do
    if item == value then
      return
    end
  end
  table.insert(tbl, value)
end

local function normalize_runner_name(name)
  return (name or ""):gsub(" %(not executable%)$", "")
end

local function resolve_command(file, ft, runner_name)
  local normalized_runner_name = normalize_runner_name(runner_name)

  if normalized_runner_name == "shebang" then
    return shebang.build_exec_cmd(file)
  end

  local runner = get_runner_by_ft_and_name(ft, normalized_runner_name)
  local cmd = runner and runner.cmd or { ft, file }
  return vim.tbl_map(function(part)
    return part:gsub("%$file", file)
  end, cmd)
end

return {
  name = "run script - deterministic",
  tags = { require("overseer").TAG.RUN, "run", "custom" },
  builder = function(params)
    -- __AUTO_GENERATED_PRINT_VAR_START__
    dbg([==[builder params:]==], vim.inspect(params)) -- __AUTO_GENERATED_PRINT_VAR_END__
    -- local file = vim.fn.expand "%:p"
    -- local ft = vim.bo.filetype
    local file = params.file
    local ft = vim.bo.filetype
    local cmd = resolve_command(file, ft, params.chosen_runner) or { "sh", file }

    -- local final_cmd_table, runner_name, prerequisite = params.get_resolved_command_info(file, ft)
    return {
      cmd = cmd,
      components = {
        { "on_output_quickfix", set_diagnostics = true },
        { "open_output", on_start = "always", direction = "dock", focus = false },
        { "on_permission_error", auto_chmod = false },
        "default",
      },
    }
  end,
  params = function()
    -- Notes: do not remove
    -- Define configurations for each filetype, including ordered runners and their specific logic
    -- Helper to get the resolved command and info
    -- show alternatives runner in case want to change for that filetypes  from the config as string of the key name
    -- params 1 show : ie { deno, bun ,  } if that file type  capable of multiple runners
    -- params 2: resolved runner  name deno
    -- params 3: current resolved runner command
    -- params 4: current resolved runner file
    -- once enter  if user choose difference runner in params 1 from resolve params 2 then put warning text that commadn will be run with `newrunnercmd $actualfilepath`
    -- // TODO:
    -- support json and configuration runner ie jq with added parameters
    -- choices = {  { final_cmd = "" }}
    local file = vim.fn.expand "%:p"
    -- __AUTO_GENERATED_PRINT_VAR_START__
    print([==[params file:]==], vim.inspect(file)) -- __AUTO_GENERATED_PRINT_VAR_END__
    -- __AUTO_GENERATED_PRINT_VAR_START__
    local ft = vim.bo.filetype
    print([==[params file:]==], vim.inspect { file, ft }) -- __AUTO_GENERATED_PRINT_VAR_END__
    local choicesRunnerForFt = {}
    local candidates = FiletypeConfigurations[ft] or FiletypeConfigurations.default
    -- append (not executable in runner name if not executable as a label)
    for _, runner_def in ipairs(candidates) do
      local executable = runner_def.executable_check or (runner_def.cmd and runner_def.cmd[1])
      if executable and vim.fn.executable(executable) == 1 then
        table.insert(choicesRunnerForFt, runner_def.name)
      else
        table.insert(choicesRunnerForFt, runner_def.name .. " (not executable)")
      end
    end

    dbg([==[params#for#if choicesRunnerForFt:]==], vim.inspect(choicesRunnerForFt)) -- __AUTO_GENERATED_PRINT_VAR_END__
    -- sort by executable first
    -- todo : count mathces content and add score on the choicesRunnerForFt
    -- runner scope tables
    table.sort(choicesRunnerForFt, function(a, b)
      local a_exec = not string.find(a, " %(not executable%)")
      local b_exec = not string.find(b, " %(not executable%)")
      if a_exec ~= b_exec then
        return a_exec -- executable first
      else
        return a < b -- then alphabetically
      end
    end)

    -- Always offer shebang as a runner choice if file has one
    local shebang_info = shebang.detect(file)
    if shebang_info.has_shebang then
      table.insert(choicesRunnerForFt, 1, "shebang")
    end

    append_unique(choicesRunnerForFt, FiletypeConfigurations.default[1].name)
    append_unique(choicesRunnerForFt, ft)

    dbg([==[params choicesRunnerForFt:]==], vim.inspect(choicesRunnerForFt)) -- __AUTO_GENERATED_PRINT_VAR_END__

    local resolved_runner_name = get_best_runner(file, ft) or FiletypeConfigurations.default[1].name
    dbg([==[params resolved_runner_name:]==], vim.inspect(resolved_runner_name)) -- __AUTO_GENERATED_PRINT_VAR_END__
    local command = resolve_command(file, ft, resolved_runner_name)
    local commandString = command and vim.fn.join(command, " ") or ""

    -- change to relative filepath
    file = vim.fn.fnamemodify(file, ":.")

    return {
      chosen_runner = {
        type = "enum", -- list without description
        name = "command",
        desc = "runner name <C-x><C-o> to see available runners",
        order = 1,
        choices = choicesRunnerForFt,
        default = resolved_runner_name,
        optional = false,
      },
      command = {
        type = "string",
        name = "resolved runner command",
        desc = "command to run <readonly>",
        order = 2,
        default = commandString,
        optional = true,
      },
      file = {
        type = "string",
        name = "user runner choice",
        desc = "file name <C-x><C-o> to see available runners for ",
        order = 3,
        default = file,
        optional = true,
      },
      meta = {
        optional = true,
        default = { a = 1, b = 2 },
      },
    }
  end,
  -- condition = {
  -- filetype = { "sh", "python", "go", "lua" },
  -- },
}
