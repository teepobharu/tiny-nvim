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

Migration added

- [ ] Zozxide snacks

LSP

- check with :check lsp or <l>li
- [ ] CMP codecompanion fix - remove enabled list
  - [ ] CMP overrides copilot
  - [x] CMP enter
        disabled
        dcompanion
- [ ] lua lsp
- [ ] remove lsp saga , unused mapping
- [ ] bash
- [ ] ts
- [ ] Check python works

### Improvements

- [ ] sesion picker from snacks

### Deprecated

- [ ] FZF
  - [ ] remove refs in neotree

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
