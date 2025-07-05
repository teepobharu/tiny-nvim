# Changes

- No more lspconfig dependecy, now directly configure `lsp` from neovim
- LSP has to be downloaded with script (no more mason support)[./install.sh]
- LazyDev helper to optimzied Lua space to show completion on only loaded module ?

## Migration Notes

- copied utils
- rename path utils to mypath
- seems boot time is faster than before
- no more telescope
  LSP
  Tools : mise, uv, go, npm
- mise is versioning tools
- uv (python based ?)
- tsc -v

```sh
mise install uv@latest -v
# if alrd install see nothing
mise ls
mise up -i
mise activate
# need zsh / re enter nvim to see
npm -g list
tsc -v  # if error uses msg : not typescript cli that is looking for
npm install -g -f typescript

uv tool install
uv tool list
```

## TODO

### Migration fixes

- [x] sesssion picker works
- [x] terminal toggle check c-\_ vs c-t
- [ ] terminal toggle check c-\_ vs c-t
- [x] LSP keymaps

Fixes attempt

- [ ] uf auto format not working

Migration added

- [ ] Zozxide snacks

LSP
Guides: https://lsp-zero.netlify.app/blog/lsp-config-without-plugins.html

- browse default conf: https://github.com/neovim/nvim-lspconfig/blob/12d163c5c2b05e85431f2deef5d9d59a8fd8dfc2/lua/lspconfig/configs/lua_ls.lua
- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#pyright

- check with :check lsp
- [ ] SH not working only ref work ?
- [ ] Lua declaration Lib not working only ref work ?
- [ ] CMP codecompanion fix - remove enabled list
  - [ ] CMP overrides copilot
  - [x] CMP enter
        disabled
        dcompanion
- [ ] Default mapping not used / not used in init get_default_keymap lsp : used in on_capability setup to set with nvim key
  - grn, conflict with gr snacks, use lsp saga
  - try search key with lsp default action work
- [ ] lua lsp
  - [x] format
  - [x] Ref gr - lib
  - [ ] Ref VIM not work
- [ ] Bash
  - [x] format
  - [x] Ref gr - lib
  - [x] GD from other file
  - [x] rename lsp saga lr
- [ ] remove lsp saga , unused mapping
- [ ] bash
- [x] ts
  - [ ] readme
- [ ] Check python works

NV2 :

- work on vim definition
- toggle format work even code setup the same

### Improvements

- [ ] sesion picker from snacks

### Deprecated

- [ ] FZF
  - [ ] remove refs in neotree
        Do not like
- Copilot accept just some parts : copilot in auto complete - work around bind with c-c to change source around
  KEYS
- shift tab to tab in insert mode , tab to complete / new line

## Perf check

- Filtering with threshold > 100ms

### Now

```
  Startuptime: 218.02ms

  Based on the actual CPU time of the Neovim process till UIEnter.
  This is more accurate than `nvim --startuptime`.
    LazyStart 28.18ms
    LazyDone  118.83ms (+90.65ms)
    UIEnter   218.02ms (+99.2ms)

  Profile
    ●  lazy.nvim 256.18ms
      ➜  spec 208.51ms
    ●  startup 539.25ms
      ➜  start 477.97ms
        ★  start  blink.cmp 271.76ms
          ‒  blink.cmp/plugin/blink-cmp.lua 202.47ms
    ●  startuptime 218.02ms
    ●  VeryLazy 745.6ms
      ➜  avante.nvim 414.02ms
    ●  markdown 576.33ms
      ➜  render-markdown.nvim 417.15ms
        ★  nvim-treesitter 115.38ms
        ★  render-markdown.nvim/plugin/render-markdown.lua 297.7ms
      ➜  FileType 151.4ms
    ●  BufWritePre 128.93ms
    ●  spec 190.8ms
    ●  spec 103.88ms
    ●  <leader>av 155.57ms
      ➜  CopilotChat.nvim 155.56ms
    ●  spec 259.62ms
    ●  spec 193.94ms
      ➜  plugins.extra.myEditor 121.66ms
```

### NV2 version

```
  Startuptime: 218.02ms

  Based on the actual CPU time of the Neovim process till UIEnter.
  This is more accurate than `nvim --startuptime`.
    LazyStart 28.18ms
    LazyDone  118.83ms (+90.65ms)
    UIEnter   218.02ms (+99.2ms)

  Profile

  You can press <C-s> to change sorting between chronological order & time taken.
  Press <C-f> to filter profiling entries that took more time than a given threshold

    ●  lazy.nvim 256.18ms
      ➜  spec 208.51ms
    ●  startup 539.25ms
      ➜  start 477.97ms
        ★  start  blink.cmp 271.76ms
          ‒  blink.cmp/plugin/blink-cmp.lua 202.47ms
    ●  startuptime 218.02ms
    ●  VeryLazy 745.6ms
      ➜  avante.nvim 414.02ms
    ●  markdown 576.33ms
      ➜  render-markdown.nvim 417.15ms
        ★  nvim-treesitter 115.38ms
        ★  render-markdown.nvim/plugin/render-markdown.lua 297.7ms
      ➜  FileType 151.4ms
    ●  BufWritePre 128.93ms
    ●  spec 190.8ms
    ●  spec 103.88ms
    ●  <leader>av 155.57ms
      ➜  CopilotChat.nvim 155.56ms
    ●  spec 259.62ms
    ●  spec 193.94ms
      ➜  plugins.extra.myEditor 121.66ms

```
