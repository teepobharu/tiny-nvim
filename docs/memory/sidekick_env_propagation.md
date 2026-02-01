# Sidekick.nvim Environment Variable Propagation

## Problem Statement

20260130 - Updated 20260131

- claude and codex open by sidekick seems not to use the env correctly even !shell command show the correct env is set

Sidekick CLI agents (like `claude`, `opencode`, etc.) sometimes fail to receive required environment variables (API keys, PATH modifications) even though they're set in the shell.

## Key GitHub Issues

- **[#62](https://github.com/folke/sidekick.nvim/issues/62)**: `Config.cli.tools.TOOL.env` not passed when tmux enabled (FIXED)
- **[#164](https://github.com/folke/sidekick.nvim/issues/164)**: `OPENCODE_CONFIG_DIR` not respected (WONTFIX - use explicit env)

## Quick Diagnosis Flowchart

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENV VAR NOT WORKING?                         │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Step 1: Is env in Neovim?                                      │
│  :lua print(vim.env.ANTHROPIC_API_KEY)                          │
└───────────────┬─────────────────────────────────────────────────┘
                │
       ┌────────┴────────┐
       │                 │
       ▼                 ▼
    [nil]             [SET]
       │                 │
       │                 ▼
       │   ┌─────────────────────────────────────────────────────┐
       │   │  Step 2: Which backend?                             │
       │   │  :lua print(require("sidekick.config").cli.mux)     │
       │   └───────────────┬─────────────────────────────────────┘
       │                   │
       │          ┌────────┴────────┐
       │          │                 │
       │          ▼                 ▼
       │     [mux=true]        [mux=false]
       │     (tmux/zellij)     (terminal)
       │          │                 │
       │          ▼                 ▼
       │   ┌──────────────┐  ┌─────────────────────────────────┐
       │   │ Check tmux   │  │ Should work - check tool.env    │
       │   │ server env   │  │ set in config                   │
       │   │ `tmux show-  │  └─────────────────────────────────┘
       │   │ environment` │
       │   └──────┬───────┘
       │          │
       │   ┌──────┴──────┐
       │   │             │
       │   ▼             ▼
       │  [missing]     [present]
       │   │             │
       │   ▼             ▼
       │  SOLUTION:     Check tool.env
       │  kill-server   explicitly set
       │  & restart     in sidekick opts
       │
       ▼
┌─────────────────────────────────────────────────────────────────┐
│  SOLUTION: Neovim started without env                           │
│  - GUI app? Launch from terminal                                │
│  - direnv not loaded? Run `direnv allow`                        │
│  - Explicit config: tools.<name>.env = { KEY = vim.env.KEY }    │
└─────────────────────────────────────────────────────────────────┘
```

## Root Cause Analysis

### 1. Environment Merge Chain

**Terminal Backend** (lua/sidekick/cli/terminal.lua:272):

```lua
local env = vim.tbl_extend("force", {},
  vim.uv.os_environ(),           -- ① Neovim's process environment
  self.tool.config.env or {},    -- ② Tool default env from config
  self.tool.env or {},           -- ③ Tool instance env (runtime)
  {                              -- ④ Hardcoded overrides
    NVIM = vim.v.servername,
    NVIM_LISTEN_ADDRESS = false,
    -- ...
  })
-- jobstart(..., clear_env = true, env = env)
```

**Tmux Backend** (lua/sidekick/cli/session/tmux.lua:75-82):

```lua
function M:add_cmd(ret)
  for key, value in pairs(self.tool.env or {}) do
    if value == false then
      vim.list_extend(ret, { "-u", key })  -- unset
    else
      vim.list_extend(ret, { "-e", ("%s=%s"):format(key, tostring(value)) })
    end
  end
  vim.list_extend(ret, self.tool.cmd)
end
-- tmux new -A -s <session> -e KEY=VAL ... <cmd>
-- sample
```

**SAMPLE COMMAND used**

```lua
function test()
 norm_cmd = { "tmux", "new", "-A", "-s", "claude_ME_$(date +u)", "-c", "/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim", "claude", ";", "set-option", "status", "off", ";", "set-option", "detach-on-destroy", "on" }

env = vim.tbl_extend("force", {}, vim.uv.os_environ(), { FOO = "bar" } or {},  {}, {
      NVIM = vim.v.servername,
      NVIM_LISTEN_ADDRESS = false,
      NVIM_LOG_FILE = false,
      VIM = false,
      VIMRUNTIME = false,
      TERM = "xterm-256color",
      DEBUG_BASHP = "1",
    })
-- __AUTO_GENERATED_PRINT_VAR_START__
-- print([==[ env:]==], vim.inspect(env)) -- __AUTO_GENERATED_PRINT_VAR_END__
 -- 'tmux', 'new', '-A', '-s', 'codex_ME_debug',

norm_cmd = { "env" } norm_cmd = { "echo", "$$ANTHROPIC_API_KEY"}
  -- '-c',
norm_cmd = {
  'tmux', 'new', '-A', '-s', 'tmdb',
    '-c',
    '/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim',
    'codex',
    -- 'pwd',
    -- 'codex --enable web_search_request',
    -- 'codex', '--add-dir', '~/dotfiles/docs/',
   ';', 'set-option', 'status', 'off', ';', 'set-option', 'detach-on-destroy', 'on',
    -- ';', 'read'
    -- ';', 'set-option', '-p', 'remain-on-exit', 'on'
}

  -- [WORK] quit all alacritty + ghostty + restart pc ??
  -- [Partial work] Disable override
  -- tmux default-shell-cmd make it work (but not with cmd codex with extra args)
  -- with the flag below make
  -- issue: 'codex', "--enable", "web_search_request",
  -- works: 'codex --enable web_search_request',
  -- "codex --add-dir', '~/dotfiles/docs/",
  -- reproducible in both tmux command in snacks term (see EXA1 below)

  -- 'echo', '$ANTHROPIC_API_KEY',
  --   'echo', '$ANTHROPIC_API_KEY',

  -- 'codex',
  -- 'echo $ANTHROPIC_API_KEY',

  -- observations----
  -- c flags with cmd got env flag correctly
  -- but if run command
  -- clear_env has not affect

  -- add new tab
vim.cmd("tabnew")
job = vim.fn.jobstart(norm_cmd, {
   cwd = vim.fn.getcwd(),
   term = true,
   -- clear_env = false,
   clear_env = true,
   env = not vim.tbl_isempty(env) and env or nil,
 })

 print(vim.inspect(job))
end

--EXA1:

-- print env correctly but when do codex / other seems like partially see debug
tmux new -e DEBUG_BASHP=1 -A -s "codex_ME_debugdb" -c "$HOME/dotfiles/ai" "env && echo $GITLAB_TOKEN && read" ";" set-option status off
 tmux new -A -s "codex_ME_debugdb" -c "$HOME/dotfiles/ai" claude ";" set-option status off
# if see gitlab missing GITLAB_TOKEN env = not working
 tmux new -A -s "codex_ME_debugdb" -c "$HOME/dotfiles/ai" codex ";" set-option status off
 tmux new -A -s "codex_ME_debugdb" -c "$HOME/dotfiles/ai" codex --enable web_search_request ";"

 tmux new -A -s "codex_ME_debug" -c "/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim" \
"codex --add-dir $HOME/ask/" \
codex --add-dir $HOME/ask/ \
";" set-option status off ";" set-option detach-on-destroy on

  -- delete session
tmux kill-session -t codex_ME_debug



```

**Key observations**:

- Terminal backend uses `clear_env = true` + explicit env table → CLI **only** sees what's in that table
- Env source is `vim.uv.os_environ()` → what Neovim's process has at startup

```lua
print(vim.inspect(vim.uv.os_environ())) # exists anthropic key
```

- Tmux backend only passes `tool.env` (not config.env, not Neovim's full env)

### 2. Historical Bug & Fix

- **Commit 0d99706** (Sep 30, 2025): Changed `vim.uv.os_environ()` to `vim.fn.environ()`
  - Reason: vim.uv captures env at Neovim process start; vim.fn.environ() is more dynamic
  - However, **current code (line 272) still uses `vim.uv.os_environ()`** → possible regression or intentional revert
- **Commit e869205** (Oct 5, 2025): Fixed tmux to pass `tool.env` to `tmux new -e`
  - Before: tmux backend didn't pass any env vars
  - After: passes tool.env only (still misses config.env and Neovim env)

### 3. Why Env Vars Go Missing

#### Scenario A: GUI Neovim (Neovim.app, VSCode, desktop launcher)

- **Problem**: macOS GUI apps don't inherit shell rc files (~/.zshrc, ~/.bashrc)
- **Impact**:
  - API keys set in ~/.zshrc are not in process env
  - PATH modifications (nvm, mise, asdf) are missing
  - `vim.uv.os_environ()` returns system default PATH + minimal env
- **Example**:

  ```zsh
  # ~/.zshrc
  export ANTHROPIC_API_KEY="sk-ant-..."
  export PATH="$HOME/.local/bin:$PATH"
  ```

  - Shell Neovim: sees these ✅
  - GUI Neovim.app: doesn't see these ❌

#### Scenario B: Tmux/Zellij multiplexer backend

- **Problem**: Multiplexer server inherits env when **it** was started
- **Impact**:
  - If tmux server started before env vars were set → CLI won't get them
  - `tmux set-environment` updates are not retroactive to existing sessions
  - Restarting multiplexer server required to pick up new env
- **Example**:
  ```bash
  # Terminal 1 (morning): start tmux
  tmux new -s dev
  # Terminal 2 (afternoon): add env var to ~/.zshrc
  echo 'export NEW_API_KEY="..."' >> ~/.zshrc
  # Terminal 3 (evening): attach to tmux
  tmux attach -t dev
  # Sidekick CLI in this session: doesn't see NEW_API_KEY ❌
  ```

#### Scenario C: Terminal backend with clear_env

- **Problem**: `jobstart(..., clear_env = true)` starts with empty env, only adds what's in `env` table
- **Impact**: Shell-level env vars not in Neovim's process are lost
- **Note**: This is intentional for clean process isolation, but requires explicit env passing

## Debugging Steps

### 1. Check Neovim's environment

```vim
" From Neovim command line
:lua print(vim.inspect(vim.uv.os_environ()))
:lua print(vim.env.ANTHROPIC_API_KEY)
:lua print(vim.env.CLAUDE_API_KEY)
```

### 2. Check Sidekick tool config

```vim
:lua print(vim.inspect(require("sidekick.config").cli.tools.claude))
:lua print(vim.inspect(require("sidekick.config").cli.tools.opencode))
```

### 3. Check CLI agent's actual environment

- Start a Sidekick session for the tool
- Use `:Sidekick cli send msg="echo $ANTHROPIC_API_KEY"` (for terminal backend)
- Or manually run `env | rg KEY_NAME` in the session
- Compare with what Neovim sees

### 4. Check multiplexer backend

```vim
:lua print(vim.inspect(require("sidekick.config").cli.mux))
```

If `mux.enabled = true`:

```bash
# Check tmux server env
tmux show-environment
# Check zellij env
zellij list-sessions
```

## Solutions & Workarounds

### Solution 1: Ensure Neovim inherits shell environment

**For terminal Neovim** (already works):

```bash
# Start Neovim from shell where env is loaded
nvim
```

**For GUI Neovim on macOS**:

- **Option A**: Launch from terminal (`open -a Neovim`)
- **Option B**: Create wrapper script:

  ```bash
  #!/bin/bash
  # ~/.local/bin/neovim-gui
  source ~/.zshrc  # or ~/.bashrc
  exec /Applications/Neovim.app/Contents/MacOS/nvim "$@"
  ```

  Then set this as default editor in system preferences

- **Option C**: launchd plist to set env vars system-wide
  ```xml
  <!-- ~/Library/LaunchAgents/setenv.ANTHROPIC_API_KEY.plist -->
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>setenv.ANTHROPIC_API_KEY</string>
      <key>ProgramArguments</key>
      <array>
        <string>sh</string>
        <string>-c</string>
        <string>launchctl setenv ANTHROPIC_API_KEY "sk-ant-..."</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
    </dict>
  </plist>
  ```
  Load with: `launchctl load ~/Library/LaunchAgents/setenv.ANTHROPIC_API_KEY.plist`

### Solution 2: Explicit env in Sidekick config (RECOMMENDED)

**Best practice**: Always set required env vars in Sidekick config

```lua
-- lua/plugins/extra/mySidekick.lua or init.lua
require("sidekick").setup({
  cli = {
    tools = {
      claude = {
        cmd = { "claude" },
        env = {
          ANTHROPIC_API_KEY = vim.env.ANTHROPIC_API_KEY,
          -- Or hardcode (less secure, but works):
          -- ANTHROPIC_API_KEY = "sk-ant-...",
        },
      },
      opencode = {
        cmd = { "opencode" },
        env = {
          OPENCODE_THEME = "system",
          OPENCODE_API_KEY = vim.env.OPENCODE_API_KEY,
        },
      },
      -- For tools that need PATH modifications
      custom_tool = {
        cmd = { "my-cli" },
        env = {
          PATH = vim.env.PATH, -- inherit Neovim's PATH
          -- Or prepend custom paths:
          -- PATH = vim.env.HOME .. "/.local/bin:" .. vim.env.PATH,
        },
      },
    },
  },
})
```

**Why this works**:

- Explicitly adds env to both terminal backend (`self.tool.config.env`) and tool instance (`self.tool.env`)
- Terminal backend merges this into jobstart env table
- Tmux backend should also pick this up (though current code only uses `tool.env`, not `tool.config.env` → potential improvement)

### Solution 3: Multiplexer server restart

**For tmux**:

```bash
# Kill all tmux sessions and server
tmux kill-server
# Or restart server while preserving sessions (if supported)
tmux detach-client -a
```

**For zellij**:

```bash
zellij kill-all-sessions
```

Then restart Neovim and create new Sidekick sessions.

### Solution 4: Use wrapper script for CLI tools

Create a wrapper that sources env before exec:

```bash
#!/bin/bash
# ~/.local/bin/claude-wrapper
# Load environment
[ -f ~/.zshrc ] && source ~/.zshrc
# Exec the actual tool
exec claude "$@"
```

Then in Sidekick config:

```lua
require("sidekick").setup({
  cli = {
    tools = {
      claude = {
        cmd = { vim.env.HOME .. "/.local/bin/claude-wrapper" },
      },
    },
  },
})
```

### Solution 5: direnv for per-project env

**For project-specific API keys**:

1. Install direnv: `brew install direnv`
2. Hook into shell (~/.zshrc):
   ```zsh
   eval "$(direnv hook zsh)"
   ```
3. Create `.envrc` in project root:
   ```bash
   export ANTHROPIC_API_KEY="sk-ant-project-specific-key"
   export OPENCODE_API_KEY="..."
   ```
4. Allow: `direnv allow .`
5. Start Neovim from project directory (direnv loads env before Neovim starts)

**Note**: Neovim must be started **after** direnv loads the env, or use direnv.nvim plugin to reload env inside Neovim.

## Known Issues & Caveats

### Issue 1: Tmux backend doesn't merge config.env

**Current behavior** (lua/sidekick/cli/session/tmux.lua:75):

```lua
for key, value in pairs(self.tool.env or {}) do
  -- Only uses tool.env, not tool.config.env
```

**Impact**: Env set in `tools.claude.env` in setup() may not propagate to tmux sessions

**Workaround**: Set env at runtime via `tool:clone({ env = {...} })` or restart with terminal backend

### Issue 2: vim.uv.os_environ() vs vim.fn.environ()

**Current code** uses `vim.uv.os_environ()` (lua/sidekick/cli/terminal.lua:272)

**Difference**:

- `vim.uv.os_environ()`: Snapshot of env at Neovim process start (libuv)
- `vim.fn.environ()`: Current environment (Vimscript, more dynamic?)

**History**: Commit 0d99706 changed to `vim.fn.environ()`, but later reverted (unclear why)

**Recommendation**: If you need dynamic env changes during Neovim session, consider using `vim.fn.environ()` instead

### Issue 3: Env changes after CLI session starts

**Problem**: Once a CLI agent process is running, its env is frozen

**Impact**:

- Changing env vars in Neovim (`:lua vim.env.KEY = "new_value"`) won't affect running CLI sessions
- Need to close and restart the Sidekick session to pick up changes

**Workaround**: Always set env before starting the session, or implement session restart keybinding

## Recommendations for Plugin Improvement

### 1. Merge tool.config.env in tmux backend

**File**: lua/sidekick/cli/session/tmux.lua:75

**Current**:

```lua
for key, value in pairs(self.tool.env or {}) do
```

**Suggested**:

```lua
local env_vars = vim.tbl_extend("force", {}, self.tool.config.env or {}, self.tool.env or {})
for key, value in pairs(env_vars) do
```

### 2. Document env precedence clearly

**Priority chain**:

1. Tool instance env (`tool.env` set at runtime)
2. Tool config env (`tools.claude.env` in setup())
3. Neovim process env (`vim.uv.os_environ()`)
4. Hardcoded overrides (NVIM, TERM, etc.)

### 3. Add :SidekickCliEnv command for debugging

```lua
vim.api.nvim_create_user_command("SidekickCliEnv", function()
  local state = require("sidekick.cli.state").get()
  if not state then
    print("No active Sidekick CLI session")
    return
  end

  print("Tool:", state.tool.name)
  print("Backend:", state.session.backend)
  print("\nNeovim env (sample):")
  print(vim.inspect({
    ANTHROPIC_API_KEY = vim.env.ANTHROPIC_API_KEY,
    PATH = vim.env.PATH and vim.env.PATH:sub(1, 100),
  }))
  print("\nTool config.env:")
  print(vim.inspect(state.tool.config.env))
  print("\nTool runtime env:")
  print(vim.inspect(state.tool.env))
end, {})
```

## Quick Reference

| Symptom                                     | Likely Cause                       | Quick Fix                                 |
| ------------------------------------------- | ---------------------------------- | ----------------------------------------- |
| GUI Neovim: CLI auth fails                  | Shell rc not loaded                | Launch from terminal or set env in config |
| Tmux: env works in one session, not another | Tmux server started before env set | `tmux kill-server`, then restart          |
| Terminal backend: CLI missing PATH          | clear_env strips env               | Add `PATH = vim.env.PATH` to tool.env     |
| Works in shell, not in Neovim               | Neovim process env missing var     | Add to tool.config.env in setup()         |
| Env set after Neovim started                | Process env is immutable           | Restart Neovim or use explicit config     |

## Testing Checklist

- [ ] Print `vim.uv.os_environ()` and verify required keys exist
- [ ] Check `require("sidekick.config").cli.tools.<tool>.env` is set
- [ ] If using mux backend, verify multiplexer server has the env vars
- [ ] Test sending `echo $VAR` to CLI session to see what agent sees
- [ ] Compare shell env vs GUI Neovim env vs CLI agent env
- [ ] Verify env propagation after tmux/zellij server restart

## Debugging Commands Checklist

Run these commands in sequence to pinpoint the issue:

### Step 1: Verify Neovim sees env vars

```vim
" Check if Neovim process has the API keys
:lua print("ANTHROPIC_API_KEY:", vim.env.ANTHROPIC_API_KEY and "SET" or "NOT SET")
:lua print("OPENAI_API_KEY:", vim.env.OPENAI_API_KEY and "SET" or "NOT SET")
:lua print("PATH:", vim.env.PATH:sub(1,100))

" Full environment dump (search for keys)
:lua for k,v in pairs(vim.uv.os_environ()) do if k:match("API") or k:match("KEY") then print(k) end end
```

### Step 2: Check Sidekick config for your tool

```vim
" Replace 'claude' with your tool name
:lua print(vim.inspect(require("sidekick.config").cli.tools.claude))
:lua print(vim.inspect(require("sidekick.config").cli.tools.opencode))

" Check mux settings
:lua print(vim.inspect(require("sidekick.config").cli.mux))
```

### Step 3: Check tmux server environment

```bash
# If mux.enabled = true with tmux backend
tmux show-environment
tmux show-environment -g

# Check when tmux server started vs when env was set
tmux display -p '#{start_time}'
```

### Step 4: Test env propagation inside CLI session

Start a sidekick session, then send:

```bash
# Inside the CLI agent session
echo $ANTHROPIC_API_KEY
echo $OPENAI_API_KEY
env | grep -E "(API|KEY|PATH)"
```

Or from Neovim:

```vim
:lua require("sidekick.cli").send({ msg = "echo $ANTHROPIC_API_KEY", submit = true })
```

### Step 5: Compare environments

```bash
# Terminal shell env (baseline)
env | grep -E "(ANTHROPIC|OPENAI|CLAUDE)" > /tmp/shell_env.txt

# Inside tmux (if using mux backend)
tmux new-session -d "env | grep -E '(ANTHROPIC|OPENAI|CLAUDE)' > /tmp/tmux_env.txt"

# Compare
diff /tmp/shell_env.txt /tmp/tmux_env.txt
```

### Step 6: Verify tool.env is being passed (for tmux)

Check if `-e` flags are in the tmux command:

```vim
" Enable debugging to see actual command
:lua vim.g.sidekick_debug = true
" Then start a session and check :messages
```

### Replication Commands

```bash
# Clean test: Kill tmux server, source env, restart
tmux kill-server
source ~/.zshrc  # or ~/.bashrc
nvim

# Inside nvim, open sidekick
:lua require("sidekick.cli").toggle({ name = "claude" })
```

## Tmux Config Considerations

Your `.tmux.conf` has these relevant settings:

```bash
# Default shell - affects env inheritance
if-shell "echo $SHELL | grep -q 'fish'" 'set -g default-shell /bin/bash' 'set -g default-shell $SHELL'

# update-environment is NOT set - tmux won't auto-update env vars
# Consider adding:
# set -g update-environment "ANTHROPIC_API_KEY OPENAI_API_KEY CLAUDE_API_KEY"
```

**Recommendation**: Add to `.tmux.conf`:

```bash
# Auto-update these env vars when attaching
set -g update-environment "ANTHROPIC_API_KEY OPENAI_API_KEY CLAUDE_API_KEY OPENCODE_API_KEY SSH_AUTH_SOCK"
```

## References

- Sidekick source: ~/.local/share/nvim3_jelly_tinynvim/lazy/sidekick.nvim/
- Env merge logic: lua/sidekick/cli/terminal.lua:272
- Tmux env passing: lua/sidekick/cli/session/tmux.lua:75-82
- Related commits:
  - 0d99706: "fix(terminal): use vim environ instead of uv" (Sep 30, 2025)
  - e869205: "fix(tmux): set tool env vars. Closes #62" (Oct 5, 2025)
- Community discussions:
  - [GitHub issue #62](https://github.com/folke/sidekick.nvim/issues/62) (tmux env vars) - CLOSED/FIXED
  - [GitHub issue #164](https://github.com/folke/sidekick.nvim/issues/164) (OPENCODE_CONFIG_DIR) - WONTFIX
