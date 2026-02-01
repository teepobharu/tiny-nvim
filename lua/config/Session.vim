let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let Lf_PopupColorscheme = "everforest"
let VM_Extend_hl = "Visual"
let VM_Insert_hl = "VMCursor"
let VM_Mono_hl = "VMCursor"
let NetrwMenuPriority =  80 
let Lf_StlColorscheme = "everforest"
let BufferlinePinnedBuffers = "/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myEditor.lua,/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/myKeys.md"
let NetrwTopLvlMenu = "Netrw."
let VM_Cursor_hl = "VMCursor"
silent only
silent tabonly
cd ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +806 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua
badd +90 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/telescope_pickers.lua
badd +138 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/neotree.lua
badd +296 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/input.lua
badd +129 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/mypath.lua
badd +206 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/prompts_helper.lua
badd +816 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/snacks_actions.lua
badd +1021 ~/dotfiles/.config/nvim3_jelly_tinynvim/tests/myTest.lua
badd +1154 ~/dotfiles/.config/nvim3_jelly_tinynvim/tests/myTestSnacks.lua
badd +559 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myEditor.lua
badd +41 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/coding.lua
badd +312 ~/dotfiles/.config/nvim3_jelly_tinynvim/myKeys.md
badd +31 ~/dotfiles/.config/nvim3_jelly_tinynvim/init.lua
badd +126 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/runner.lua
badd +252 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/snacks_terminal.lua
badd +217 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/myautocmds.lua
badd +186 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/my_avante_utils.lua
badd +27 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/term_util.lua
badd +3 ~/dotfiles/.config/nvim3_jelly_tinynvim/docs/avante_20260107_keys_model.md
badd +6 ~/dotfiles/.config/nvim3_jelly_tinynvim/docs/snacks_misc.md
badd +26 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua
badd +663 ~/dotfiles/.config/nvim3_jelly_tinynvim/docs/codecompanion_20260107_update.md
badd +41 ~/dotfiles/.config/nvim3_jelly_tinynvim/docs/codecompanion_20260107_model.md
badd +55 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/cmd.lua
badd +4 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/path.lua
badd +15 ~/dotfiles/.config/nvim3_jelly_tinynvim/CLAUDE.md
badd +18 ~/dotfiles/.config/nvim3_jelly_tinynvim/docs/misc_nvim.md
badd +27 ~/dotfiles/.config/nvim3_jelly_tinynvim/docs/avante_20260121_update.md
badd +65 ~/dotfiles/.config/nvim3_jelly_tinynvim/myREADME.md
badd +9 ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/drafts/copillotnvim-updatenotwork-20260125.md
badd +76 ~/.local/share/nvim3_jelly_tinynvim/lazy/sidekick.nvim/lua/sidekick/cli/init.lua
badd +1 ~/.local/share/nvim3_jelly_tinynvim/lazy/sidekick.nvim/lua/sidekick/cli/ui/select.lua
badd +69 ~/dotfiles/.config/nvim3_jelly_tinynvim/docs/memory/snacks_picker.md
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/snippets/global.json
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/done/\"snippets/global.json\"
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/done/\'lua/plugins/init.lua
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/done/\[docs/misc_nvim.md
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/done/lua/plugins/init.lua
badd +8 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/file_reference.lua
badd +1 gitsigns:///Users/tharutaipree/dotfiles/.git/modules/.config/nvim3_jelly_tinynvim//:0:lua/config/mykeymaps.lua
badd +67 ~/dotfiles/.config/nvim3_jelly_tinynvim/tests/test_goto_file_edge_cases.md
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/tests/lua/config/mykeymapsx.lua
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/docs/memory/gitsigns.md
badd +81 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/snacks.lua
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/\$XDG_CONFIG_HOME/\$NVIM_APPNAME/lua/config/keymaps.lua
badd +4 ~/.local/share/nvim3_jelly_tinynvim/lazy/kanagawa.nvim/lua/kanagawa/init.lua
badd +57 ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/review/investigate-bigfile-startup-time.md
badd +270 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/tests/\$\{XDG_CONFIG_HOME}/nvim3_jelly_tinynvim/init.lua
badd +90 ~/dotfiles/.config/nvim3_jelly_tinynvim/docs/task_tracking.md
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/keyutil.lua
badd +53 ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/drafts/codecompanion_dynamic_model_toggle.md
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/my_codecompanion_actions.lua
badd +16 ~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/interactions/inline/init.lua
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/drafts/lua/codecompanion/interactions/inline/init.lua
badd +3 ~/AgodaGit/be/booking-query/api-clients/src/main/scala/com/agoda/bapiq/clients/aapi/models/SearchDetails.scala
badd +1 ~/AgodaGit/be/booking-query/api-clients/src/main/scala/com/agoda/bapiq/clients/aapi/models/SearchDetails.scala:L3
badd +11 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/myopts.lua
badd +141 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/codecompanion.lua
badd +1 ~/dotfiles/.config/nvim/init.lua
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/init.lua
badd +1 ~/.local/share/nvim/lazy/overseer.nvim
badd +53 ~/dotfiles/.config/nvim3_jelly_tinynvim/tests/test_env_var_expansion.md
badd +1 ~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/CHANGELOG.md
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/utils.mypath
badd +8 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/vscode_global/vscode_global.lua
badd +141 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/startup/lsp_log_trim.lua
badd +1 ~/Library/Application\ Support/Code/User/tasks.json
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/vscode_global/overseer.template.vscode
badd +274 ~/dotfiles/.config/nvim3_jelly_tinynvim/docs/tasks/done/overseer_v2_migration_audit.md
badd +4 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/android_client/and_build.lua
badd +5 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/android_client/and_pick.lua
badd +184 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/android_client/and_test.lua
badd +166 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/dotnet/dotnet_test.lua
badd +4 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/mmb/mmb_pick.lua
badd +5 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/mmb/mmb_tests.lua
badd +5 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/tripviewbff/tripviewbff_pick.lua
badd +8 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/common_shell/grep_async.lua
badd +322 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/user/run_script_deterministic.lua
badd +7 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/user/run_script.lua
badd +419 ~/dotfiles/.config/nvim3_jelly_tinynvim/\[CodeCompanion]\ 179
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/android_client/and_build.lua:
badd +1 ~/.local/share/nvim3_jelly_tinynvim/lazy/gitsigns.nvim/lua/gitsigns.lua
badd +22 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/avante.lua
badd +8 ~/dotfiles/.config/nvim3_jelly_tinynvim/test.ts
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/ui.lua
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/.nvimlog
badd +51 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myNoice.lua
badd +74 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myGit.lua
badd +33 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mydefault-nvim-config.lua
badd +4 ~/dotfiles/.config/nvim3_jelly_tinynvim/aa.ts
badd +6 ~/.local/share/nvim3_jelly_tinynvim/lazy/hurl.nvim/lua/hurl/git_utils.lua
badd +31 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/tmux-navigator.lua
badd +29 ~/dotfiles/.config/nvim3_jelly_tinynvim/lsp/gitlablsp.lua
badd +79 ~/dotfiles/.config/nvim3_jelly_tinynvim/scripts/install-tools.sh
badd +51 ~/dotfiles/.config/nvim3_jelly_tinynvim/lsp/yamlls.lua
badd +23 ~/dotfiles/.config/nvim3_jelly_tinynvim/lsp/biome.lua
badd +21 ~/dotfiles/.config/nvim3_jelly_tinynvim/lsp/eslint.lua
badd +30 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/copilot-chat.lua
badd +50 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ai.lua
badd +11 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myAi.lua
badd +63 ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/open/snacks_yank_preview.md
badd +103 ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/review/lsp-log-daily-trim.md
badd +13 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/startup/simple_startup.lua
badd +36 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/lazy.lua
badd +17 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/options.lua
badd +1 ~/.vimrc
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/startup/\$VIMRC
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/open/2026-01-26-enhance-toggle-external-files-picker.md
badd +1 ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/drafts/neotree_snacks_keybinds.md
argglobal
%argdel
$argadd myEditor.lua
tabnew +setlocal\ bufhidden=wipe
tabnew +setlocal\ bufhidden=wipe
tabnew +setlocal\ bufhidden=wipe
tabnew +setlocal\ bufhidden=wipe
tabnew +setlocal\ bufhidden=wipe
tabnew +setlocal\ bufhidden=wipe
tabrewind
edit ~/dotfiles/.config/nvim3_jelly_tinynvim/myKeys.md
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd _ | wincmd |
split
1wincmd k
wincmd w
wincmd w
wincmd _ | wincmd |
split
1wincmd k
wincmd w
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe '1resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 1resize ' . ((&columns * 106 + 106) / 212)
exe '2resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 2resize ' . ((&columns * 106 + 106) / 212)
exe '3resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 3resize ' . ((&columns * 105 + 106) / 212)
exe '4resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 4resize ' . ((&columns * 105 + 106) / 212)
argglobal
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.require'utils.ui'.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 184 - ((5 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 184
normal! 08|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/myopts.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/myopts.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/myopts.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/myopts.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/myKeys.md
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 11 - ((10 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 11
normal! 0
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/myKeys.md
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 2 - ((1 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 2
normal! 0
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/myKeys.md
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 30 - ((5 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 30
normal! 0
wincmd w
exe '1resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 1resize ' . ((&columns * 106 + 106) / 212)
exe '2resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 2resize ' . ((&columns * 106 + 106) / 212)
exe '3resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 3resize ' . ((&columns * 105 + 106) / 212)
exe '4resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 4resize ' . ((&columns * 105 + 106) / 212)
tabnext
edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/user/run_script_deterministic.lua
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
vsplit
wincmd _ | wincmd |
vsplit
wincmd _ | wincmd |
vsplit
3wincmd h
wincmd _ | wincmd |
split
1wincmd k
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd _ | wincmd |
split
1wincmd k
wincmd w
wincmd w
wincmd w
wincmd w
wincmd _ | wincmd |
split
1wincmd k
wincmd w
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd w
wincmd w
wincmd w
wincmd _ | wincmd |
split
1wincmd k
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd w
wincmd w
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe '1resize ' . ((&lines * 11 + 25) / 51)
exe 'vert 1resize ' . ((&columns * 30 + 106) / 212)
exe '2resize ' . ((&lines * 21 + 25) / 51)
exe 'vert 2resize ' . ((&columns * 30 + 106) / 212)
exe '3resize ' . ((&lines * 33 + 25) / 51)
exe 'vert 3resize ' . ((&columns * 29 + 106) / 212)
exe '4resize ' . ((&lines * 15 + 25) / 51)
exe 'vert 4resize ' . ((&columns * 60 + 106) / 212)
exe '5resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 5resize ' . ((&columns * 60 + 106) / 212)
exe '6resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 6resize ' . ((&columns * 30 + 106) / 212)
exe '7resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 7resize ' . ((&columns * 29 + 106) / 212)
exe 'vert 8resize ' . ((&columns * 29 + 106) / 212)
exe '9resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 9resize ' . ((&columns * 30 + 106) / 212)
exe '10resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 10resize ' . ((&columns * 29 + 106) / 212)
exe '11resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 11resize ' . ((&columns * 60 + 106) / 212)
argglobal
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/vscode_global/vscode_global.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=0
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
206
sil! normal! zo
let s:l = 128 - ((127 * winheight(0) + 5) / 11)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 128
normal! 0
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/user/run_script.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/user/run_script.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/user/run_script.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/user/run_script.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/user/run_script_deterministic.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
1
sil! normal! zo
let s:l = 7 - ((6 * winheight(0) + 10) / 21)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 7
normal! 03|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/vscode_global/vscode_global.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/vscode_global/vscode_global.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/vscode_global/vscode_global.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/vscode_global/vscode_global.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/user/run_script_deterministic.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
6
sil! normal! zo
9
sil! normal! zo
29
sil! normal! zo
let s:l = 8 - ((7 * winheight(0) + 16) / 33)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 8
normal! 03|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/common_shell/grep_async.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/common_shell/grep_async.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/common_shell/grep_async.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/common_shell/grep_async.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/tripviewbff/tripviewbff_pick.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
2
sil! normal! zo
6
sil! normal! zo
25
sil! normal! zo
40
sil! normal! zo
57
sil! normal! zo
58
sil! normal! zo
59
sil! normal! zo
70
sil! normal! zo
76
sil! normal! zo
let s:l = 8 - ((-11 * winheight(0) + 7) / 15)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 8
normal! 035|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myEditor.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=0
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
1012
sil! normal! zo
1013
sil! normal! zo
1016
sil! normal! zo
1019
sil! normal! zo
1022
sil! normal! zo
1025
sil! normal! zo
1028
sil! normal! zo
1012
sil! normal! zc
let s:l = 1105 - ((66 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1105
normal! 0
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/snacks_actions.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
1012
sil! normal! zo
1046
sil! normal! zo
1047
sil! normal! zo
1056
sil! normal! zo
1064
sil! normal! zo
1080
sil! normal! zo
1110
sil! normal! zo
1128
sil! normal! zo
1146
sil! normal! zo
1147
sil! normal! zo
1148
sil! normal! zo
1149
sil! normal! zo
1150
sil! normal! zo
1165
sil! normal! zo
1168
sil! normal! zo
1169
sil! normal! zo
let s:l = 168 - ((4 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 168
normal! 014|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/tripviewbff/tripviewbff_pick.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/tripviewbff/tripviewbff_pick.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/tripviewbff/tripviewbff_pick.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/tripviewbff/tripviewbff_pick.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
2
sil! normal! zo
6
sil! normal! zo
32
sil! normal! zo
42
sil! normal! zo
43
sil! normal! zo
44
sil! normal! zo
let s:l = 4 - ((1 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 4
normal! 03|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/android_client/and_test.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
1012
sil! normal! zo
1046
sil! normal! zo
1047
sil! normal! zo
1056
sil! normal! zo
1064
sil! normal! zo
1080
sil! normal! zo
1110
sil! normal! zo
1128
sil! normal! zo
1146
sil! normal! zo
1147
sil! normal! zo
1148
sil! normal! zo
1149
sil! normal! zo
1150
sil! normal! zo
1165
sil! normal! zo
1168
sil! normal! zo
1169
sil! normal! zo
let s:l = 175 - ((23 * winheight(0) + 24) / 49)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 175
let s:c = 11 - ((8 * winwidth(0) + 14) / 29)
if s:c > 0
  exe 'normal! ' . s:c . '|zs' . 11 . '|'
else
  normal! 011|
endif
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/android_client/and_pick.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/android_client/and_pick.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/android_client/and_pick.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/overseer/template/agoda/android_client/and_pick.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/\[CodeCompanion]\ 179
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
2
sil! normal! zo
let s:l = 5 - ((4 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 5
let s:c = 80 - ((12 * winwidth(0) + 15) / 30)
if s:c > 0
  exe 'normal! ' . s:c . '|zs' . 80 . '|'
else
  normal! 080|
endif
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/tests/myTestSnacks.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/tests/myTestSnacks.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/tests/myTestSnacks.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/tests/myTestSnacks.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/docs/memory/snacks_picker.md
setlocal foldmethod=manual
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
silent! normal! zE
let &fdl = &fdl
let s:l = 1335 - ((4 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1335
normal! 05|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/editor_keymaps.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myEditor.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
26
sil! normal! zo
47
sil! normal! zo
96
sil! normal! zo
113
sil! normal! zo
166
sil! normal! zo
166
sil! normal! zc
187
sil! normal! zo
189
sil! normal! zo
192
sil! normal! zo
197
sil! normal! zo
205
sil! normal! zo
210
sil! normal! zo
211
sil! normal! zo
218
sil! normal! zo
239
sil! normal! zo
247
sil! normal! zo
256
sil! normal! zo
258
sil! normal! zo
351
sil! normal! zo
352
sil! normal! zo
363
sil! normal! zo
370
sil! normal! zo
378
sil! normal! zo
447
sil! normal! zo
452
sil! normal! zo
460
sil! normal! zo
470
sil! normal! zo
478
sil! normal! zo
486
sil! normal! zo
494
sil! normal! zo
501
sil! normal! zo
508
sil! normal! zo
515
sil! normal! zo
522
sil! normal! zo
529
sil! normal! zo
536
sil! normal! zo
538
sil! normal! zo
546
sil! normal! zo
548
sil! normal! zo
557
sil! normal! zo
559
sil! normal! zo
575
sil! normal! zo
577
sil! normal! zo
591
sil! normal! zo
593
sil! normal! zo
600
sil! normal! zo
611
sil! normal! zo
617
sil! normal! zo
618
sil! normal! zo
629
sil! normal! zo
636
sil! normal! zo
638
sil! normal! zo
640
sil! normal! zo
641
sil! normal! zo
642
sil! normal! zo
653
sil! normal! zo
655
sil! normal! zo
683
sil! normal! zo
690
sil! normal! zo
692
sil! normal! zo
702
sil! normal! zo
703
sil! normal! zo
727
sil! normal! zo
729
sil! normal! zo
738
sil! normal! zo
740
sil! normal! zo
747
sil! normal! zo
749
sil! normal! zo
757
sil! normal! zo
759
sil! normal! zo
767
sil! normal! zo
769
sil! normal! zo
778
sil! normal! zo
781
sil! normal! zo
795
sil! normal! zo
798
sil! normal! zo
806
sil! normal! zo
808
sil! normal! zo
817
sil! normal! zo
819
sil! normal! zo
820
sil! normal! zo
823
sil! normal! zo
832
sil! normal! zo
856
sil! normal! zo
857
sil! normal! zo
865
sil! normal! zo
873
sil! normal! zo
881
sil! normal! zo
889
sil! normal! zo
900
sil! normal! zo
911
sil! normal! zo
912
sil! normal! zo
913
sil! normal! zo
914
sil! normal! zo
929
sil! normal! zo
930
sil! normal! zo
940
sil! normal! zo
941
sil! normal! zo
951
sil! normal! zo
952
sil! normal! zo
968
sil! normal! zo
976
sil! normal! zo
981
sil! normal! zo
984
sil! normal! zo
992
sil! normal! zo
999
sil! normal! zo
1012
sil! normal! zo
1046
sil! normal! zo
1047
sil! normal! zo
1056
sil! normal! zo
1064
sil! normal! zo
1080
sil! normal! zo
1110
sil! normal! zo
1128
sil! normal! zo
1146
sil! normal! zo
1147
sil! normal! zo
1148
sil! normal! zo
1149
sil! normal! zo
1150
sil! normal! zo
1165
sil! normal! zo
1168
sil! normal! zo
1169
sil! normal! zo
let s:l = 26 - ((12 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 26
normal! 0
wincmd w
exe '1resize ' . ((&lines * 11 + 25) / 51)
exe 'vert 1resize ' . ((&columns * 30 + 106) / 212)
exe '2resize ' . ((&lines * 21 + 25) / 51)
exe 'vert 2resize ' . ((&columns * 30 + 106) / 212)
exe '3resize ' . ((&lines * 33 + 25) / 51)
exe 'vert 3resize ' . ((&columns * 29 + 106) / 212)
exe '4resize ' . ((&lines * 15 + 25) / 51)
exe 'vert 4resize ' . ((&columns * 60 + 106) / 212)
exe '5resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 5resize ' . ((&columns * 60 + 106) / 212)
exe '6resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 6resize ' . ((&columns * 30 + 106) / 212)
exe '7resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 7resize ' . ((&columns * 29 + 106) / 212)
exe 'vert 8resize ' . ((&columns * 29 + 106) / 212)
exe '9resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 9resize ' . ((&columns * 30 + 106) / 212)
exe '10resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 10resize ' . ((&columns * 29 + 106) / 212)
exe '11resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 11resize ' . ((&columns * 60 + 106) / 212)
tabnext
edit ~/dotfiles/.config/nvim3_jelly_tinynvim/test.ts
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
split
1wincmd k
wincmd _ | wincmd |
vsplit
wincmd _ | wincmd |
vsplit
2wincmd h
wincmd w
wincmd w
wincmd _ | wincmd |
split
1wincmd k
wincmd w
wincmd w
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe '1resize ' . ((&lines * 32 + 25) / 51)
exe 'vert 1resize ' . ((&columns * 70 + 106) / 212)
exe '2resize ' . ((&lines * 32 + 25) / 51)
exe 'vert 2resize ' . ((&columns * 70 + 106) / 212)
exe '3resize ' . ((&lines * 10 + 25) / 51)
exe 'vert 3resize ' . ((&columns * 70 + 106) / 212)
exe '4resize ' . ((&lines * 21 + 25) / 51)
exe 'vert 4resize ' . ((&columns * 70 + 106) / 212)
exe '5resize ' . ((&lines * 16 + 25) / 51)
argglobal
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/avante.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.require'utils.ui'.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 8 - ((7 * winheight(0) + 16) / 32)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 8
normal! 02|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mydefault-nvim-config.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mydefault-nvim-config.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mydefault-nvim-config.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mydefault-nvim-config.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/test.ts
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 21 - ((20 * winheight(0) + 16) / 32)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 21
normal! 0
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua
endif
balt ~/.local/share/nvim3_jelly_tinynvim/lazy/gitsigns.nvim/lua/gitsigns.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
13
sil! normal! zo
49
sil! normal! zo
259
sil! normal! zo
262
sil! normal! zo
271
sil! normal! zo
325
sil! normal! zo
329
sil! normal! zo
330
sil! normal! zo
332
sil! normal! zo
335
sil! normal! zo
348
sil! normal! zo
351
sil! normal! zo
354
sil! normal! zo
355
sil! normal! zo
356
sil! normal! zo
363
sil! normal! zo
let s:l = 337 - ((3 * winheight(0) + 5) / 10)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 337
normal! 07|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/avante.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.require'utils.ui'.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
13
sil! normal! zo
325
sil! normal! zo
329
sil! normal! zo
330
sil! normal! zo
332
sil! normal! zo
335
sil! normal! zo
325
sil! normal! zc
let s:l = 313 - ((10 * winheight(0) + 10) / 21)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 313
normal! 04|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myGit.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myGit.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myGit.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myGit.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/path.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
1
sil! normal! zo
2
sil! normal! zo
4
sil! normal! zo
30
sil! normal! zo
32
sil! normal! zo
35
sil! normal! zo
35
sil! normal! zc
45
sil! normal! zo
79
sil! normal! zo
let s:l = 90 - ((66 * winheight(0) + 8) / 16)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 90
normal! 021|
wincmd w
exe '1resize ' . ((&lines * 32 + 25) / 51)
exe 'vert 1resize ' . ((&columns * 70 + 106) / 212)
exe '2resize ' . ((&lines * 32 + 25) / 51)
exe 'vert 2resize ' . ((&columns * 70 + 106) / 212)
exe '3resize ' . ((&lines * 10 + 25) / 51)
exe 'vert 3resize ' . ((&columns * 70 + 106) / 212)
exe '4resize ' . ((&lines * 21 + 25) / 51)
exe 'vert 4resize ' . ((&columns * 70 + 106) / 212)
exe '5resize ' . ((&lines * 16 + 25) / 51)
tabnext
edit ~/dotfiles/.config/nvim3_jelly_tinynvim/aa.ts
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
vsplit
wincmd _ | wincmd |
vsplit
wincmd _ | wincmd |
vsplit
3wincmd h
wincmd _ | wincmd |
split
1wincmd k
wincmd w
wincmd w
wincmd w
wincmd w
wincmd _ | wincmd |
split
1wincmd k
wincmd w
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe '1resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 1resize ' . ((&columns * 52 + 106) / 212)
exe '2resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 2resize ' . ((&columns * 52 + 106) / 212)
exe 'vert 3resize ' . ((&columns * 52 + 106) / 212)
exe 'vert 4resize ' . ((&columns * 53 + 106) / 212)
exe '5resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 5resize ' . ((&columns * 52 + 106) / 212)
exe '6resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 6resize ' . ((&columns * 52 + 106) / 212)
argglobal
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myGit.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.require'utils.ui'.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 4 - ((3 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 4
normal! 07|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myGit.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myGit.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myGit.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myGit.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/test.ts
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 44 - ((19 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 44
normal! 0
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mydefault-nvim-config.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.require'utils.ui'.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
13
sil! normal! zo
259
sil! normal! zo
262
sil! normal! zo
271
sil! normal! zo
348
sil! normal! zo
351
sil! normal! zo
let s:l = 270 - ((12 * winheight(0) + 24) / 49)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 270
normal! 08|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/scripts/install-tools.sh", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/scripts/install-tools.sh | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/scripts/install-tools.sh | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/scripts/install-tools.sh
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lsp/gitlablsp.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.require'utils.ui'.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 74 - ((18 * winheight(0) + 24) / 49)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 74
normal! 03|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/ui.lua
setlocal foldmethod=diff
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=0
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 341 - ((4 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 341
normal! 04|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/init.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/init.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/init.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/init.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 26 - ((17 * winheight(0) + 12) / 24)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 26
normal! 04|
wincmd w
exe '1resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 1resize ' . ((&columns * 52 + 106) / 212)
exe '2resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 2resize ' . ((&columns * 52 + 106) / 212)
exe 'vert 3resize ' . ((&columns * 52 + 106) / 212)
exe 'vert 4resize ' . ((&columns * 53 + 106) / 212)
exe '5resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 5resize ' . ((&columns * 52 + 106) / 212)
exe '6resize ' . ((&lines * 24 + 25) / 51)
exe 'vert 6resize ' . ((&columns * 52 + 106) / 212)
tabnext
edit ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/review/lsp-log-daily-trim.md
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd _ | wincmd |
split
1wincmd k
wincmd _ | wincmd |
vsplit
wincmd _ | wincmd |
vsplit
2wincmd h
wincmd w
wincmd w
wincmd w
wincmd w
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe '1resize ' . ((&lines * 23 + 25) / 51)
exe 'vert 1resize ' . ((&columns * 53 + 106) / 212)
exe '2resize ' . ((&lines * 23 + 25) / 51)
exe 'vert 2resize ' . ((&columns * 38 + 106) / 212)
exe '3resize ' . ((&lines * 23 + 25) / 51)
exe 'vert 3resize ' . ((&columns * 66 + 106) / 212)
exe '4resize ' . ((&lines * 23 + 25) / 51)
exe 'vert 4resize ' . ((&columns * 159 + 106) / 212)
exe 'vert 5resize ' . ((&columns * 52 + 106) / 212)
argglobal
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/review/investigate-bigfile-startup-time.md
setlocal foldmethod=expr
setlocal foldexpr=v:lua.require'utils.ui'.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 103 - ((5 * winheight(0) + 11) / 23)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 103
normal! 03|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/init.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/init.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/init.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/init.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mydefault-nvim-config.lua
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
25
sil! normal! zo
let s:l = 31 - ((8 * winheight(0) + 11) / 23)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 31
normal! 05|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua
endif
balt ~/.vimrc
setlocal foldmethod=marker
setlocal foldexpr=v:lua.require'utils.ui'.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=10
setlocal foldminlines=1
setlocal foldnestmax=10
setlocal foldenable
let s:l = 806 - ((11 * winheight(0) + 11) / 23)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 806
normal! 016|
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/startup/simple_startup.lua", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/startup/simple_startup.lua | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/startup/simple_startup.lua | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/startup/simple_startup.lua
endif
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/config/lazy.lua
setlocal foldmethod=marker
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=10
setlocal foldenable
let s:l = 13 - ((6 * winheight(0) + 11) / 23)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 13
normal! 0
wincmd w
argglobal
if bufexists(fnamemodify("~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/open/snacks_yank_preview.md", ":p")) | buffer ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/open/snacks_yank_preview.md | else | edit ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/open/snacks_yank_preview.md | endif
if &buftype ==# 'terminal'
  silent file ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/open/snacks_yank_preview.md
endif
setlocal foldmethod=expr
setlocal foldexpr=v:lua.require'utils.ui'.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=99
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 63 - ((35 * winheight(0) + 23) / 47)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 63
normal! 054|
wincmd w
exe '1resize ' . ((&lines * 23 + 25) / 51)
exe 'vert 1resize ' . ((&columns * 53 + 106) / 212)
exe '2resize ' . ((&lines * 23 + 25) / 51)
exe 'vert 2resize ' . ((&columns * 38 + 106) / 212)
exe '3resize ' . ((&lines * 23 + 25) / 51)
exe 'vert 3resize ' . ((&columns * 66 + 106) / 212)
exe '4resize ' . ((&lines * 23 + 25) / 51)
exe 'vert 4resize ' . ((&columns * 159 + 106) / 212)
exe 'vert 5resize ' . ((&columns * 52 + 106) / 212)
tabnext
edit ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/drafts/neotree_snacks_keybinds.md
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt ~/dotfiles/.config/nvim3_jelly_tinynvim/tasks/open/2026-01-26-enhance-toggle-external-files-picker.md
setlocal foldmethod=expr
setlocal foldexpr=v:lua.require'utils.ui'.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=10
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
let s:l = 1 - ((0 * winheight(0) + 23) / 47)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1
normal! 0
tabnext
edit ~/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myEditor.lua
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
1argu
setlocal foldmethod=expr
setlocal foldexpr=v:lua.vim.treesitter.foldexpr()
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=10
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
22
sil! normal! zo
98
sil! normal! zo
102
sil! normal! zo
108
sil! normal! zo
151
sil! normal! zo
156
sil! normal! zo
175
sil! normal! zo
176
sil! normal! zo
192
sil! normal! zo
198
sil! normal! zo
200
sil! normal! zo
201
sil! normal! zo
202
sil! normal! zo
204
sil! normal! zc
202
sil! normal! zc
290
sil! normal! zo
504
sil! normal! zo
507
sil! normal! zo
549
sil! normal! zo
552
sil! normal! zo
560
sil! normal! zo
561
sil! normal! zo
585
sil! normal! zo
594
sil! normal! zo
595
sil! normal! zo
654
sil! normal! zo
661
sil! normal! zo
662
sil! normal! zo
685
sil! normal! zo
704
sil! normal! zo
719
sil! normal! zo
745
sil! normal! zo
754
sil! normal! zo
781
sil! normal! zo
801
sil! normal! zo
804
sil! normal! zo
806
sil! normal! zo
807
sil! normal! zo
826
sil! normal! zo
829
sil! normal! zo
831
sil! normal! zo
890
sil! normal! zo
904
sil! normal! zo
918
sil! normal! zo
921
sil! normal! zo
929
sil! normal! zo
930
sil! normal! zo
937
sil! normal! zo
945
sil! normal! zo
969
sil! normal! zo
1014
sil! normal! zo
1015
sil! normal! zo
1033
sil! normal! zo
1036
sil! normal! zo
1037
sil! normal! zo
1049
sil! normal! zo
1049
sil! normal! zo
1119
sil! normal! zo
1156
sil! normal! zo
1160
sil! normal! zo
1162
sil! normal! zo
1165
sil! normal! zo
1173
sil! normal! zo
1183
sil! normal! zo
1203
sil! normal! zo
1205
sil! normal! zo
1206
sil! normal! zo
1214
sil! normal! zo
1221
sil! normal! zo
1222
sil! normal! zo
1232
sil! normal! zo
1237
sil! normal! zo
1279
sil! normal! zo
1284
sil! normal! zo
1285
sil! normal! zo
let s:l = 559 - ((41 * winheight(0) + 23) / 47)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 559
normal! 012|
tabnext 7
if exists('s:wipebuf') && len(win_findbuf(s:wipebuf)) == 0 && getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=1 winwidth=1
let &shortmess = s:shortmess_save
let &winminheight = s:save_winminheight
let &winminwidth = s:save_winminwidth
let s:sx = expand("<sfile>:p:r")."x.vim"
if filereadable(s:sx)
  exe "source " . fnameescape(s:sx)
endif
let &g:so = s:so_save | let &g:siso = s:siso_save
set hlsearch
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
