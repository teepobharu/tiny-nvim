local opts = { noremap = true, silent = true }
local keymap = vim.keymap.set
local pathUtils = require("utils.path")
local test = require("gitsigns.test")

local function stringTest()
  local somebuffername = "term://lazygit/1"
  print(somebuffername)
  local ismatchlzg1 = string.match(somebuffername, ".*(lazygit)/1$")
  print([==[stringTest ismatchlzg1:]==], vim.inspect(ismatchlzg1)) -- __AUTO_GENERATED_PRINT_VAR_END__
  print([==[str find]==], string.find(somebuffername, "lazygit"))
  print([==[str findnone]==], string.find(somebuffername, "zxc"))
  is_lazygit = string.match(somebuffername, "lazygit")
  print([==[stringTest is_lazygit:]==], vim.inspect(is_lazygit)) -- __AUTO_GENERATED_PRINT_VAR_END__
end

local function printVariables()
  local n = { 1, 2 }
  print([==[ n:]==], vim.inspect(n))
  print(123123)
  print(n[2])

  local current_file_path = vim.fn.expand("%:p")
  print([==[ current_file_path:]==], vim.inspect(current_file_path))
  local current_dir = vim.fn.expand("%:p:h")
  print([==[ current_dir:]==], vim.inspect(current_dir))
  local vim_getcwd = vim.fn.getcwd()
  -- get current lcd dir
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[printVariables vim_getcwd:]==], vim.inspect(vim_getcwd)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local dir = vim.fn.expand("$DOTFILES_DIR/.config/nvim2_jelly_lzmigrate")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[main dir:]==], vim.inspect(dir)) -- __AUTO_GENERATED_PRINT_VAR_END__

  fname = vim.fn.expand("%:p")
  print("dir from filename: " .. fname .. "  dir=" .. vim.fn.fnamemodify(fname, ":h"))
end

-- local keymap = vim.api.nvim_set_keymap
local function handleMode(mode)
  return function()
    if vim.fn.mode() == mode then
      vim.cmd("normal! y")
    else
      vim.cmd("normal! gv")
    end
  end
end

local function testKeyMap()
  opts.desc = "check if in V mode or v line mode"
  keymap("v", "<leader>z", checkIfInVmodeOrVLinemode, opts)
  keymap("v", "<leader>z", sentSelectedToTerminal, opts)

  -- opts.desc = "yank in visual mode"
  -- keymap("v", "v", handleMode("v"), opts)
  -- keymap("v", "V", handleMode("V"), opts)

  opts.desc = "Duplicate line and preserve yank register"
  keymap("n", "<A-d>", duplicateselected, opts)
  keymap("v", "<A-d>", duplicateselected, opts)
end

function sentSelectedToTerminal()
  -- -- !!! this will not work in visual mode
  -- vim.api.nvim_put("yyp") -- async cause the work is done in the background
  local mode = vim.fn.mode()
  if mode == "V" then
    print("in V mode")
    require("toggleterm").send_lines_to_terminal("visual_lines", true, { args = vim.v.count })
  elseif mode == "\22" then -- "\22" is the ASCII representation for CTRL-V
    print("in ^V mode")
    require("toggleterm").send_lines_to_terminal("visual_selection", true, { args = vim.v.count })
  elseif mode == "v" then
    print("in v mode")
    require("toggleterm").send_lines_to_terminal("visual_selection", true, { args = vim.v.count })
  else
    print("other " .. mode)
  end
end

local function checkLspClients()
  local lspconfig = require("lspconfig")
  local lspclient_f = lspconfig.util.get_lsp_clients({ name = "typescript-tools" })
  local lspclient_f2 = lspconfig.util.get_lsp_clients({ name = "denols" })
  local lspclient_ft = lspconfig.util.get_active_clients_list_by_ft("typescript")
  print([==[ lspclient_ft:]==], vim.inspect(lspclient_ft))
  print([==[ lspclient:]==], vim.inspect(lspclient_f))
  print([==[ lspclient:]==], vim.inspect(lspclient_f2))
end

function checkIfInVmodeOrVLinemode()
  local mode = vim.fn.mode()
  -- echo 1
  -- echo 2
  if mode == "V" then
    print("in V mode")
  elseif mode == "\22" then -- "\22" is the ASCII representation for CTRL-V
    print("in ^V mode")
  elseif mode == "v" then
    print("in v mode")
  else
    print("other " .. mode)
  end
end

function duplicateselected()
  local saved_unnamed = vim.fn.getreg('"')

  local current_selected_line = ""
  local current_mode = vim.fn.mode()
  if current_mode == "v" or current_mode == "V" then
    -- Get the selected lines
    current_selected_line = vim.fn.getline("`<", "`>")
  else
    current_selected_line = vim.fn.getline(".")
  end

  print("current_selected_line")
  print(current_selected_line)

  -- Duplicate the current line or selected lines
  if current_mode == "v" or current_mode == "V" then
    -- In visual mode, use normal command to duplicate lines
    vim.api.nvim_command("normal! y`>p`>")
    -- vim.api.nvim_command("normal! y`>$p`>") -- new line (will not work with v mode not new line)
  else
    -- In normal mode, duplicate the current line
    vim.cmd("normal! yyp")
  end

  -- Restore previous yank registers
  vim.fn.setreg('"', saved_unnamed)
end

local function toggleTermCheck()
  -- already avail in keymap function
  --   local set_opfunc = vim.fn[vim.api.nvim_exec(
  --     [[
  --   func s:set_opfunc(val)
  --     let &opfunc = a:val
  --   endfunc
  --   echon get(function('s:set_opfunc'), 'name')
  -- ]],
  --     true
  --   )]
  -- print(vim.fn.expand("%:p:h"))
  -- local Terminal = require("toggleterm.terminal").Terminal
  -- Terminal:new({ dir = vim.fn.expand("%:p:h") })
  local function CreateNewTerm()
    local Terminal = require("toggleterm.terminal").Terminal
    -- why normal command without stop command not show here
    -- Terminal:new({ dir = "git_dir", direction = "horizontal" })
    -- Terminal:toggle()
    local t1 = Terminal:new({ cmd = "sh pwd", close_on_exit = false })
    -- local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })
    -- lazygit:toggle()
    t1:toggle()
  end
  -- CreateNewTerm()

  opts.desc = "Send whole file to terminal"
  vim.keymap.set("n", [[<localleader>ta]], function()
    set_opfunc(function(motion_type)
      require("toggleterm").send_lines_to_terminal(motion_type, false, { args = vim.v.count })
    end)
    vim.api.nvim_feedkeys("ggg@G''", "n", false)
  end, opts)
  opts.desc = ""
end
local function testGit()
  local gitOriginSSH = "git@github.com:teepobharu/my-nvim-ide.git"
  local gitOriginHTTPS = "https://github.com/teepobharu/my-nvim-ide.git"

  local function extractNavigablePart(gitUrl)
    local sshPattern = "git@(.+):(.+).git"
    local httpsPattern = "https://(.+)/(.+).git"

    local domain, repo = gitUrl:match(sshPattern)
    if not domain then
      domain, repo = gitUrl:match(httpsPattern)
    end

    if domain and repo then
      return domain .. "/" .. repo
    else
      return nil, "Invalid Git URL"
    end
  end

  local navigablePartSSH = extractNavigablePart(gitOriginSSH)
  local navigablePartHTTPS = extractNavigablePart(gitOriginHTTPS)
  local git_current_branch = vim.fn.system("git rev-parse --abbrev-ref HEAD")

  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[testGit git_mainbranch:]==], vim.inspect(git_mainbranch))         -- __AUTO_GENERATED_PRINT_VAR_END__
  print([==[testGit git_current_branch:]==], vim.inspect(git_current_branch)) -- __AUTO_GENERATED_PRINT_VAR_END__

  local function get_remote_path(remote_url)
    -- Remove the protocol part (git@ or https://) and remove the first : after the protocol
    local path = remote_url:gsub("^git@", ""):gsub("^https?://", "")
    -- remove the first colon only
    path = path:gsub(":", "/", 1)
    -- Remove the .git suffix
    path = path:gsub("%.git$", "")
    return path
  end
  print("using gsub function")
  print(get_remote_path(gitOriginSSH))
  print("using gsub 2 function")
  print(get_remote_path(gitOriginHTTPS) or "NONE")
  print("using extract function")
  print(navigablePartSSH)   -- Output: github.com/teepobharu/my-nvim-ide
  print(navigablePartHTTPS) -- Output: github.com/teepobharu/my-nvim-ide
end
function testGit2(path)
  local current_file = path or vim.fn.expand("%:p")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[testGit2 current_file:]==], vim.inspect(current_file)) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- __AUTO_GENERATED_PRINT_VAR_START__

  local urlPath = require("utils.git").get_remote_path()
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[testGit2 urlPath:]==], vim.inspect(urlPath)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local mainBranch = require("utils.git").git_main_branch()
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[testGit2 mainBranch:]==], vim.inspect(mainBranch)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local gitroot = require("utils.path").get_root_directory()
  -- __AUTO_GENERATED_PRINT_VAR_START__
  local current_file = current_file:gsub(gitroot .. "/?", "")
  print([==[testGit2 current_file gsub:]==], vim.inspect(current_file)) -- __AUTO_GENERATED_PRINT_VAR_END__
  print([==[testGit2 gitroot:]==], vim.inspect(gitroot))                -- __AUTO_GENERATED_PRINT_VAR_END__
  local currentBranch = require("lazy.util").git_info(gitroot)
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[testGit2 currentBranch:]==], vim.inspect(currentBranch)) -- __AUTO_GENERATED_PRINT_VAR_END__

  -- gitlab vs gfithuib cases
  -- folder
  -- https://github.com/teepobharu/lazy-nvim-ide/tree/main/spell
  -- file
  -- -- https://gitlab.agodadev.io/full-stack/fe-data/messaging-client-js-core/-/blob/beta/.husky/commit-msg?ref_type=heads

  local branch = ""
  vim.ui.select({
    "1. Main Branch",
    "2. Current Branch",
  }, { prompt = "Choose to open in browser:" }, function(choice)
    if choice then
      local i = tonumber(choice:sub(1, 1))
      if i == 1 then
        branch = mainBranch
      else
        branch = currentBranch
      end
    else
    end
  end)
  local fullUrl = "https://" .. urlPath .. "/" .. current_file .. "/blob/" .. branch
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[testGit2 fullUrl:]==], vim.inspect(fullUrl)) -- __AUTO_GENERATED_PRINT_VAR_END__
  vim.fn.system("open " .. fullUrl)
  require("lazy.util").open(fullUrl)
end

function getGitList()
  local results = {}
  -- local remote_branches = vim.fn.system("git branch -r")
  local addedCd = ""
  -- addedCd = "cd $(zoxide query mmbweb) > /dev/null && "
  local remote_branches = vim.fn.system(addedCd .. "git branch --remote | sed -E 's|.* ||' | uniq")
  for branch in remote_branches:gmatch("[^\r\n]+") do
    table.insert(results, { value = branch })
    -- __AUTO_GENERATED_PRINT_VAR_START__
    -- remote = first part before branch name
    local remote_name = branch:match("([^/]+)")
    print("getGitList orignal name", branch, " extracted remote:", remote_name)
  end

  -- print([==[getGitList#for results:]==], vim.inspect(results)) -- __AUTO_GENERATED_PRINT_VAR_END__
end

function checkPyVenv()
  local pathVenv = vim.fn.getcwd() .. "/.venv"
  local isdir = vim.fn.isdirectory(pathVenv)
  if isdir == 1 then
    print(pathVenv .. " exists")
  else
    print(pathVenv .. " not exists")
  end
end

function getArrListConfig()
  local arrConfig = {
    { ssl = true,  proxy = "" },
    { ssl = false, proxy = "http://localhost:11435" },
  }
  print(arrConfig[2].ssl)
  print(arrConfig[2].proxy)

  -- vim.g.copilot_proxy = "http://localhost:11435"
  -- vim.g.copilot_proxy_strict_ssl = false
end

function filesys()
  local f = vim.fn.tempname()
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[ f:]==], vim.inspect(f)) -- __AUTO_GENERATED_PRINT_VAR_END__
end

function executables()
  local ppath = vim.fn.exepath("python3")
  local ppath = vim.fn.exepath("python")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[main ppath:]==], vim.inspect(ppath)) -- __AUTO_GENERATED_PRINT_VAR_END__
  get_pythonpath()
end

function get_pythonpath()
  -- check if pyrightconfig.json exists if yes proceed to get path from there else use pipenv --py to get other path else use default
  --
  -- find upward but do not exceed root project dir
  -- check if pyrightconfig.json exists
  -- if yes read venvPath and venv from there
  local root_dir = pathUtils.get_root_directory()
  local pyrightconfig = root_dir .. "/pyrightconfig.json"
  if vim.fn.filereadable(pyrightconfig) == 1 then
    print([==[M.pythonpath pyrightconfig exists:]==], vim.inspect(pyrightconfig))
    local config_content = vim.fn.readfile(pyrightconfig)
    local config = vim.fn.json_decode(table.concat(config_content, "\n"))

    if config == nil then
      print("config is nil")
    else
      local venvPath = config.venvPath
      local venv = config.venv
      local test = config.asda
      print([==[get_pythonpath#if config.venvPath:]==], vim.inspect(config)) -- __AUTO_GENERATED_PRINT_VAR_END__
      -- error if path not found
      if venvPath == nil or vim.fn.empty(venvPath) == 1 then
        vim.notify("pyrightconfig exist but venvPath not found", vim.log.levels.ERROR)
      else
        local venvPath = string.gsub(venvPath, root_dir, "")
        -- Remove front / back slash if it exists
        if string.sub(venvPath, 1, 1) == "/" then
          venvPath = string.sub(venvPath, 2)
        end
        if string.sub(venvPath, -1) == "/" then
          venvPath = string.sub(venvPath, 1, -2)
        end
        -- print("using from config: " .. root_dir .. "/" .. venvPath .. "/" .. "/bin/python")
        local pythonPath = root_dir .. "/" .. venvPath .. "/" .. "/bin/python"
        if vim.fn.filereadable(pythonPath) == 1 then
          -- print("pythonPath exists")
          return root_dir .. "/" .. venvPath .. "/" .. "/bin/python"
          -- print("pythonPath not exists")
        end
      end
    end
  end

  local python_path = ""
  local outputpipenvpy = vim.fn.systemlist("pipenv --py")
  print([==[get_pythonpath outputpipenvpy:]==], vim.inspect(outputpipenvpy))
  if vim.v.shell_error == 0 then
    -- Loading .env environment variables... <- sometimes show this extra line ??
    -- /Users/tharutaipree/Personal/streamlitgemini/.venv/bin/python
    for _, line in ipairs(output) do
      if line:match("^/") then
        python_path = line
        break
      end
    end
    print([==[get_pythonpath python_path (pipenv --py):]==], vim.inspect(python_path)) -- __AUTO_GENERATED_PRINT_VAR_END__
    return python_path
  else
    local python = vim.fn.exepath("python")
    print("==get_pythonpath using default python exe == :", python)
    return python
  end
end

function errorHandling()
  local ok, result = pcall(function()
    -- read non existing json decode
    local config = vim.fn.readfile("nonexisting.json")
    local decoded = vim.fn.json_decode(table.concat(config, "\n"))
    -- error("error")
  end)
  if not ok then
    print("error ==")
    vim.notify(result, vim.log.levels.ERROR)
  end
end

local function buffers()
  local prev_buf = vim.fn.bufnr("#") or 0
  local line_no = vim.api.nvim_buf_get_mark(prev_buf, ".")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[ line_no:]==], prev_buf, "line:", vim.inspect(line_no))
  print([==[ line_no][1]==], line_no[1])
end

testGetlineExe = function()
  local current_selected_line = vim.fn.getline("`<", "`>")
  local lastselectedcontent = vim.fn.getline("'<", "'>")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[lastselectedcontent:]==], vim.inspect(lastselectedcontent))     -- __AUTO_GENERATED_PRINT_VAR_END__
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[current_selected_line:]==], vim.inspect(current_selected_line)) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- # why always empty
end
testGitMatch = function()
  local hash = ""
  hash = "af3d91ef"
  hash = "81cda3728d4a25037acd2391902a9a021597d37b"

  local isT = hash:match("[0-9a-fA-F]{1,100}")   --  not work using {1,100}
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[function isT:]==], vim.inspect(isT)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local isT2 = hash:match("^[0-9a-fA-F]+$")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[function isT2:]==], vim.inspect(isT2)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local isT3 = #hash >= 7 and #hash <= 40 and hash:match("^[0-9a-fA-F]+$")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[function isT3:]==], vim.inspect(isT3)) -- __AUTO_GENERATED_PRINT_VAR_END__
end

vim_process_callback = function()
  print("vim_process_callback")
  local commandTables = {
    -- "which code", -- not executable
    -- "&&", -- this now work
    -- "env",
    -- "&&",
    -- "echo",
    -- "hello",
    -- "&&",
    -- "123",
  }
  -- chode not found
  -- commandTables = "env && which code && 123" -- this works code path output
  -- join table with space
  -- vim.fn.jobstart(table.concat(commandTables, " ", {
  vim.fn.jobstart(commandTables, {
    -- vim.fn.jobstart("env && which code && echo 'hello' && code . && some error here", {
    on_stdout = function(_, data, _)
      -- print("stdout", data)
      -- __AUTO_GENERATED_PRINT_VAR_START__
      print([==[cmdall functionout#function data:]==], vim.inspect(data)) -- __AUTO_GENERATED_PRINT_VAR_END__
    end,
    on_stderr = function(_, data, _)
      -- print("stderr", data)
      -- __AUTO_GENERATED_PRINT_VAR_START__
      print([==[cmdall functioerrn#function data:]==], vim.inspect(data)) -- __AUTO_GENERATED_PRINT_VAR_END__
    end,
    on_exit = function(_, code, _)
      print("exit", code)
    end,
    detach = true,
  })
  local open_command = "open"
  local open_command = "code"
  print([==[function open_command:]==], vim.inspect(open_command)) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- __AUTO_GENERATED_PRINT_VAR_START__
  -- local open_command = "open -a code"
  local url_or_word = "/Users/tharutaipree/dotfiles/.config/nvim2_jelly_lzmigrate/lua/config/mykeymaps.lua"

  -- vim.fn.jobstart({ open_command, "-a" , "code"}, { -- not work
  -- vim.fn.jobstart(open_command .. " -a " .. "code"}, { -- not work
  vim.fn.jobstart({ open_command, url_or_word }, {
    on_stdout = function(_, data, _)
      --   print("stdout", data)
      -- __AUTO_GENERATED_PRINT_VAR_START__
      print([==[functionout#if#function data:]==], vim.inspect(data)) -- __AUTO_GENERATED_PRINT_VAR_END__
    end,
    on_stderr = function(_, data, _)
      --   print("stderr", data)
      print([==[function#err#function data:]==], vim.inspect(data)) -- __AUTO_GENERATED_PRINT_VAR_END__
    end,
    on_exit = function(_, code, _)
      print("exit code=", code)
      if code == 0 then
        print("open success")
      else
        print("open failed")
      end
    end,
    detach = true,
  })
end

local function testExpand()
  local current_file = vim.fn.expand("%:p")
  print([==[testExpand current_file:]==], vim.inspect(current_file)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local cfile = vim.fn.expand("<cfile>")                             --// asdasd end
  print([==[testExpand cfile:]==], vim.inspect(cfile))               -- __AUTO_GENERATED_PRINT_VAR_END__
  local currline = vim.fn.getline(".")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[testExpand currline:]==], vim.inspect(currline)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local selline = vim.fn.getline("`<", "`>")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[testExpand selline:]==], vim.inspect(selline)) -- __AUTO_GENERATED_PRINT_VAR_END__
end

local function git_replace_pathedgecase()
  local a = "/Users/tharutaipree/AgodaGit/fe/messaging-client-messages"
  local b = "/Users/tharutaipree/AgodaGit/fe/messaging-client-messages/CONTRIBUTING.md"
  print([==[a:]==], vim.inspect(a))

  local escaped_a = vim.pesc(a)                           -- Escape special characters in 'a'
  print([==[main escaped_a:]==], vim.inspect(escaped_a))  -- __AUTO_GENERATED_PRINT_VAR_END__
  print([==[path - escaped :]==], vim.inspect(escaped_a)) -- __AUTO_GENERATED_PRINT_VAR_END__

  -- unesacpe version will  not work when contains char like '-' in the path
  local escPath_replace = b:gsub(escaped_a .. "/?", "")
  local unesRelPath_replace = b:gsub(a .. "/?", "")
  print([==[replace relPath:]==], vim.inspect(escPath_replace))         -- __AUTO_GENERATED_PRINT_VAR_END__
  print([==[replace unesRelPath:]==], vim.inspect(unesRelPath_replace)) -- __AUTO_GENERATED_PRINT_VAR_END__

  -- for android project
  local gitroot = "/Users/tharutaipree/AgodaGit/fe/client-android"
  local c = gitroot
      .. "/"
      ..
      "presentation/legacy-navigation/src/test/kotlin/com/agoda/mobile/src/test/consumer/screens/home/BottomNavPageMapperImplTest.kt"
  local c_no_root_fail = c:gsub(gitroot .. "/?", "")
  local c_no_root = c:gsub(vim.pesc(gitroot), "")
  -- `(.-)` is a non-greedy match for any character (except newline) as few times as possible.
  local module_path_work = c_no_root:match("^(.-)/src/test/")

  --
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[git_replace_pathedgecase modulee_path_work:]==], vim.inspect(module_path_work)) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- __AUTO_GENERATED_PRINT_VAR_START__
  --
  -- print([==[git_replace_pathedgecase c_no_root_fail:]==], vim.inspect(c_no_root)) -- __AUTO_GENERATED_PRINT_VAR_END__
  print([==[git_replace_pathedgecase c_no_root:]==], vim.inspect(c_no_root)) -- __AUTO_GENERATED_PRINT_VAR_END__

  -- get path from fe untiil test fe/(.*)/test
  local path_before_test = c:match("(.*)/src/test")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[git_replace_pathedgecase path_before_test:]==], vim.inspect(path_before_test)) -- __AUTO_GENERATED_PRINT_VAR_END__

  local module_pattern = "(.*)/src/test/"
  local module = path_before_test:match(module_pattern)
  print([==[git_replace_pathedgecase module:]==], vim.inspect(module)) -- __AUTO_GENERATED_PRINT_VAR_END__

  local module_pattern = "([^/]+)/([^/]+)/src/test/"
  local module = path_before_test:match(module_pattern)
  print([==[git_replace_pathedgecase module:]==], vim.inspect(module)) -- __AUTO_GENERATED_PRINT_VAR_END__
end

local function overseertestTask()
  -- Insert args at the '$*' in the grepprg
  local function runGrep(params)
    -- __AUTO_GENERATED_PRINT_VAR_START__
    local cmd, num_subs = vim.o.grepprg:gsub("%$%*", params.args)
    -- __AUTO_GENERATED_PRINT_VAR_START__
    if num_subs == 0 then
      cmd = cmd .. " " .. params.args
    end
    local overseer = require("overseer")
    -- Define the type for overseer.new_task
    ---@type fun(opts: overseer.TaskDefinition): overseer.Task
    local new_task = overseer.new_task

    local task = new_task({
      cmd = cmd,
      components = {
        {
          "on_output_quickfix", -- will output to quickfix
          errorformat = vim.o.grepformat,
          open = not params.bang,
          open_height = 8,
          items_only = true,
        },
        -- We don't care to keep this around as long as most tasks
        { "on_complete_dispose", timeout = 30 },
        { "on_complete_notify",  system = "unfocused" },
        "default",
      },
    })
    task:start()
  end

  vim.api.nvim_create_user_command("OverseerGrep", function(params)
    runGrep(params)
  end, { nargs = "*", bang = true, complete = "file" })
  local params = { args = "test", bang = false }
  -- runGrep(params)
end

local function runGetVisual()
  local text = require("utils.input").get_selected_or_cursor_word() --  mode n  cannot test since run with command ?
  -- local text = get_selected_or_cursor_word()
  print([==[runGetVisual text:]==], vim.inspect(text))              -- __AUTO_GENERATED_PRINT_VAR_END__
end

function get_selected_or_cursor_word()
  -- Check the current mode
  local mode = vim.api.nvim_get_mode().mode
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[M.get_selected_or_cursor_word mode:]==], vim.inspect(mode)) -- __AUTO_GENERATED_PRINT_VAR_END__

  if mode == "v" or mode == "V" or mode == "\22" then                   -- Check if the current mode is visual
    -- Get the start and end positions of the visual selection
    local s_start = vim.fn.getpos("'<")
    local s_end = vim.fn.getpos("'>")
    -- Retrieve the lines within the visual selection
    local lines = vim.fn.getline(s_start[2], s_end[2])
    -- Print the lines for debugging purposes
    print([==[M.get_selected_or_cursor_word#lines:]==], vim.inspect(lines)) -- __AUTO_GENERATED_PRINT_VAR_END__
    local selection = ""

    if #lines == 1 then
      -- If only one line is selected, extract the substring from start to end
      selection = lines[1]:sub(s_start[3], s_end[3])
    else
      -- If multiple lines are selected, adjust the first and last lines
      lines[1] = lines[1]:sub(s_start[3])
      lines[#lines] = lines[#lines]:sub(1, s_end[3])
      -- Concatenate all lines to form the complete selection
      selection = table.concat(lines, "\n")
    end

    return selection
  else
    -- Default to the word under the cursor
    return vim.fn.expand("<cword>")
  end
end

function testExtendTblwithKey()
  local CF2 = { { "T3", config = {} }, { "TTrue1", config = {} }, { "TTrue2", config = {} } }
  local TT = true -- get overridden
  local tbl = { { "t1", config = {} }, { "t3", config = {} } }
  tbl = vim.tbl_extend("force", tbl, TT and CF2 or {})
  -- not work wrong key the later table with keys
  -- print(vim.inspect(tbl))
  print(vim.inspect(vim.list_extend({ 1, 2 }, CF2)))
end

function bind_get_selected_or_cursor_word()
  vim.keymap.set("v", ",rx", function()
    local text = get_selected_or_cursor_word()
    print("bind_get_selected_or_cursor_word", text)
  end, { noremap = true, silent = true })
  vim.keymap.set("n", ",rx", function()
    local text = get_selected_or_cursor_word()
    print("bind_get_selected_or_cursor_word", text)
  end, { noremap = true, silent = true })
end

function test_outputcmd_copy_fn_from_quicklist()
  local files = {}
  -- __AUTO_GENERATED_PRINT_VAR_START__
  -- get item in QF list
  for _, item in ipairs(vim.fn.getqflist()) do
    --
    local fname = vim.fn.bufname(item.bufnr)
    if fname ~= "" and not files[fname] then
      files[fname] = true
    end
  end

  -- print file join by space in one line and create command to add new line on these files if exists
  --print the shell command
  command_sh_add_line_check_exist =
      "echo '" ..
      table.concat(vim.tbl_keys(files), " ") ..
      "' | xargs -I {} sh -c 'if [ -f {} ]; then echo \"\" >> \"{}\"; else echo \"File does not exist: {}\"; fi'"

  print([==[ command_sh_add_line_check_exist:]==], command_sh_add_line_check_exist) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- print remove_newline (revert )
  command_sh_remove_newline =
      "echo '" ..
      table.concat(vim.tbl_keys(files), " ") ..
      "' | xargs -n 1 -I {} sh -c 'if [ -f {} ]; then sed -i \"\" \"\\$d\" \"{}\"; else echo \"File does not exist: {}\"; fi'"
  print([==[ command_sh_remove_newline:]==], command_sh_remove_newline)
  -- print([==[ files:]==], vim.inspect(files)) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- copy files into clipboard split by new line / if want same line can paste in spotlight
  vim.fn.setreg("+", table.concat(vim.tbl_keys(files), "\n"))


  local file_chunks = {}
  local chunk_size = 100 -- Adjust the chunk size as needed
  for i = 1, #files, chunk_size do
    table.insert(file_chunks, table.concat(vim.list_slice(files, i, i + chunk_size - 1), " "))
  end

  for _, chunk in ipairs(file_chunks) do
    local command_sh_remove_newline =
        "echo '" ..
        chunk ..
        "' | xargs -n 4 -I {} sh -c 'if [ -f {} ]; then sed -i \"{}\" \"\\$d\"; else echo \"File does not exist: {}\"; fi'"
  end
end

local function main()
  -- add key binding ,rp = run
  -- runGetVisual()
  test_outputcmd_copy_fn_from_quicklist()

  -- __AUTO_GENERATED_PRINT_VAR_START__
  -- call :messages
  -- testExpand()
  -- vim_process_callback()
  -- get_pythonpath()
  -- getGitList()
  -- buffers()
  -- errorHandling()
  -- executables()
  -- filesys()
  -- getArrListConfig()
  -- testGetlineExe()
  -- testGitMatch()
  -- git_replace_pathedgecase()

  if false then
    testExtendTblwithKey()
    checkLspClients()
    overseertestTask()
    stringTest()
    printVariables()
    checkPyVenv()
    testGit()
    print(table.concat({ 1, 2, 3 }, ","))
    vim.opt_local.timeoutlen = 1000                                                          -- setlocal can used (still not found any differences when set)
    print([==[main   vim.timeoutlen:]==], vim.inspect(vim.opt.timeoutlen._value))            -- __AUTO_GENERATED_PRINT_VAR_END__
    print([==[main   vim.timeoutlenlocal:]==], vim.inspect(vim.opt_local.timeoutlen._value)) -- __AUTO_GENERATED_PRINT_VAR_END__
    -- __AUTO_GENERATED_PRINT_VAR_START__
    toggleTermCheck()
    testKeyMap()
    -- require("toggleterm").setup({ size = 20, open_mapping = [[<C-\>]] }) -- open terminal with <C-\>
    print("not run functions")
  end
end

main()
