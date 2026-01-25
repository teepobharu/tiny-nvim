--@return overseer.TemplateDefinition
return {
  name = "yarn test current file (cov) watch + update snap",
  tags = { require("overseer").TAG.TEST, "agoda", "custom" },
  description = "Run yarn test (jest) on the current file with specified options",
  builder = function(params)
    -- v2: Validation moved from condition callback
    local current_file = vim.fn.expand "%:t"
    local is_test_file = current_file:match "tests?%.tsx?$" or current_file:match "specs?%.tsx?$"
    if not is_test_file then
      error("This template only works for test files (*.test.tsx, *.spec.ts, etc.). Current file: " .. current_file)
    end

    -- Detect package manager by searching for nearest package.json and reading its packageManager field.
    local file_name = vim.fn.expand "%"
    local start_dir = vim.fn.expand "%:p:h"
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
          if pm_field:match "^pnpm" then
            pm = "pnpm"
          elseif pm_field:match "^yarn" then
            pm = "yarn"
          elseif pm_field:match "^npm" then
            pm = "npm"
          end
        end
      end
    end

    print([==[builder#if pm:]==], vim.inspect(pm)) -- __AUTO_GENERATED_PRINT_VAR_END__
    if not pm then
      -- __AUTO_GENERATED_PRINT_VAR_START__
      local lock = vim.fs.find(
        { "pnpm-lock.yaml", "yarn.lock", "package-lock.json" },
        { upward = true, path = start_dir }
      )
      if lock and lock[1] then
        if lock[1]:match "pnpm%-lock.yaml$" then
          pm = "pnpm"
          pkg_path = pkg_path or lock[1]
        elseif lock[1]:match "yarn%.lock$" then
          pm = "yarn"
          pkg_path = pkg_path or lock[1]
        elseif lock[1]:match "package%-lock%.json$" then
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
    {
      "on_output_parse",
      parser = function(line)
        local file = line:match "^%s+FAIL%s+(.+)$"
        if file then
          print([==[parser file:]==], vim.inspect(file)) -- __AUTO_GENERATED_PRINT_VAR_END__
          return {
            filename = file,
            lnum = 1,
            text = "Failed test file",
            type = "E",
          }
        end
        -- sample
        --       at Object.<anonymous> (src/common/textUtils.test.tsx:15:60)
        -- Regex explanation:
        -- ^%s*at Object%.<anonymous>%s*%((.-):(%d+):(%d+)%):
        --   ^%s*         : Start of line, optional whitespace
        --   at Object%.<anonymous> : Literal match for 'at Object.<anonymous>'
        --   %s*          : Optional whitespace
        --   %(           : Literal '('
        --   (.-)         : Non-greedy match for file path (captures file)
        --   :(%d+)       : Colon, then one or more digits (captures line number)
        --   :(%d+)       : Colon, then one or more digits (captures column)
        --   %)           : Literal ')'
        -- local line ="      at Object.<anonymous> (src/common/textUtils.test.tsx:15:60)"
        local file, lnum, col = line:match "^%s*at Object%.<anonymous>%s*%((.-):(%d+):(%d+)%)$" -- fixed regex: allow optional spaces, non-greedy file match, correct colon
        -- __AUTO_GENERATED_PRINT_VAR_START__
        print([==[parser file:]==], vim.inspect(file)) -- __AUTO_GENERATED_PRINT_VAR_END__
        print(file, lnum, col)

        if file then
          return {
            filename = file,
            lnum = tonumber(lnum),
            col = tonumber(col),
            text = "Test failure location",
            type = "E",
          }
        end
      end,
    },

    {
      "on_output_quickfix", -- Jest error format patterns

      errorformat = "%t%\\s%\\+%f:%l:%c",
      --     open = true,
      --     items_only = true,
      -- errorformat = table.concat({
      --   -- Main Jest stack trace: "at Object.<anonymous> (file:line:col)"
      --   "%E      at %m (%f:%l:%c)",  -- 6 spaces before "at"
      --   -- Alternative: "at Object (file:line:col)"
      --   "%E      at Object (%f:%l:%c)",  -- 6 spaces before "at"
      --   -- Test failure header: "● test suite › test name"
      --   "%E  ● %m",  -- 2 spaces before "●"
      --   -- Error location with caret: "> 15 |"
      --   "%Z      >%l |%m",  -- 6 spaces before ">"
      --   -- Error context lines with pipe
      --   "%C      %l |%m",  -- 6 spaces before line number
      --   -- expect() error message (4 spaces indent)
      --   "%C    %m",
      --   -- Continuation lines
      --   "%C%m",
      --   -- Ignore separator lines
      --   "%-G%.%#",
      -- }, ","),
      open = true,
      open_height = 12,
      tail = true, -- Auto-scroll on watch mode
      items_only = false,
    },
    -- We don't care to keep this around as long as most tasks
    -- { "on_complete_dispose", timeout = 30 },
    { "on_complete_notify", system = "always" },
    "default",
  },
  condition = {
    filetype = { "typescriptreact", "typescript" }, -- Include test filetypes
    -- Note: v2 removed condition callbacks - validation moved to builder
  },
}
