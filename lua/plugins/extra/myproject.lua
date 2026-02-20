local M = {}
local path_utils = require "utils.path"

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
  local cmd = string.format(
    "deno run --allow-read %s 2>/dev/null",
    script_path
  )
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
    '  // OpenCode configuration - https://opencode.ai/docs/config',
    '  "$schema": "https://opencode.ai/config.json",',
    '  ',
    '  // Control which actions require approval',
    '  // Learn more: https://opencode.ai/docs/permissions',
    '  "permission": {',
    '    "bash": {',
    '      "*": "ask",           // Ask before running shell commands',
    '      "git *": "allow",     // Allow git commands',
    '      "npm *": "allow",     // Allow npm commands',
    '      "rm *": "deny"        // Deny dangerous rm commands',
    '    },',
    '    "edit": "ask",          // Ask before editing files',
    '    "external_directory": { // Control access outside project',
    '      "~/projects/**": "allow"',
    '    }',
    '  }',
    '}',
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
            "Merged configuration with existing "
              .. vim.fn.fnamemodify(existing_file, ":t"),
            vim.log.levels.INFO
          )
        end
      end
    else
      vim.notify(
        "Could not parse existing config. Using new config instead.",
        vim.log.levels.WARN
      )
    end
  end

  -- Write to opencode.jsonc
  local file = io.open(target_path, "w")
  if file then
    file:write(final_content .. "\n")
    file:close()
    vim.notify(
      "Created/updated " .. target_path,
      vim.log.levels.INFO
    )
    
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
    vim.ui.select(
      { "merge", "replace", "cancel" },
      {
        prompt = "opencode config exists at " .. existing_file .. ". Choose action: ",
      },
      function(action)
        if not action or action == "cancel" then
          return
        end

        -- Generate and write config
        write_config(git_root, action, existing_file)
      end
    )
  else
    -- No existing file, proceed directly
    write_config(git_root, "replace", nil)
  end
end

function M.setup()
  vim.api.nvim_create_user_command("OpenCodeInit", create_opencode_config, {
    desc = "Create opencode.jsonc with prepopulated permissions",
  })
end

return M
