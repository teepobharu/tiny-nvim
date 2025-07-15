-- NVIM_APPNAME is manual requirement to change to use the right settings vscode://settings.json
if not vim.g.vscode then
  return {}
end
local function get_visual_selection()
  local isVmode = vim.fn.mode() == "v"
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[get_visual_selection isVmode:]==], vim.inspect(isVmode)) -- __AUTO_GENERATED_PRINT_VAR_END__
  if not isVmode then
    -- __AUTO_GENERATED_PRINT_VAR_START__
    print([==[get_visual_selection#if vim.fn.expand("<cword>"):]==], vim.inspect(vim.fn.expand("<cword>"))) -- __AUTO_GENERATED_PRINT_VAR_END__
    return vim.fn.expand("<cword>")
  end
  local vstart = vim.fn.getpos("'<")
  local vend = vim.fn.getpos("'>")
  local line_start = vstart[2]
  local line_end = vend[2]
  local lines = vim.fn.getline(line_start, line_end)
  print([==[my_vscode_keymaps#function#get_visual_selection lines:]==], vim.inspect(lines)) -- __AUTO_GENERATED_PRINT_VAR_END__
  return lines
end

local enabled = {
  "lazy.nvim",
  "ts-comments.nvim",
  "nvim-treesitter",
  "nvim-treesitter-textobjects",
  "nvim-ts-context-commentstring",
  "vim-repeat",
}
-- use to fix vim.fn.start not found

-- print(vim.expand("$PATH"))
-- vim.env.PATH = vim.env.PATH .. ":/opt/homebrew/bin"
-- print(vim.expand("$PATH"))

local Config = require("lazy.core.config")
Config.options.checker.enabled = false
Config.options.change_detection.enabled = false
Config.options.defaults.cond = function(plugin)
  -- __AUTO_GENERATED_PRINT_VAR_START__
  -- print([==[Config.options.defaults.cond plugin:]==], vim.inspect(plugin))
  print([==[Config.options.defaults.cond plugin:]==], vim.inspect(plugin.name), plugin.vscode) -- __AUTO_GENERATED_PRINT_VAR_END__
  return vim.tbl_contains(enabled, plugin.name) or plugin.vscode
end

-- Add some vscode specific keymaps
-- Refer to https://github.com/vscode-neovim/vscode-neovim#code-navigation-bindings for default keymaps
vim.api.nvim_create_autocmd("User", {
  pattern = "NvimIdeKeymaps", -- This pattern will be called when the plugin is loaded
  callback = function()
    local vscode = require "vscode"
    -- +File
    -- Find file
    vim.keymap.set("n", "<leader><space>", function()
      -- show all editors
      vim.cmd("Find")
      -- # make notify auto dismissed
      -- vscode.notify("c-space to show opened files")
      vim.notify("c-space to filter opened files", vim.log.levels.INFO)
      -- vscode.action("workbench.action.showAllEditors")
    end)
    vim.keymap.set("n", "<leader>be", function()
      vscode.action("workbench.action.showAllEditors")
    end)
    vim.keymap.set("n", "<leader>,", function()
      vscode.action("workbench.action.showAllEditors")
    end)
    vim.keymap.set("n", "<leader>b<C-d>", function()
      vscode.action("workbench.action.closeOtherEditors")
    end)
    -- Find recent open files
    vim.keymap.set("n", "<leader>fr", function()
      vscode.action "workbench.action.showAllEditorsByMostRecentlyUsed"
    end)

    -- Need to install https://github.com/jellydn/vscode-fzf-picker
    vim.keymap.set("n", "<leader>ff", function()
      vscode.action "fzf-picker.findFiles"
    end)
    vim.keymap.set("n", "<leader>fr", function()
      vscode.action "fzf-picker.runCustomTask"
    end)
    -- Find word
    vim.keymap.set({ "n", "v" }, "<leader>fw", function()
      vscode.action "fzf-picker.findWithinFiles"
    end)
    vim.keymap.set("n", "<leader>fw", function()
      vscode.action "editor.action.addSelectionToNextFindMatch"
      vscode.action "fzf-picker.findWithinFiles"
    end)
    -- Find file from git status
    vim.keymap.set("n", "<leader>fg", function()
      vscode.action "fzf-picker.pickFileFromGitStatus"
    end)
    -- Resume last search
    vim.keymap.set("n", "<leader>fR", function()
      vscode.action "fzf-picker.resumeSearch"
    end)
    -- Find todo/fixme
    vim.keymap.set("n", "<leader>fx", function()
      vscode.action "fzf-picker.findTodoFixme"
    end)

    -- Open other files
    vim.keymap.set("n", "<leader>,", function()
      vscode.action "workbench.action.showAllEditors"
    end)
    -- Find in files
    vim.keymap.set("n", "<leader>/", function()
      vscode.action "workbench.action.findInFiles"
    end)
    -- Open file explorer in left sidebar
    vim.keymap.set("n", "<leader>e", function()
      vscode.action "workbench.view.explorer"
    end)

    -- +Search
    -- Open symbol
    vim.keymap.set("n", "<leader>ss", function()
      vscode.action("outline.focus")
      -- vscode.action("workbench.action.gotoSymbol")
    end)
    vim.keymap.set("n", "<leader>sS", function()
      vscode.action("workbench.action.showAllSymbols")
    end)
    -- Search word under cursor
    vim.keymap.set("n", "<leader>sw", function()
      vscode.action "editor.action.addSelectionToNextFindMatch"
      vscode.action "workbench.action.findInFiles"
      -- Or send as the param like this: code.action("workbench.action.findInFiles", { args = { query = vim.fn.expand("<cword>") } })
    end)

    -- Keep undo/redo lists in sync with VsCode
    vim.keymap.set("n", "u", "<Cmd>call VSCodeNotify('undo')<CR>")
    vim.keymap.set("n", "<C-r>", "<Cmd>call VSCodeNotify('redo')<CR>")
    -- Navigate VSCode tabs like lazyvim buffers
    vim.keymap.set("n", "<S-h>", "<Cmd>call VSCodeNotify('workbench.action.previousEditor')<CR>")
    vim.keymap.set("n", "<S-l>", "<Cmd>call VSCodeNotify('workbench.action.nextEditor')<CR>")
    -- use c-w-l
    vim.keymap.set({ "n", "i", "v" }, "<C-l>", function()
      -- "<C-w>l")
      vscode.action "workbench.action.navigateRight"
    end)

    -- Search work in current buffer
    vim.keymap.set("n", "<leader>sb", function()
      vscode.action "actions.find"
    end)

    -- +Code
    -- Code Action
    vim.keymap.set("n", "<leader>ca", function()
      vscode.action "editor.action.codeAction"
    end)
    -- Source Action
    vim.keymap.set("n", "<leader>cA", function()
      vscode.action "editor.action.sourceAction"
    end)
    -- Code Rename
    vim.keymap.set("n", "<leader>cr", function()
      vscode.action "editor.action.rename"
    end)
    -- Quickfix shortcut
    vim.keymap.set("n", "<leader>.", function()
      vscode.action "editor.action.quickFix"
    end)
    -- Code format
    vim.keymap.set("n", "<leader>cf", function()
      vscode.action "editor.action.formatDocument"
    end)
    -- Refactor
    vim.keymap.set("n", "<leader>cR", function()
      vscode.action "editor.action.refactor"
    end)

    -- +Terminal
    -- Open terminal
    vim.keymap.set("n", "<leader>ft", function()
      vscode.action "workbench.action.terminal.focus"
    end)

    -- +LSP
    -- View problem
    vim.keymap.set("n", "<leader>xx", function()
      vscode.action "workbench.actions.view.problems"
    end)
    -- Go to next/prev error
    vim.keymap.set("n", "]e", function()
      vscode.action "editor.action.marker.next"
    end)
    vim.keymap.set("n", "[e", function()
      vscode.action "editor.action.marker.prev"
    end)

    -- Find references
    vim.keymap.set("n", "gr", function()
      vscode.action "references-view.find"
    end)
    vim.keymap.set("n", "gy", function()
      vscode.action "editor.action.goToTypeDefinition"
    end)

    -- +Git
    -- Git status
    vim.keymap.set("n", "<leader>gs", function()
      vscode.action "workbench.view.scm"
    end)
    -- Go to next/prev change
    vim.keymap.set("n", "]h", function()
      vscode.action "workbench.action.editor.nextChange"
    end)
    vim.keymap.set("n", "[h", function()
      vscode.action "workbench.action.editor.previousChange"
    end)

    -- Revert change
    vim.keymap.set("v", "<leader>ghr", function()
      vscode.action "git.revertSelectedRanges"
    end)

    -- +Buffer
    -- Switch buffer
    vim.keymap.set("n", "<leader>`", function()
      vscode.action "workbench.action.quickOpenPreviousRecentlyUsedEditor"
      vscode.action "list.select"
    end)

    -- Close buffer
    vim.keymap.set("n", "<leader>bd", function()
      vscode.action "workbench.action.closeActiveEditor"
    end)
    -- Close other buffers
    vim.keymap.set("n", "<leader>bl", function()
      vscode.action("workbench.action.closeEditorsToTheLeft")
    end)
    vim.keymap.set("n", "<leader>br", function()
      vscode.action("workbench.action.closeEditorsToTheRight")
    end)
    vim.keymap.set("n", "<leader>bo", function()
      vscode.action "workbench.action.closeOtherEditors"
    end)

    -- +Project
    vim.keymap.set("n", "<leader>fp", function()
      vscode.action "workbench.action.openRecent"
    end)

    -- Markdown preview
    vim.keymap.set("n", "<leader>mp", function()
      vscode.action "markdown.showPreviewToSide"
    end)

    -- Hurl runner, https://github.com/jellydn/vscode-hurl-runner
    vim.keymap.set("n", "<leader>ha", function()
      vscode.action "vscode-hurl-runner.runHurl"
    end)
    vim.keymap.set("n", "<leader>hr", function()
      vscode.action "vscode-hurl-runner.rerunLastCommand"
    end)
    vim.keymap.set("n", "<leader>hA", function()
      vscode.action "vscode-hurl-runner.runHurlFile"
    end)
    vim.keymap.set("n", "<leader>he", function()
      vscode.action "vscode-hurl-runner.runHurlFromBegin"
    end)
    vim.keymap.set("n", "<leader>hE", function()
      vscode.action "vscode-hurl-runner.runHurlToEnd"
    end)
    vim.keymap.set("n", "<leader>hg", function()
      vscode.action "vscode-hurl-runner.manageInlineVariables"
    end)
    vim.keymap.set("n", "<leader>hh", function()
      vscode.action "vscode-hurl-runner.viewLastResponse"
    end)
    vim.keymap.set("v", "<leader>hh", function()
      vscode.action "vscode-hurl-runner.runHurlSelection"
    end)

    -- Run task
    vim.keymap.set("n", "<leader>oo", function()
      vscode.action "workbench.action.tasks.runTask"
    end)
    vim.keymap.set("n", "<leader>ol", function()
      vscode.action "npm.focus"
    end)
    vim.keymap.set("n", "<leader>rt", function()
      vscode.action "workbench.action.tasks.runTask"
    end)
    -- Re-run
    vim.keymap.set("n", "<leader>rr", function()
      vscode.action "workbench.action.tasks.reRunTask"
    end)

    -- Debug typescript type, used with https://marketplace.visualstudio.com/items?itemName=Orta.vscode-twoslash-queries
    vim.keymap.set("n", "<leader>dd", function()
      vscode.action "orta.vscode-twoslash-queries.insert-twoslash-query"
    end)

    -- Other keymaps will be used with https://github.com/VSpaceCode/vscode-which-key, so we don't need to define them here
    -- Trigger which-key by pressing <CMD+Space>, refer more default keymaps https://github.com/VSpaceCode/vscode-which-key/blob/15c5aa2da5812a21210c5599d9779c46d7bfbd3c/package.json#L265

    -- Mutiple cursors
    vim.keymap.set({ "n", "x", "i" }, "<C-m>", function()
      require("vscode-multi-cursor").addSelectionToNextFindMatch()
    end)

    my_vscode_keymaps(vscode)
  end,
})

-- X : if vscode then add run time
if vim.g.vscode then
  -- vim.cmd([[set runtimepath^=$HOME/.config/nvim2_jelly_lzmigrate]])
  -- -- print runtimepathkjA
  -- print(vim.o.runtimepath)
  --   require("config.mykeymaps")
end

function my_vscode_keymaps(vscode)
  -- api : https://github.com/vscode-neovim/vscode-neovim?tab=readme-ov-file#%EF%B8%8F-api
  -- local vscode = vscode or require("vscode")

  local QuickOnboardKeyInstructions = [[
    <l> = leader
    -----------------------------
    \n ?+?      WhichKey search
    <l>ls / qq  Stop plugin
    <l>lr       Restart neovim plugin
    -----------------------------
    <l>sna Open output + messages
    <l>oo Open test results
    <space><space> Find file
    -- Config
    ,e Edit config file
    -- Git
    <l>gb Git blame
    <l>gf Git file history
    <l>gC Git compare diff
    <l>gi Toggle inline diff
    <l>g< diff with previously
    -- Files and search
    <l>fw Find word within files
    <l>ff Find files using fzf-picker
    <l>fr Find recent open files
    <l>fg Find file from git status
    <l>fR Resume last search
    <l>fx Find todo/fixme
    <l>, Open other files
    <l>/ Find in files
    <l>sw Search word under cursor
    <l>sb Search word in current buffer
    <l>e Open file explorer in left sidebar
    <l>ss Open symbol
    -- Code
    <l>ca Code action
    <l>cA Source action
    <l>cr Code rename
    <l>. Quickfix shortcut
    <l>cf Code format
    <l>cR Refactor
    --
    n  <l>dv Print below variables
    n  <l>rB Extract block to file
    n  <l>rI Inline function
    n  <l>ri Inline variable
    n  <l>rb Extract block
    n  <l>cjd JsDoc
    n  <l>cjf JsDocFormat
    -- Views
    <l>1 Toggle sidebar
    <l>2 togglge secondary
    -- Windows
    <l>ft Open terminal
    <l>xx View problems
    <C-q> Close window group
    <l>wv Split window
    <l>wL Close editors to the right
    <l>wH Close editors to the left
    <l>wh Split editor down
    ** <leader>sna to see all keybind / prior messages **
]]

  local isCursor = vscode.has_config("cursor") -- work around since cannot acces context like in when
  print(QuickOnboardKeyInstructions)
  -- vscode.notify(QuickOnboardKeyInstructions)
  -- Helper
  vim.keymap.set("n", "?", function()
    vscode.action("whichkey.show")
  end)
  --
  vim.keymap.set("n", "<localleader>le", function()
    -- local currentfiledir = vim.fn.expand("<sfile>:p:h")
    local initFile = vim.fn.expand("$HOME/.config/$NVIM_APPNAME/init.lua")
    local configFile = vim.fn.expand("$HOME/.config/$NVIM_APPNAME/lua/plugins/vscode.lua")
    local keymapFile = vim.fn.expand("$HOME/.config/$NVIM_APPNAME/lua/config/mykeymaps.lua")
    --   local configFile = vim.fn.expand("$HOME/.config/nvim2_jelly_lzmigrate/init.lua")
    vim.fn.jobstart("code " .. initFile, { detach = true })
    vim.fn.jobstart("code " .. configFile, { detach = true })
    vim.fn.jobstart("code " .. keymapFile, { detach = true })
    vim.notify("Open file: " .. configFile .. " and " .. initFile .. " and " .. keymapFile)
  end)

  -- View
  vim.keymap.set("n", "<leader>1", function()
    vscode.action("workbench.action.toggleSidebarVisibility")
  end)
  vim.keymap.set("n", "<leader>2", function()
    vscode.action("workbench.action.toggleAuxiliaryBar")
  end)
  -- Preferences
  vim.keymap.set("n", "<leader>sk", function()
    vscode.action("workbench.action.openGlobalKeybindings")
  end)
  vim.keymap.set("n", "<leader>sK", function()
    vscode.action("workbench.action.openGlobalKeybindingsFile")
  end)
  vim.keymap.set("n", "<leader>qr", function()
    vscode.action("workbench.action.reloadWindow")
  end)
  -- +Window
  -- vs / sp split
  vim.keymap.set("n", "<leader>wv", function()
    vscode.action("workbench.action.splitEditor")
  end)
  -- Ctrl Q - close window group
  -- c-w j and c-w k above / below editor group -- not working - edit in keyjson instead
  -- vim.keymap.set("n", "<C-w>j", function()
  --   vscode.action("workbench.action.focusBelowGroup")
  -- end)
  -- vim.keymap.set("n", "<C-w>k", function()
  --   vscode.action("workbench.action.focusAboveGroup")
  -- end)
  vim.keymap.set("n", "<C-q>", function()
    vscode.action("workbench.action.closeEditorsAndGroup")
  end)
  vim.keymap.set("n", "<leader>wL", function()
    vscode.action("workbench.action.closeEditorsToTheRight")
  end)
  vim.keymap.set("n", "<leader>wH", function()
    vscode.action("workbench.action.closeEditorsToTheLeft")
  end)
  vim.keymap.set("n", "<leader>wh", function()
    vscode.action("workbench.action.splitEditorDown")
  end)
  vim.keymap.set("n", "<leader><Tab>d", function()
    vscode.action("workbench.action.closeEditorsInGroup")
  end)
  vim.keymap.set("n", "<leader><Tab>o", function()
    vscode.action("workbench.action.closeEditorsInOtherGroups")
  end)
  vim.keymap.set("n", "Q", function()
    -- close file
    vscode.action("workbench.action.closeActiveEditor")
  end)
  -- since bd have some problem that open output file
  vim.keymap.set("n", "L", function()
    vscode.action("workbench.action.nextEditorInGroup")
  end)
  vim.keymap.set("n", "H", function()
    vscode.action("workbench.action.previousEditorInGroup")
  end)
  vim.keymap.set("n", "<leader>sne", function()
    vscode.action("workbench.panel.output.focus")
  end)
  vim.keymap.set("n", "zC", function()
    vscode.action("editor.foldAll")
  end)
  vim.keymap.set("n", "<esc><space>", function()
    vscode.action("editor.toggleFold")
    -- vscode.action("editor.toggleFoldRecursively")
  end)
  vim.keymap.set("n", "zc", function()
    vscode.action("editor.foldRecursively")
  end)
  vim.keymap.set("n", "zO", function()
    vscode.action("editor.unfoldAll")
  end)
  vim.keymap.set("n", "zo", function()
    vscode.action("editor.unfoldRecursively")
  end)
  vim.keymap.set("n", "zv", function()
    vscode.action("editor.unfold")
    vscode.action("editor.foldAllExcept")
  end)
  vim.keymap.set("n", "zV", function()
    vscode.action("editor.unfoldRecursively")
    vscode.action("editor.foldAllExcept")
  end)
  vim.keymap.set("n", "zj", function()
    vscode.action("editor.gotoNextFold")
  end)
  vim.keymap.set("n", "zk", function()
    vscode.action("editor.gotoPreviousFold")
  end)
  -- +Git
  vim.keymap.set("n", "<leader>gb", function()
    -- blame
    vscode.action("gitlens.toggleFileBlame")
  end)
  vim.keymap.set({ "n", "v" }, "<leader>ghs", function()
    vscode.action("git.stageSelectedRanges")
  end)
  vim.keymap.set("n", "<leader>ghS", function()
    vscode.action("git.stage")
  end)

  vim.keymap.set("n", "<leader>ghU", function()
    vscode.action("git.unstageAll")
  end)
  vim.keymap.set({ "n", "v" }, "<leader>ghu", function()
    vscode.action("git.unstage")
  end)
  -- open file history
  vim.keymap.set("n", "<leader>gf", function()
    vscode.action("gitlens.views.fileHistory.focus")
  end)
  -- open compare diff
  vim.keymap.set("n", "<leader>ghD", function()
    vscode.action("gitlens.compareHeadWith")
  end)
  vim.keymap.set("n", "<leader>ghd", function()
    vscode.action("gitlens.openFileRevisionFrom")
  end)
  vim.keymap.set("n", "<leader>gC", function()
    vscode.action("gitlens.compareHeadWith")
    vscode.notify("use cmd+down browse sections")
  end)
  vim.keymap.set("n", "<leader>gi", function()
    vscode.action("toggle.diff.renderSideBySide")
  end)
  -- dup ?
  vim.keymap.set("n", "<leader>g<", function()
    vscode.action("gitlens.diffWithPreviousInDiffLeft")
    --   vscode.action("gitlens.diffWithPrevious")
  end)
  vim.keymap.set("n", "<leader>g>", function()
    vscode.action("gitlens.diffWithNext")
  end)
  vim.keymap.set("n", "<leader>go", function()
    vscode.action("git.checkout")
  end)
  vim.keymap.set("n", "<leader>gw", function()
    vscode.action("gitlens.views.worktrees.focus")
  end)
  vim.keymap.set("n", "<leader>g'", function()
    vscode.action("gitlens.showQuickFileHistory")
  end)
  vim.keymap.set("n", "<leader>gc", function()
    vscode.action("git.commit")
  end)
  vim.keymap.set("n", "<leader>gF", function()
    vscode.action("git.fetch")
  end)
  vim.keymap.set("n", "<leader>gi", function()
    vscode.action("git.init")
  end)
  vim.keymap.set("n", "<leader>gl", function()
    vscode.action("gitlens.showGraphPage")
  end)
  vim.keymap.set("n", "<leader>gm", function()
    vscode.action("gitlens.gitCommands")
  end)
  vim.keymap.set("n", "<leader>gp", function()
    vscode.action("git.publish")
  end)
  -- +File

  -- LSP and code
  vim.keymap.set("n", "<leader>xX", function()
    vscode.action "errorLens.toggle"
  end)
  -- vscode-neovim.restart with <leader>ls (stop vim)
  vim.keymap.set("n", "<leader>ls", function()
    vscode.action("vscode-neovim.stop")
  end)
  -- typescript.restartTsServer with <leader>ls (stop vim)
  -- set j k and k j to enter normal mode - not work use in settings.json
  -- vim.keymap.set("i", "jk", "<esc>")
  -- vim.keymap.set("i", "kj", "<esc>")
  -- send selected text / lline to terminal in n\v mode
  -- open shortcuts key json in vscode
  vim.keymap.set({ "n", "v" }, "<localleader>t", function()
    -- vscode.notify("Before wrun WAIT")
    vscode.action("workbench.action.terminal.runSelectedText")
    -- vscode.call("_wait", { args = { 1000 }, 100 })
    -- vscode.notify("AFFTER WAIT NEVER RUN !!")
    -- vscode.call("workbench.action.terminal.focus", {}, 100)
  end)

  vim.keymap.set({ "n", "v" }, "<leader>lr", function()
    vscode.action("vscode-neovim.restart")
    vscode.action("workbench.panel.output.focus")
  end)
  -- Errors
  vim.keymap.set("n", "<leader>el", function()
    vscode.action("workbench.actions.view.problems")
  end)
  vim.keymap.set("n", "]q", function()
    vscode.action("editor.action.marker.nextInFiles")
  end)
  vim.keymap.set("n", "[q", function()
    vscode.action("editor.action.marker.prevInFiles")
  end)
  -- Tests and tasks

  -- AI ai
  vim.keymap.set({ "n", "v" }, "<leader>aq", function()
    if isCursor then
      vscode.action("aipopup.action.modal.generate") -- cursor
    else
      vscode.action("inlineChat.start")
    end
  end)
  vim.keymap.set({ "n", "v" }, "<leader>av", function()
    -- TODO can we check wit when context -- seems like not kjj?
    -- Check if the cursor is active and start the composer prompt in VSCode
    if isCursor then
      vscode.action("composer.startComposerPrompt")
    else
      vscode.action("workbench.action.chat.openInSidebar")
    end
    -- local config = vscode.eval("return vscode.window.activeTextEditor.document.fileName")
    -- local w1 = vscode.eval("return vscode.editorTextFocus") -- nil

    -- vim.print(vscode.get_config({ "editor.fontFamily", "editor.tabSize" }))
    -- __AUTO_GENERATED_PRINT_VAR_START__
    -- print([==[my_vscode_keymaps#(anon) vscode.get_config("cursor"):]==], vim.inspect(vscode.get_config("cursor"))) -- __AUTO_GENERATED_PRINT_VAR_END__

    -- print(
    --   [==[my_vscode_keymaps#(anon) vscode.get_config("cursor"):]==],
    --   vim.inspect(vscode.get_config("editor.tabSize")),
    --   vim.inspect(vscode.get_config("xzceditor")),
    --   vim.inspect(vscode.get_config("cursor")),
    --   isCursor
    -- ) -- __AUTO_GENERATED_PRINT_VAR_END__
  end)
  vim.keymap.set("n", "<leader>aa", function()
    if isCursor then
      vscode.action("aichat.newchataction") -- cursor
    else
      vscode.action("workbench.action.chat.attachFile")
    end
    -- vscode.action("aipopup.action.modal.generate") -- cursor
  end)
  vim.keymap.set("v", "<leader>aa", function()
    if isCursor then
      vscode.action("aichat.insertselectionintochat") -- cursor
    else
      vscode.action("github.copilot.chat.attachSelection")
    end
  end)
  vim.keymap.set("n", "<leader>aA", function()
    vscode.action("github.copilot.edits.attachFile")
  end)
  vim.keymap.set("v", "<leader>aA", function()
    vscode.action("github.copilot.edits.attachFile")
  end)

  vim.keymap.set("n", "<leader>at", function()
    vscode.action("github.copilot.terminal.explainTerminalLastCommand")
  end)

  vim.keymap.set("v", "<leader>at", function()
    vscode.action("github.copilot.terminal.explainTerminalSelection")
  end)

  vim.keymap.set("n", "<leader>aT", function()
    vscode.action("github.copilot.terminal.explainTerminalLastCommand")
  end)

  vim.keymap.set("v", "<leader>aT", function()
    vscode.action("github.copilot.terminal.explainTerminalSelection")
  end)

  vim.keymap.set("n", "<leader>aV", function()
    vscode.action("workbench.action.chat.openEditSession")
  end)
  vim.keymap.set("v", "<leader>aV", function()
    vscode.action("github.copilot.edits.attachSelection")
    vscode.action("workbench.panel.chat.view.edits.focus")
  end)

  vim.keymap.set({ "n", "v" }, "<leader>Aa", function()
    vscode.action("continue.focusContinueInputWithoutClear")
  end)
  -- Av - v mode "continue.focusContinueInputWithoutClear"
  vim.keymap.set("v", "<leader>Av", function()
    vscode.action("continue.focusContinueInputWithoutClear")
  end)
  -- Av - n mode "continue.continueGUIView.focus"
  vim.keymap.set("n", "<leader>Av", function()
    vscode.action("continue.continueGUIView.focus")
  end)
  --
  -- WIP
  vim.keymap.set({ "n", "v" }, "<leader>sf", function()
    vscode.action("editor.action.addSelectionToNextFindMatch")
    vscode.action("editor.action.startFindReplaceAction")
  end)

  vim.keymap.set("n", "<leader>sa", function()
    vscode.action("workbench.action.showCommands")
  end)

  vim.keymap.set("n", "<leader>fl", function()
    -- FIX: why settings.json field does not include task yet ?
    -- live grep
    vscode.action("fzf-picker.runCustomTask")
  end)

  vim.keymap.set({ "v", "n" }, "<leader>sw", function()
    -- In action (workbench.action) not in api docs (vscode.api?)
    --  - https://github.com/microsoft/vscode/blob/1.98.2/src/vs/workbench/contrib/search/browser/searchActionsFind.ts#L40
    --  - https://code.visualstudio.com/api/references/commands
    vscode.action(
      "workbench.action.findInFiles",
      { args = { query = get_visual_selection(), filesToInclude = "", onlyOpenEditors = false } }
    )
    vscode.action("search.action.focusSearchList")
  end)

  vim.keymap.set({ "v", "n" }, "<leader>sW", function()
    -- vscode.action("editor.action.addSelectionToNextFindMatch")
    -- vscode.action("workbench.action.findInFiles")
    vscode.action(
      "workbench.action.findInFiles",
      { args = { query = get_visual_selection(), filesToInclude = "", onlyOpenEditors = true } }
    )
    vscode.action("search.action.focusSearchList")
  end)

  vim.keymap.set({ "v", "n" }, "<leader>sb", function()
    vscode.action(
      "workbench.action.findInFiles",
      { args = { query = get_visual_selection(), filesToInclude = "", onlyOpenEditors = true } }
    )
    vscode.action("search.action.focusSearchList")
  end)

  vim.keymap.set({ "v", "n" }, "<leader>sB", function()
    local query = get_visual_selection()
    print([==[my_vscode_keymaps#(anon) query:]==], vim.inspect(query)) -- __AUTO_GENERATED_PRINT_VAR_END__
    local isVmode = vim.fn.mode() == "v"

    if (query ~= "" and #query > 2) or isVmode then
      vscode.action(
        "workbench.action.findInFiles",
        { args = { query = query, filesToInclude = "", onlyOpenEditors = true } }
      )
      vscode.action("search.action.focusSearchList")
    else
      print("No selection found")
    end
    vscode.action("search.action.focusSearchList")
  end)

  vim.keymap.set({ "n", "v" }, "<leader>sF", function()
    local currentDir = vim.fn.expand("%:p:h")
    -- __AUTO_GENERATED_PRINT_VAR_START__
    print([==[my_vscode_keymaps#function currentDir:]==], vim.inspect(currentDir)) -- __AUTO_GENERATED_PRINT_VAR_END__
    local current_file = vscode.eval("return vscode.window.activeTextEditor.document.fileName")
    -- __AUTO_GENERATED_PRINT_VAR_START__
    print([==[my_vscode_keymaps#function current_file:]==], vim.inspect(current_file)) -- __AUTO_GENERATED_PRINT_VAR_END__
    local activeEditor = vscode.eval("return vscode.window.activeTextEditor")
    -- __AUTO_GENERATED_PRINT_VAR_START__
    print([==[my_vscode_keymaps#function activeEditor:]==], vim.inspect(activeEditor)) -- __AUTO_GENERATED_PRINT_VAR_END__

    --
    -- if v mode then use the selection text
    -- local query = vim.fn.getreg("v") or vim.fn.expand("<cword>")
    -- local vscode_selected_text = vscode.eval("await vscode")
    -- print([==[function#function vim.fn.expand("<cword>"):]==], vim.inspect(vim.fn.expand("<cword>"))) -- __AUTO_GENERATED_PRINT_VAR_END__
    -- print([==[function#function vim.fn.getreg("v"):]==], vim.inspect(vim.fn.getreg("v"))) -- __AUTO_GENERATED_PRINT_VAR_END__
    -- print([==[function#function query:]==], vim.inspect(query)) -- __AUTO_GENERATED_PRINT_VAR_END__
    -- vscode.action("workbench.action.findInFiles", { ]]
    vscode.action(
      "workbench.action.findInFiles",
      { args = { query = get_visual_selection(), currentDir = current_file .. "/../**", onlyOpenEditors = false } }
    )
    -- vscode.action("workbench.action.replaceInFiles", {
    --     args = { query = get_visual_selection(), filesToInclude = currentDir .. "/../**" },
    -- })
    vscode.notify("cmd+enter to open result in editor")
    vscode.action("search.action.focusSearchList")
  end)

  -- TO MIGRATE -------------------- =============
  -- Navigation

  -- Jest : TODO: make sure it ru njest test
  -- toggle wrap tw
  vim.keymap.set("n", "<leader>tw", function()
    vscode.action("editor.action.toggleWordWrap")
  end)
  vim.keymap.set("n", "<leader>tT", function()
    vscode.action("extension.runJestFile")
    vscode.action("testing.runCurrentFile")
  end)
  vim.keymap.set("n", "<leader>tt", function()
    vscode.action("extension.runJest")
    vscode.action("testing.runAtCursor")
  end)
  vim.keymap.set("n", "<leader>ts", function()
    vscode.action("workbench.view.testing.focus")
  end)
  vim.keymap.set("n", "<leader>to", function()
    vscode.action("workbench.panel.testResults.view.focus")
  end)
  vim.keymap.set("n", "<leader>tr", function()
    vscode.action("workbench.panel.testResults.view.focus")
  end)
  vim.keymap.set("n", "<leader>tb", function()
    vscode.action("workbench.action.tasks.build")
  end)
  -- Navigation
  vim.keymap.set("n", "<leader>fY", function()
    vscode.action("workbench.action.files.copyPathOfActiveFile")
  end)
  vim.keymap.set("n", "<leader>fy", function()
    -- access clipboard
    vscode.action("copyRelativeFilePath")
    -- __AUTO_GENERATED_PRINT_VAR_START__
    -- local vscode.eval("await vscode.env.clipboard.writeText(args.text)", { args = { text = "some text" } })

    --
    -- Callback function to handle the result of an asynchronous operation.
    -- @param err string|nil: Error message if an error occurred, or nil if no error.
    -- @param ret any: The result of the asynchronous operation.
    local callback = function(err, ret)
      if err then
        print("cb Error: ", vim.inspect(err))
      else
        print("cb Result: ", vim.inspect(ret))
      end
    end
    -- ex: https://github.com/vscode-neovim/vscode-neovim/blob/c095de724ed0aeb3d94f9bc8552fffedc4dbecff/runtime/vscode/clipboard.lua#L6
    local currText = vscode.eval("await vscode.env.clipboard.readText()", { args = { callback = callback } }, 200)
    vscode.notify("Copied relative file path")
  end)
  vim.keymap.set("n", "<localleader>sb", function()
    vscode.action("bookmarksExplorer.focus")
  end)
  vim.keymap.set("n", "<leader>fb", function()
    vscode.action("")
  end)
  vim.keymap.set("n", "<leader>fB", function()
    vscode.action("bookmarks.listFromAllFiles")
  end)
  vim.keymap.set("n", "<leader>bj", function()
    vscode.action("bookmarks.jumpToNext")
  end)
  vim.keymap.set("n", "<leader>bk", function()
    vscode.action("bookmarks.jumpToPrevious")
  end)
  -- TODO : verify
  -- <leader>fh+<key> for bookmark l=related
  -- j , k for next and previous bookmarks.jumpToNext bookmarks.jumpToPrevious
  -- a add bookmark bookmarks.toggle
  -- A add bookmark with label bookmarks.toggleLabeled
  -- m for open menu bookmarks.listFromAllFiles
  vim.keymap.set("n", "<leader>fhj", function()
    vscode.action("bookmarks.jumpToNext")
  end)
  vim.keymap.set("n", "<leader>fhk", function()
    vscode.action("bookmarks.jumpToPrevious")
  end)
  vim.keymap.set("n", "<leader>fha", function()
    vscode.action("bookmarks.toggle")
  end)
  vim.keymap.set("n", "<leader>fhA", function()
    vscode.action("bookmarks.toggleLabeled")
  end)
  vim.keymap.set("n", "<leader>fhL", function()
    vscode.action("bookmarksExplorer.focus")
  end)
  vim.keymap.set("n", "<leader>fhl", function()
    vscode.action("bookmarks.listFromAllFiles")
  end)
  vim.keymap.set("n", "gr", function()
    vscode.action("editor.action.peekDefinition")
  end)
  vim.keymap.set("n", "gR", function()
    vscode.action("references-view.findReferences")
  end)

  -- to be revisited ?
  vim.keymap.set("n", "<leader>en", function()
    vscode.action("editor.action.marker.next")
  end)
  vim.keymap.set("n", "<leader>ep", function()
    vscode.action("editor.action.marker.prev")
  end)
  vim.keymap.set("n", "Lj", function()
    vscode.action("editor.action.marker.nextInFiles")
  end)
  vim.keymap.set("n", "Lk", function()
    vscode.action("editor.action.marker.prevInFiles")
  end)

  -- Add some vscode specific keymaps
  -- Refer to
  --
end

-- vim.api.nvim_create_autocmd("User", {
--   pattern = "NvimIdeKeymaps", -- This pattern will be called when the plugin is loaded
--   callback = function()
--   end,
-- })

return {
  {
    "xiyaowong/fast-cursor-move.nvim",
    vscode = true,
    enabled = vim.g.vscode,
    init = function()
      -- Disable acceleration, use key repeat settings instead
      vim.g.fast_cursor_move_acceleration = false
    end,
  },
  -- Refer https://github.com/vscode-neovim/vscode-multi-cursor.nvim to more usages
  -- gcc: clear multi cursors
  -- gc: create multi cursors
  -- mi/mI/ma/MA: insert text at each cursor
  {
    "vscode-neovim/vscode-multi-cursor.nvim",
    event = "VeryLazy",
    cond = not not vim.g.vscode,
    opts = {},
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { highlight = { enable = false } },
  },
}
