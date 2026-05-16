local M = {}
local path_utils = require "utils.path"
local mypath = require "utils.mypath"
local csharp_lsp_installer = require "utils.csharp_lsp_installer"

-- ═══════════════════════════════════════════════════════════════════════════════
-- .nvim-config.lua marker-based template system
-- Embeds a commented-out copy of mydefault-nvim-config.lua between markers so
-- users can see available defaults and uncomment/override per-project.
-- ═══════════════════════════════════════════════════════════════════════════════

local MARKER_START =
  "-- ──── NVIM DEFAULT CONFIG REFERENCE (auto-generated) DO NOT EDIT BETWEEN MARKERS ────"
local MARKER_END = "-- ──── END NVIM DEFAULT CONFIG REFERENCE ────"

--- Read mydefault-nvim-config.lua and return its content commented out, wrapped in markers
---@return string|nil reference_block The full marker block, or nil on error
local function get_default_config_reference()
  local config_path = vim.fn.stdpath "config" .. "/lua/config/mydefault-nvim-config.lua"
  local f = io.open(config_path, "r")
  if not f then
    return nil
  end

  local existing_config_newlines = {}
  for line in f:lines() do
    -- TODO: do not enforce this yet since might require re update every time when not comment
    -- if line:find "**disableInit" then
    table.insert(existing_config_newlines, "-- " .. line)
    -- else
    --   table.insert(existing_config_newlines, line)
    -- end
  end
  f:close()

  local config_display = config_path:gsub(vim.env.HOME, "~")
  local header = {
    MARKER_START,
    "-- Source: " .. config_display,
    "-- Regenerated: " .. os.date "%Y-%m-%d" .. " | Run :ProjectSettingsReload to refresh",
    "-- Uncomment and modify values below to override defaults for this project.",
    "--",
  }
  local footer = { MARKER_END }

  local result = {}
  vim.list_extend(result, header)
  vim.list_extend(result, existing_config_newlines)
  vim.list_extend(result, footer)
  return table.concat(result, "\n")
end

--- Embed or replace the reference block in existing file content
---@param existing_content string|nil Current file content (nil for new file)
---@param reference_block string The marker block to embed
---@return string new_content The updated file content
local function embed_reference_in_content(existing_content, reference_block)
  -- New file: reference block + template for user overrides
  if not existing_content or existing_content == "" then
    return reference_block
      .. "\n\n"
      .. "-- Project-specific overrides below\n"
      .. "-- mono: <- set the label to show (mono:label) in files/grep subproject picker here\n"
      .. "-- vim.g.subproject_scan_ignored = false -- disable subproject scanning in snacks file/grep picker\n"
  end

  -- Find marker positions in existing content
  local start_pos = existing_content:find(MARKER_START, 1, true)
  local end_pos = existing_content:find(MARKER_END, 1, true)

  if start_pos and end_pos then
    -- Both markers found: replace content between them, preserve before/after
    local before = existing_content:sub(1, start_pos - 1)
    local end_of_marker = end_pos + #MARKER_END
    -- Skip trailing newline after end marker if present
    if existing_content:sub(end_of_marker, end_of_marker) == "\n" then
      end_of_marker = end_of_marker + 1
    end
    local after = existing_content:sub(end_of_marker)
    return before .. reference_block .. "\n" .. after
  else
    -- No markers found (old-style file): prepend reference block, preserve old content below
    return reference_block .. "\n\n" .. existing_content
  end
end

--- Write .nvim-config.lua with embedded default config reference
---@param filepath string Path to .nvim-config.lua
---@return boolean success
local function write_nvim_config_with_markers(filepath)
  local ref_block = get_default_config_reference()
  if not ref_block then
    vim.notify("Could not read mydefault-nvim-config.lua", vim.log.levels.ERROR)
    return false
  end

  -- Read existing content if file exists
  local existing = nil
  local f = io.open(filepath, "r")
  if f then
    existing = f:read "*a"
    f:close()
  end

  local new_content = embed_reference_in_content(existing, ref_block)

  local out = io.open(filepath, "w")
  if not out then
    vim.notify("Failed to write " .. filepath, vim.log.levels.ERROR)
    return false
  end
  out:write(new_content)
  out:close()
  return true
end

local function parse_jsonc_with_deno(file_path)
  -- Create a temporary file for deno script
  local script_path = "/tmp/parse_jsonc_" .. math.random(100000, 999999) .. ".js"
  local script_content = string.format(
    [[import { parse } from "jsr:@std/jsonc@1";
const content = await Deno.readTextFile("%s");
const result = parse(content);
console.log(JSON.stringify(result));]],
    file_path
  )

  -- Write script to temp file
  local script_file = io.open(script_path, "w")
  if not script_file then
    return nil
  end
  script_file:write(script_content)
  script_file:close()

  -- Execute deno script
  local cmd = string.format("deno run --allow-read %s 2>/dev/null", script_path)
  local handle = io.popen(cmd)
  if not handle then
    os.remove(script_path)
    return nil
  end

  local output = handle:read "*a"
  handle:close()
  os.remove(script_path)

  if output == "" or not output then
    return nil
  end

  -- Remove any trailing newlines
  output = output:gsub("\n$", "")

  -- Decode JSON
  local ok, result = pcall(vim.json.decode, output)
  if ok then
    return result
  end

  return nil
end

local function merge_configs(existing, new)
  -- Deep merge new config into existing config
  local function deep_merge(t1, t2)
    for k, v in pairs(t2) do
      if type(v) == "table" and type(t1[k]) == "table" then
        deep_merge(t1[k], v)
      else
        t1[k] = v
      end
    end
    return t1
  end

  return deep_merge(existing, new)
end

local function generate_opencode_jsonc()
  -- Generate JSONC content with comments and prepopulated config
  local jsonc_lines = {
    "{",
    "  // OpenCode configuration - https://opencode.ai/docs/config",
    '  "$schema": "https://opencode.ai/config.json",',
    "  ",
    "  // Control which actions require approval",
    "  // Learn more: https://opencode.ai/docs/permissions",
    '  "permission": {',
    '    "bash": {',
    '      "*": "ask",           // Ask before running shell commands',
    '      "git *": "allow",     // Allow git commands',
    '      "npm *": "allow",     // Allow npm commands',
    '      "rm *": "deny"        // Deny dangerous rm commands',
    "    },",
    '    "edit": "ask",          // Ask before editing files',
    '    "external_directory": { // Control access outside project',
    '      "~/projects/**": "allow"',
    "    }",
    "  }",
    "}",
  }

  return table.concat(jsonc_lines, "\n")
end

local function write_config(git_root, action, existing_file)
  local new_config_str = generate_opencode_jsonc()
  local target_path = git_root .. "/opencode.jsonc"

  local final_content = new_config_str

  -- Handle merge if requested and existing file exists
  if action == "merge" and existing_file then
    local existing_config = parse_jsonc_with_deno(existing_file)
    if existing_config then
      -- Parse the new config JSONC to get JSON object
      local temp_path = "/tmp/new_opencode_" .. math.random(100000, 999999) .. ".jsonc"
      local temp_file = io.open(temp_path, "w")
      if temp_file then
        temp_file:write(new_config_str)
        temp_file:close()

        local new_config = parse_jsonc_with_deno(temp_path)
        os.remove(temp_path)

        if new_config then
          local merged = merge_configs(existing_config, new_config)

          -- Convert merged config back to JSONC with comments
          local merged_json = vim.json.encode(merged)
          local function pretty_json(json_str)
            local indent = 0
            local result = ""
            local in_string = false
            local escape_next = false

            for i = 1, #json_str do
              local char = json_str:sub(i, i)
              local next_char = json_str:sub(i + 1, i + 1)

              if escape_next then
                result = result .. char
                escape_next = false
              elseif char == "\\" and in_string then
                result = result .. char
                escape_next = true
              elseif char == '"' then
                result = result .. char
                in_string = not in_string
              elseif not in_string then
                if char == "{" or char == "[" then
                  result = result .. char
                  indent = indent + 1
                  if next_char ~= "}" and next_char ~= "]" then
                    result = result .. "\n" .. string.rep("  ", indent)
                  end
                elseif char == "}" or char == "]" then
                  if json_str:sub(i - 1, i - 1) ~= "{" and json_str:sub(i - 1, i - 1) ~= "[" then
                    indent = indent - 1
                    result = result .. "\n" .. string.rep("  ", indent)
                  else
                    indent = indent - 1
                  end
                  result = result .. char
                elseif char == "," then
                  result = result .. char
                  result = result .. "\n" .. string.rep("  ", indent)
                elseif char == ":" then
                  result = result .. char .. " "
                elseif char ~= " " then
                  result = result .. char
                end
              else
                result = result .. char
              end
            end

            return result
          end

          final_content = pretty_json(merged_json)
          vim.notify(
            "Merged configuration with existing " .. vim.fn.fnamemodify(existing_file, ":t"),
            vim.log.levels.INFO
          )
        end
      end
    else
      vim.notify("Could not parse existing config. Using new config instead.", vim.log.levels.WARN)
    end
  end

  -- Write to opencode.jsonc
  local file = io.open(target_path, "w")
  if file then
    file:write(final_content .. "\n")
    file:close()
    vim.notify("Created/updated " .. target_path, vim.log.levels.INFO)

    -- Open the file in current buffer
    vim.cmd("edit " .. vim.fn.fnameescape(target_path))
  else
    vim.notify("Failed to create opencode.jsonc", vim.log.levels.ERROR)
  end
end

local function create_opencode_config()
  -- Get git root directory
  local git_root = path_utils.get_root_directory()
  if not git_root then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return
  end

  -- Get project name from git root path
  local project_name = git_root:match "([^/]+)$" or "my-project"

  -- Check if opencode config files already exist
  local jsonc_path = git_root .. "/opencode.jsonc"
  local json_path = git_root .. "/opencode.json"
  local existing_file = nil
  local has_existing = false

  if vim.fn.filereadable(jsonc_path) == 1 then
    existing_file = jsonc_path
    has_existing = true
  elseif vim.fn.filereadable(json_path) == 1 then
    existing_file = json_path
    has_existing = true
  end

  -- If existing file found, ask user about merge/replace
  if has_existing then
    vim.ui.select({ "merge", "replace", "cancel" }, {
      prompt = "opencode config exists at " .. existing_file .. ". Choose action: ",
    }, function(action)
      if not action or action == "cancel" then
        return
      end

      -- Generate and write config
      write_config(git_root, action, existing_file)
    end)
  else
    -- No existing file, proceed directly
    write_config(git_root, "replace", nil)
  end
end

function M.setup()
  vim.api.nvim_create_user_command("OpenCodeInit", create_opencode_config, {
    desc = "Create opencode.jsonc with prepopulated permissions",
  })

  vim.api.nvim_create_user_command("ProjectIgnore", function()
    local cwd = mypath.get_cwd()
    mypath.open_project_ignore(cwd)
  end, {
    desc = "Create/open .ignore in cwd with initial project ignore rules",
  })

  -- Override upstream's :ProjectSettings with marker-based template
  -- This runs after utils/project.lua setup(), so it overwrites the upstream command
  vim.api.nvim_create_user_command("ProjectSettings", function()
    local filepath = vim.fn.getcwd() .. "/.nvim-config.lua"
    local is_update = vim.loop.fs_stat(filepath) ~= nil

    if not write_nvim_config_with_markers(filepath) then
      return
    end

    local action = is_update and "Updated" or "Created"
    vim.notify(action .. " .nvim-config.lua with default config reference", vim.log.levels.INFO)

    -- Open the file (moved from utils/project.lua)
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))

    -- Open .ignore in vsplit (moved from utils/project.lua)
    local ok_mp, mp = pcall(require, "utils.mypath")
    if ok_mp and type(mp.open_project_ignore) == "function" then
      vim.cmd "vsplit"
      mp.open_project_ignore(vim.fn.getcwd())
    end
  end, {
    desc = "Create/update .nvim-config.lua with default config reference template",
  })

  vim.api.nvim_create_user_command("ProjectSettingsReload", function()
    local cwd, cwd_display = mypath.get_cwd()
    local project_setting = cwd .. "/.nvim-config.lua"

    local function confirm(prompt, on_choice)
      if vim.ui and type(vim.ui.confirm) == "function" then
        vim.ui.confirm(prompt, on_choice)
        return
      end

      vim.ui.select({ "Yes", "No" }, { prompt = prompt }, function(choice)
        if choice == "Yes" then
          on_choice(1)
        else
          on_choice(0)
        end
      end)
    end

    if vim.loop.fs_stat(project_setting) then
      confirm(("Regenerate reference & reload project settings?\n file:%s"):format(project_setting), function(choice)
        if choice == 1 then
          -- Regenerate marker block before reloading
          write_nvim_config_with_markers(project_setting)
          -- Reload the buffer to show updated content
          vim.cmd("edit " .. vim.fn.fnameescape(project_setting))
          -- Execute the file to apply settings
          local ok, err = pcall(dofile, project_setting)
          if ok then
            vim.notify("Regenerated reference & reloaded settings from " .. project_setting, vim.log.levels.INFO)
          else
            vim.notify("Error loading project setting: " .. tostring(err), vim.log.levels.ERROR)
          end
        end
      end)
      return
    end

    confirm((".nvim-config.lua not found.\n\ncwd:\n%s\n\nCreate it now?"):format(cwd_display), function(choice)
      if choice ~= 1 then
        return
      end
      vim.cmd "ProjectSettings"
    end)
  end, {
    desc = "Regenerate default config reference and reload .nvim-config.lua",
  })

  vim.api.nvim_create_user_command("CSharpLspInstallInfo", function()
    csharp_lsp_installer.show_install_info()
  end, {
    desc = "Show OmniSharp install/upgrade plan",
  })

  vim.api.nvim_create_user_command("CSharpLspInstall", function()
    csharp_lsp_installer.install_latest()
  end, {
    desc = "Install OmniSharp from latest release (with confirmation)",
  })

  vim.api.nvim_create_user_command("CSharpLspUpgrade", function()
    csharp_lsp_installer.upgrade_latest()
  end, {
    desc = "Upgrade OmniSharp to latest release (with confirmation)",
  })

  vim.api.nvim_create_user_command("CSharpLspOpenReleases", function()
    csharp_lsp_installer.open_releases_page()
  end, {
    desc = "Open OmniSharp releases page",
  })
end

return M
