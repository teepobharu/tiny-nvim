# Quickstart guidelines

- General
  Old key info at [Old keys](../nvim2_jelly_lzmigrate/myREADME_leg.md)

References docs:
- Snacks
-> previewer: /Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/snacks.nvim/lua/snacks/picker/init.lua
> - /Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/snacks.nvim/lua/snacks/picker/preview.lua
> - <url>https://www.reddit.com/r/neovim/comments/1j4e7fq/share_your_custom_snackspicker_sources</url>
> - <url>https://github.com/folke/snacks.nvim/blob/main/docs/picker.md</url>



## TODOs

- bind check qflist WIP
  - snacks not support multi delete binding c-x
  - trouble does not persist when dd but file visilbity gone
  - script with acmd seem not work ?
- focused file search and stop change dir in mono repo switch
  - observation: json files lsp root to .git
  - other .js .ts files work and trigger search within monorepo
  - WIP (https://github.com/nvim-neo-tree/neo-tree.nvim/blob/main/lua/neo-tree/defaults.lua)
    - try disable neotree cwd and move json lsp `root_markers` from .git to

- terminal 
  snacks term
  - [x] Send to active terminal in visible tab / screen  (current snacks key only send when there is term not open)
  - [x] 
  - desired logic when count is sent always match with snacks id term else create new and send if no count send find best match term visible / first terminal (id=1) if > 1 visible or the next available id by ascending sorting
  - [ ] fix: count in visual mode not work
  - [ ] fix: count in n, v mode not force new term when id not match
  search
  - [x] tmux win search
    - [ ] support preview + delete 


- LSP
 - [x] glab works strangely on some files 2025-12-10
    - references,def: build,releases,rules,cache but not tests on tripsweb 
    - custom ft works
    - [ ] check if root matter (on git root currently)
    - ./lsp/gitlablsp.lua
Chore 
- [x] handle selection gx Gf ignore space  / newline
- [x] gitsign hunks not support visual c-j,k

Snacks
- snacks upstream diff
- snacks upstream diff
- mega ref git diff files - preview
- fix switch cwd to use refresh instead
- cwd: fuzzy matcher markers
- ignore case toggle
- toggle persist

Nav
- [x] tab navigations

Git
- leader-g-O open git on default browser rename leader-g-o

*Done*
0 - files hidden by default and pass options between toggle - don
  - caveat buffer hidden will also persist since it use current opts to persist state
  - preview <leader-f-G> not show changes
  - preview changes if not exist (show in preview)
 5 - Avante slash cmd get deprioritize to be below folder cmp
 1 - companion load prompt slash cmd*2
 2 - search term (with fix needed)
 - [ ] keybind to switch back search not work
 4 - global snippets not work again ...
- select new line fix gGx , gF - yes?
commands :
- oseer run dotnet test
- feat wip: grep word scope changer - default, gitroot, monorepo root 
- grep/files depth changer - a-/+
- select fix relative path from current file gF ? works need to check other example why sometime not

*current*
- subproject utility enhancement : support multiple matches (and condition) and mutliple results sort by nearest-gitroot
  - ie.  matcher { name = { "Clientside/", "Serverside/" } , type = "path", project_type = "dotnet" },
  - ie result : { matcher[1], matcher[2],... }

- avante models quick select switch between 4.1 mini and 5 mini and 5.2 codex 
  - ./docs/avante_20260107_keys_model.md
3 - codecompanion update try https://github.com/olimorris/codecompanion.nvim/blob/main/lua/codecompanion/config.lua
  - choose model in inline chat explore
- fix: fg in terminal wrong path based
- mega ref git diff files - sort diff options, keybind
  - diff ref alias compare , open fix
  - feat: switch refs with c-space
- ai: 
   - avante
      -  check gpt via oai 5.2 works when switch takes v long to load 
      -  check claude via vertex/
      -  check gemini via opai 
        - answer done
        - run tools ls / view error write tools ? :
            - Unable to submit request because function call `default_api:grep` in the 15. content block is missing a `thought_signature` \n No fallback model group found for original model_group=vertex_ai-gemini-3-pro-preview
            - https://docs.cloud.google.com/vertex-ai/generative-ai/docs/thought-signatures

      -  check gemini via vert/gem
- improve speed
  - preview file changes - seem like work on some files only (default preview)
*To verify*
1 - copilot prompt context check
  - prompt preview 
  - prompt additiona path of /Users/tharutaipree/AgodaGit/tools/trip-ai-tools/prompt/update_test_by_change.prompt.md
3 - send text to terminal from visible screen first then trust vcount later
  - trust vcount with id
    - [ ] buffer to last buffer (currently can use snacks) is there better way ?
To fix 

- [] AI: 
  - [ ] 08/12/2025 - Code companion prompts context


- [ ] fix toggle term keymap term cycle and other mappings - 20251201 wip
  - cycle C-E for all term type works
  - C-Tab not mappable work
  - C-space layout:
    - [x] toggleterm work no
    - [ ] snacks term no
  - [ ] c\_/ consistency to use snacks
  - issues : 
- [x] Feat: luasnip add in /scripts needs package.json
  - add p.json still not work print get correct dir [file](lua/plugins/coding.lua:72)
  - works now make sure the package.json settings and path link to corret json dir (copilot change from lazyload -> load but when revert still works)
  - https://github.com/rafamadriz/friendly-snippets/blob/main/package.json
  - example: https://github.com/rafamadriz/friendly-snippets/blob/main/snippets/global.json
- [x] branches 20251204
  - fzf c-s
  - bind open glab mr on branch

## Configurations

BASE Config [README.md](./README.md##Keymaps)
Updates from nv2: [Updates](./myREADME.md)

## Keymaps Summary

### General Guideliens

Main lazy setup for plugins :
<leader>-s + h(elp), b(uffers), t(odos), c(ommands history), k(eymaps), r(replace)

- s(symbols) Symbols {W,E toggle fold}
  <leader>-f + f(iles), b(uffers),c(config)
  <leader>-g + g(it), b(lame), c(ommit), s(tatus), h(unks actions)
- h => stage, diff
- gs - surround : replace, delete
  <leader>-w + windows, splits, delete, move
  <leader>-TAB + create / move tabs
  <leader>-d => debug

keymaps

- which-key
- toggle (i = C-R + backspace)
- <leader>? : mapping on current buffer

Understand each plugin more: https://www.youtube.com/watch?v=6pAG3BHurdM&ab_channel=JoseanMartinez

## AI

### Sidekick

https://github.com/folke/sidekick.nvim

Steps

- <a-a> to attach intially then toggle after
- a-d to detach

  Actions

- Open each agent in tmux.
- Add the current file with `<l>af`.

Some Issues

- Adding from the buffer will send relative paths.

Features

- Use snacks with the `a-a` key to send selected files (full path) to chat.

### CodeCompanion

Actions

- multi select files /files
- gd : view debug info - post submit (not truncate, context file)
  Context and setup
- does #lsp work - not shown in debug info ?
- #viewport get all buffers that visible in all tabs ?
- slash commands /now , /file , /clear

2025-12-11 Breaking changes warning : https://github.com/olimorris/codecompanion.nvim/pull/2439

Prompt actions
- cannot be used together 

### Copilot-Chat

- ui trigger happens after pressing tab #command:<tab>
- buffers: select visible (including gitsigns buffer can indicate master-curerent change correctly)
- gc: see context - pre submit (preview: truncate file content)
  Actions
- go to diff / and accept c-y , applying not have correct space ?
  Context and setup
- select model with $models
- #buffers:visible get all buffers that visible in all tabs ?
- #url
- #git : stage / unstaged

### Avante

Actions

- add open file with key <l>ac
- inline edit without asking for quick task
- edit / retry with e / r on user prompt
- accept key , more reliable diff marker acceptance
  Context / setup
- single file, add using shortcut <l>ab
-

Cons

- a bit hard to navigate to the conv chat / edit (only hover cmnd when focus user prompt)
- file apply on root dir
- cursor alwasy move when response streaming

Search providers support : https://github.com/yetone/avante.nvim?tab=readme-ov-file#web-search-engines
- tavily 
- google json: https://developers.google.com/custom-search/v1/introduction/?apix=true
  - create new search engine : https://programmablesearchengine.google.com/controlpanel/create
  - ie. https://cse.google.com/cse?cx=649b8d161c6074aca

## Keymaps

🤩 try to search the keys should already be there

### Hidden settings / keymaps

- i mode: calculator <C-r>=
- q: is disabled by default

- C+/ toggle terminal
  - Esc Esc = normal mode in terminal

### LSP

- install formatters via Mason
- enable on config
- enable format from lazy = <leader>fm
- leader + <L> old lsp infos (not snack)

| Key              | Description                                     |
| ---------------- | ----------------------------------------------- |
| K + K            | see documents params + move to the popup window |
| visual:<C-space> | expand selection                                |
| gd               | See references                                  |
| [d and ]d        | Diagnostics Jump                                |
| [e and ]e        | Errors Jump                                     |
| <leader>ca       | Code action - to help fix                       |
| <leader>cA       | bulk file actions                               |

Troubleshoot some problems

- Python/ruff lsp not working try :e again on the file / enter vim again (might because session)

### Windows

| Key              | Description                                                                       |
| ---------------- | --------------------------------------------------------------------------------- |
| Esc-hl           | Resize screen                                                                     |
| <leader>h/v      | Split                                                                             |
| C-\ + C-n        | Terminal Normal Mode                                                              |
| C+/              | Toggle terminal ( <leader>t+. open split but usaully cause hang , can try :term ) |
| leader + b/w + d | Delete buffer / window                                                            |

### Navigations

Custom
gx - custom function to go to links or directly to github page plugin link
gG - go to google with cursor word / selcted text

- for LSP navigations see below LSP map

#### Help Pages

- C-] go to tags - section (highlighted in red)
- C-t to go back to previous location tag

| Key             | Description                           |
| --------------- | ------------------------------------- |
| zj / k          | Navigate fold (useful in diff split ) |
| FLASH           | -----------                           |
| f/F/s           | search 1-back / 2                     |
| S               | search visual block jump              |
| vmode: , ; (+f) | search Quotes block                   |

#### Neo Tree

| Key            | Description               |
| -------------- | ------------------------- |
| <leader>c.     | Change dir zoxide plugins |
| <localleader>c | Change dir current file   |

Config file settings / debug

| Key         | Description                             |
| ----------- | --------------------------------------- |
| <local>rl   | include lua (check test.lua)            |
| <leader>sna | open noice (messages) log               |
| C-v + <key> | get the key mapping char representation |

### Editing

| Key         | Description                          |
| ----------- | ------------------------------------ |
| C-s         | Save                                 |
| <ll> w      | Save                                 |
| Y, YY       | copy to system clipboard             |
| <ll> q      | Quit                                 |
| za/A        | fold toggle cursor / All             |
| zd          | fold delete                          |
| <leader> fm | Format whole file                    |
| <leader> fF | Toggle Format on Save Buff(!)/Global |

#### Language

<l>ss - symbols
<l>gO - loclist native symbols works on markdown if no lsp installed - render-markdown only provide auto complete capability ?

md - `[[` go to next section

### Files

Find other files

- <leader>fp : select project + file in project
- <leader>fr : find recent open

Neo Tree

<leader-e> 
- h = help

- Custom actions
  - Ff => fzf find in node
  - Fg => fzf grep in node
  - Tf/Tg => telescope
  - TC,Tc => telescope cd / cd


### Issues

Keymap code terminal, tmux, vim

Tmux non compatible
- c_- and c-/ : is same code inside tmux

Terminal compatible (not tmux)
- c-s-s : ghostty only
- c-tab / c-s-tab : work in ghostty keymap only

To check more 
- [ ] https://apple.stackexchange.com/questions/24261/how-do-i-send-c-that-is-control-slash-to-the-terminal


## Others

#### Coding

Overseer - task manangement (leader + o)

- support and read ./.vscode/tasks.json by default
- can extend by https://github.com/stevearc/overseer.nvim/blob/master/doc/guides.md#custom-tasks
- rerun last task with <leader>>or
- vscode spec: https://github.com/stevearc/overseer.nvim/blob/master/doc/guides.md#vs-code-tasks

Hurl - HTTP client runner (leader + h)

https://github.com/jellydn/hurl.nvim?tab=readme-ov-file#swappable-environment
Set env file by

- uses `vars.env` relative or recursively to root project, can change using :HurlSetEnvFile (support mult use ,)

#### Refactoring

1. FZF/Snacks/Telescope select with tab + C+Q > send to quicklist
2. :copen to see the list
3. :cfdo %s/old/new/g | update (use c flag substitude to make sure its correct)

`Markdown` - manual enable on md files table mode auto format when type the  
Tables plugin (manual enabled)

'Notes' : Key works per buffer
| Key | Description |
| ----------- | -------------- |
| <leader> tm | Enable |
| <leader> tc | Delete column |

### Replacing

Use nvim spectre

- sometimes in config file not see need to toggle hidden (I)
- <leader>+sF search + replace current word

- no undo
  Guide: basic cdo + spectre : https://www.youtube.com/watch?v=YzVmdJ41Xkg&ab_channel=AndrewCourter

### Searching

#### Snacks Preview

https://github.com/folke/snacks.nvim/discussions/1306
Configured:

- truncate files 200
  | Key | Description |
  | ----------- | ----------- |
  | <leader> s + b | search inside current buffer + jump |
  | pickers keyboard | |
  | ? | help |
  |a+w| switch window can edit in preview |
  | a+p| preview |
  |a+f| follow |

### Git

#### Snacks

- key vim friendly switch between insert / normal
- git-browse + git plugin

Action bind

- Branch
  - c-s diff compare, c-o open

  | Key   | Description                                         |
  | ----- | --------------------------------------------------- |
  | <l>gL | line history all + go on commit hash = open browser |
  | <l>gf | file history in lzg                                 |
  | <l>gb | branch                                              |
  | <l>go | open current cursor hash / file in browser          |

  Added Features/Pickers
  - grep in quicklist (default only support file search)
  - binding smart to trigger files / buffers switches

CAVEAT actions
- function(picker,items) only works in action
ie. `picker:refresh()` and items will be nil if put as inline function inside win.input.keys

#### Gitsign

- good features

  | Key   | Description          |
  | ----- | -------------------- |
  | <l>g  | toggle gitsigns      |
  | S     | stage buffer         |
  | <l>gh | prefixes             |
  | s     | toggle un/stage hunk |

#### FZF

Good

- full screen / fkey usable
- good for customizing with actions

Features

- git branches = branches
- git_bcommits = see all commits for current file

Action bind

- git branch, bcommits
  - c-s diff compare, c-o open, f6 toggle delta diff mode (work but will quit the pickers)

| Key  | Description                       |
| ---- | --------------------------------- |
| <l>G | prefix                            |
| B    | File history                      |
| S    | Blame all line (enter=go to line) |

--- old ---
Telescope
| Key | Description |
| -------------- | ----------- |
| C-A-j/k | Next Hunk |
| ]c, [c | Next Hunk |
| <leader>gbc | See files |
| - enter | apply commit change to file |
| - split | compare |

Fugitive

Status View

| Key        | Description          |
| ---------- | -------------------- |
| <leader>gz | see git status       |
| = / > \ <  | expand toggle diff   |
| J/K        | next hunk            |
| I          | patch mode           |
| X          | discard under cursor |
| G          | Git Status           |

Commit / Files View - TODO OLD fugitive

| Key                  | Description                |
| -------------------- | -------------------------- |
| :Gclog               | See clean commit message   |
| :Gclog -- %          | see commit of currnt file  |
| g?                   | help                       |
| gq                   | quit blame / menu          |
| <leader> gb          | Git Blame                  |
| - l                  | Blame Line                 |
| - c                  | Blame commit Telescope     |
| - L                  | see commit with blame info |
| C                    | go to commit of the file   |
| <enter> / o / go / O | open file / split          |

---

| auto tag add support |
| md : table on save format | not pretty line auto like TD mode |

Coding
| Key | Description |
| ----- | ------|
| Comment | gc<kjh> gcc |
| Format | <leader>-cf |

### AI

#### ChatGPT

plugin: https://www.youtube.com/watch?v=jrFjtwm-R94&ab_channel=NerdSignals

- Act as (persona)
- Docs
- Chat Grammar correct Bug fixes, Explain

#### CodeCompanion

Pros:

- Support Tools calling and run docker (but might not setup deps correctly)
- Diff pane (only show when use with quick chat) acceptable / rejectable
  - but a bit weird to edit code sometimes not correct

Cons:

- when Toggle with visual does not Add context of selected to the chat like copilot chat

| Key          | Description                       |
| ------------ | --------------------------------- |
| <leader>A    | toggle commands                   |
| + A          | add selected code to chat         |
| + q          | Chat with input (select/deselect) |
| gy           | copy code section using gy        |
| ga           | accept diff code                  |
| gr           | reject diff code                  |
| chat /       | slash commands                    |
| chat @       | tools                             |
| -- MODIFY -- |                                   |
| + Q          | Chat with input (select/deselect) |

#### Copilot

https://github.com/CopilotC-Nvim/CopilotChat.nvim

Copilot Chat

| Key             | Description                                          |
| --------------- | ---------------------------------------------------- |
| <leader>a       | toggle commands                                      |
| - m/M           | get commit message from current diff / staged        |
| <Tab> (default) | auto suggest / open popup can use after #file: <Tab> |
| <input> / or @  | /prompts or @context                                 |
| <enter>         | continue question enter chat                         |

Code companion

| Key        | Description     |
| ---------- | --------------- |
| <leader> A | toggle commands |


## Adapater AI notes

Codecompanion 
- support value as ENV name inject when not empty
- support header env 

more answer: https://deepwiki.com/search/how-to-bind-key-to-do-inline-c_1b187fa6-d9be-448a-be94-c77c3e2de23f?mode=fast
default 
api_key = "OPENAI_API_KEY"


## Lua notes

'<'> marks will only be available when user select text in visual mode and exit visual mode
so binding with execution on v mode with

```lua
vim.cmd("'<'>Command") might get error like not found mark '<>
```
