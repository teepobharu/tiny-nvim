--@return overseer.TemplateDefinition
return {
  name = "yarn test current file (cov) watch + update snap",
  description = "Run yarn test (jest) on the current file with specified options",
  builder = function(params)
    -- Detect package manager by searching for nearest package.json and reading its packageManager field.
    local file_name = vim.fn.expand("%")
    local start_dir = vim.fn.expand("%:p:h")
    local pkg_path = nil
    local pm = nil

    -- Find nearest package.json upwards from the current file
    local found = vim.fs.find({ "package.json" }, { upward = true, path = start_dir })
    print([==[builder found:]==], vim.inspect(found)) -- __AUTO_GENERATED_PRINT_VAR_END__
    if found and found[1] then
      pkg_path = found[1]
      -- Try to read packageManager field from package.json
      local ok, content = pcall(vim.fn.readfile, pkg_path)
      if ok and content then
        local json_text = table.concat(content, "\n")
        local success, tbl = pcall(vim.fn.json_decode, json_text)
        if success and type(tbl) == "table" and tbl.packageManager then
          local pm_field = tostring(tbl.packageManager)
          if pm_field:match("^pnpm") then
            pm = "pnpm"
          elseif pm_field:match("^yarn") then
            pm = "yarn"
          elseif pm_field:match("^npm") then
            pm = "npm"
          end
        end
      end
    end

    print([==[builder#if pm:]==], vim.inspect(pm)) -- __AUTO_GENERATED_PRINT_VAR_END__
    if not pm then
      -- __AUTO_GENERATED_PRINT_VAR_START__
      local lock = vim.fs.find({ "pnpm-lock.yaml", "yarn.lock", "package-lock.json" }, { upward = true, path = start_dir })
      if lock and lock[1] then
        if lock[1]:match("pnpm%-lock.yaml$") then
          pm = "pnpm"
          pkg_path = pkg_path or lock[1]
        elseif lock[1]:match("yarn%.lock$") then
          pm = "yarn"
          pkg_path = pkg_path or lock[1]
        elseif lock[1]:match("package%-lock%.json$") then
          pm = "npm"
          pkg_path = pkg_path or lock[1]
        end
      end
    end

    -- Default to yarn (preserve existing behavior) if detection fails
    if not pm then
      pm = "yarn"
    end

    -- Build the command based on detected package manager
    local cmd
    if pm == "pnpm" then
      cmd = "pnpm test " .. file_name .. " --watch -u --silent=false --coverage=false"
    elseif pm == "npm" then
      cmd = "npm test -- " .. file_name .. " --watch -u --coverage=false"
    else
      cmd = "yarn test " .. file_name .. " --watch -u --silence=false --coverage=false"
    end

    ---@type overseer.TaskDefinition
    return {
      cmd = cmd,
      cwd = pkg_path and vim.fn.fnamemodify(pkg_path, ":h") or vim.fn.getcwd(),
    }
  end,
  --- @type overseer.Params|fun():overseer.Params
  params = function()
    return {}
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
  priority = 5,
  condition = {
    filetypes = { "typescriptreact" , "typescript" }, -- Include test filetypes
    callback = function(task)
      local isTestFile = vim.fn.expand("%:t"):match("tests?%.tsx?$") or vim.fn.expand("%:t"):match("specs?%.tsx?$")
      if isTestFile then
        return true
      else
        return false
      end
    end,
  },
}
