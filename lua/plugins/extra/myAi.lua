-- Only contains modifications to default configs
-- put all related ai agents additional plugins options and configs here

local editor_keymaps = require "utils.editor_keymaps"
local AI_CONST = require "utils.my_ai_constants"
local avante_utils = require "utils.my_avante_utils"
local AI_CFG = require "utils.my_ai_default_config"

local DEFAULT_PROVIDER = AI_CFG.DEFAULT_PROVIDER
local ENABLE_COPILOT = AI_CFG.ENABLE_COPILOT

local git_util = require "utils.git"

local is_git_worktree_profile = git_util.is_worktree_dir(vim.fn.stdpath "config")

local function resolve_mcphub_backend()
  local function first_existing_cli(candidates)
    for _, candidate in ipairs(candidates) do
      if vim.fn.filereadable(candidate) == 1 then
        return candidate
      end
    end
    return ""
  end

  local function cli_from_repo(repo_path)
    local repo = vim.trim(repo_path or "")
    if repo == "" then
      return ""
    end

    return first_existing_cli {
      repo .. "/dist/cli.js",
      repo .. "/src/utils/cli.js",
    }
  end

  local server_url = vim.trim(vim.env.MCP_HUB_SERVER_URL or "")
  if server_url ~= "" then
    return {
      use_bundled_binary = false,
      server_url = server_url,
      cmd = nil,
      cmdArgs = nil,
    }
  end

  local cli_path = ""
  local fork_cli_env = vim.trim(vim.env.MCP_HUB_FORK_CLI or "")
  if fork_cli_env ~= "" then
    if vim.fn.filereadable(fork_cli_env) == 1 then
      cli_path = fork_cli_env
    else
      vim.notify(("mcphub: MCP_HUB_FORK_CLI not readable, ignoring: %s"):format(fork_cli_env), vim.log.levels.WARN)
    end
  end
  if cli_path == "" then
    cli_path = cli_from_repo(vim.env.MCP_HUB_FORK_REPO)
  end

  -- Zero-config defaults for local fork development.
  if cli_path == "" then
    local default_repos = {
      vim.fn.expand "~/projects/mcp-hub",
      vim.fn.expand "~/worktree/mcp-hub",
    }
    for _, repo in ipairs(default_repos) do
      cli_path = cli_from_repo(repo)
      if cli_path ~= "" then
        break
      end
    end
  end

  if cli_path ~= "" then
    return {
      use_bundled_binary = false,
      server_url = nil,
      cmd = "node",
      cmdArgs = { cli_path },
    }
  end

  return {
    use_bundled_binary = true,
    server_url = nil,
    cmd = nil,
    cmdArgs = nil,
  }
end

local mcphub_backend = resolve_mcphub_backend()

local CLAUDE_CODER_MAPPING_PREFIX = "<leader>C"
-- caveat : might not updated when something changed until restart nvim ?
local common_agent_env = {
  OPENAI_API_KEY = vim.env.GENAIAG,
  OPENAI_BASE_URL = vim.env.AG_OPENAIPROXY,
  ANTHROPIC_AUTH_TOKEN = vim.env.ANTHROPIC_AUTH_TOKEN,
  GLEAN_API_TOKEN = vim.env.GLEAN_API_TOKEN,
  GITLAB_TOKEN = vim.env.GITLAB_TOKEN,
  GEMINI_API_KEY = vim.env.GEMINI_API_KEY,
  CLAUDE_CODE_USE_BEDROCK = vim.env.CLAUDE_CODE_USE_BEDROCK or "0",
  CLAUDE_CODE_NO_FLICKER = "1", -- render only viz part save mem ? add fn search / and c-u/d , but sidekick terminal normal mode can scroll up easily not like term for vim / claude
}

return {
  {
    -- https://deepwiki.com/search/explain-if-luarcjson-file-can_a16e3ee5-0d51-46cf-9c7d-6b6a96e5ad8c?mode=fast
    "folke/sidekick.nvim",
    -- https://deepwiki.com/search/what-does-dev-and-dir-field-is_dcd4b58d-b892-4dd9-b13c-88c7a1a0d367?mode=fast
    -- The dev path is configured by config.dev.path (default "~/projects"). The resolved directory becomes {config.dev.path}/{plugin.name} config.lua:69-76 .

    -- DEBUG way 1
    -- directly edit source code
    -- w/o exiting use :Lazy reload
    --
    -- if no change reflect / cache try below
    -- dir = "/Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/sidekick.nvim/",
    -- dir = "sidekick.nvim/",
    -- dev = true,
    opts = {
      cli = {
        -- Moved from myEditor.lua — custom prompt context variables
        prompts = {
          fname = function()
            return vim.fn.expand "%:t"
          end,
          fpath = function()
            -- in this format file: <> \n name <> in newline separate
            -- try sending just the file name not the content
            return vim.fn.expand "%:p"
          end,
        },
        win = {
          keys = {
            buffers       = { "<c-b>", "buffers"   , mode = "n", desc = "open buffer picker" },
            files         = { "<c-f>", "files"     , mode = "n", desc = "open file picker" },
            hide_ctrl_z   = { "<c-z>", "blur"      , mode = "nt", desc = "go back to the previous window without hiding the terminal" },
            prompt        = { "<c-p>", "prompt"    , mode = "n" , desc = "insert prompt or context" },
            -- Disable conflicting Ctrl keybindings
            -- files = false, -- disables <c-f>
            -- prompt = "<m-i>", -- disables <c-p>
            -- buffers = false, -- disables <c-b>
            -- Disable all tmux navigation keys in sidekick terminal
            nav_left = false, -- disables <c-h>
            nav_down = false, -- disables <c-j>
            nav_up = false, -- disables <c-k>
            nav_right = false, -- disables <c-l>
          },
        },
        -- work around for issues docs/memory/sidekick_env_propagation.md
        tools = {
          opencode = {
            -- Use <M-p> for the command palette instead of the default <C-p>
            keys = { prompt = { "<m-p>", "prompt" } },
            env = common_agent_env,
            -- env = {
            --   GLEAN_API_TOKEN = vim.env.GLEAN_API_TOKEN,
            -- },
          },
          -- crush = {
          --   env = {
          --     GLEAN_API_TOKEN = vim.env.GLEAN_API_TOKEN,
          --   },
          -- },
          codex = {
            cmd = { "codex", "--dangerously-bypass-approvals-and-sandbox" },
            env = common_agent_env,
          },
          claude = {
            cmd = { "claude", "--allow-dangerously-skip-permissions" },
            env = common_agent_env,
          },
          claude_bare = {
            cmd = { "claude", "--bare", "--allow-dangerously-skip-permissions" },
            env = common_agent_env,
          },
          claudeF = {
            cmd = { "claude", "--allow-dangerously-skip-permissions" },
            env = vim.tbl_extend("force", common_agent_env, { CLAUDE_CODE_NO_FLICKER = "0" }),
          },
          claude_Agd = {
            cmd = { vim.env.DOTFILES_DIR .. "/ai/claude/cc-agd/cag.sh" },
            env = common_agent_env,
          },
          claude_AgdOm = {
            cmd = { vim.env.DOTFILES_DIR .. "/ai/claude/cc-agd/cag.sh", "--om" },
            env = common_agent_env,
          },
          claude_AgdOmD = {
            cmd = { vim.env.DOTFILES_DIR .. "/ai/claude/cc-agd/cag.sh", "--omd" },
            env = common_agent_env,
          },
          pi = {
            -- Try pi with extensions; on failure (e.g. mcphub bridge crash outside
            -- its worktree) fall back to --no-extensions. Wrapped in bash -c because
            -- sidekick runs cmd directly (no shell), so "||" would be a literal arg.
            cmd = { "bash", "-c", "pi 2>/dev/null || exec pi --no-extensions" },
            env = vim.tbl_extend("force", common_agent_env, {
              PI_TELEMETRY = "0",
              PI_CACHE_RETENTION = "long",
            }),
          },
          pi_noext = {
            -- Try pi with extensions; on failure (e.g. mcphub bridge crash outside
            -- its worktree) fall back to --no-extensions. Wrapped in bash -c because
            -- sidekick runs cmd directly (no shell), so "||" would be a literal arg.
            cmd = {  "pi",  "--no-extensions" },
            env = vim.tbl_extend("force", common_agent_env, {
              PI_TELEMETRY = "0",
              PI_CACHE_RETENTION = "long",
            }),
          },
          debug_me = { -- https://github.com/folke/sidekick.nvim/issues/62
            env = vim.tbl_extend("force", common_agent_env, {
              FOO = "bar",
            }),
            -- require to use absolute (no ~) else failed - try chmod +x also
            cmd = { "/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/tests/debug_me.sh" },
            -- cmd = { "bash", "-c", "~/dotfiles/.config/nvim3_jelly_tinynvim/tests/debug_me.sh", "&&", "read" },
            -- below also work ?
            -- below envs work fine ?
            -- cmd = { "bash", "-l" }, -- show all env correctly
            -- cmd = { "bash", "-lc", "claude" }, -- show env properly used
            -- env = {
            --   FOO = "111",
            -- },
            dummyFn = function()
              -- Test :LazyDev importability and completionQ
              -- Behavior
              -- - config optional = true on coding not enough lua/plugins/coding.lua, ft lua lazydev lua/langs/lua.lua needed else blink error
              -- - initial = all buffers scan require modules / text to import into workspace
              -- .luarc.json - should not have setting of workspace.library (else functionality will not work ie. Snacks global sidekick.cli.terminal full path not navable)
              -- seems like load all deps
              -- if not enable will not auto load these plujgins into lsp workspace var
              -- use :VimDev to check latest loaded lists
              -- print(vim.env.VIMRUNTIME) --/opt/homebrew/Cellar/neovim/0.11.3/share/nvim/runtime
              -- uncomment to test
              require "sidekick.cli.terminal"
              require "snacks"
              require "lazydev"
              print(Snacks.bigfile)
              print "Debug Me tool executed"
              vim.uv.sleep(1000)
            end,
          },
        },
      },
    },
    keys = require("utils.editor_keymaps").keymaps.sidekick,
  },
  --#region AI tools moved from myEditor.lua
  -- image support for code companion , requires pngpaste , brew install pngpaste https://github.com/jcsalterego/pngpaste
  {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    keys = editor_keymaps.keymaps.img_clip,
    opts = {
      default = {
        prompt_for_file_name = false,
        template = "[Image$CURSOR]($FILE_PATH)",
        use_absolute_path = false,
        drag_and_drop = {
          insert_mode = false,
        },
      },
      filetypes = {
        codecompanion = {
          prompt_for_file_name = false,
          use_absolute_path = true,
        },
        AvanteInput = {
          prompt_for_file_name = false,
          use_absolute_path = true,
        },
      },
    },
  },
  {
    "github/copilot.vim",
    -- v1.58.0 has issue errors 2026-01-26 02:58
    version = "1.57.0",
    enabled = ENABLE_COPILOT,
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      { "github/copilot.vim" },
      { "nvim-lua/plenary.nvim" },
    },
    enabled = ENABLE_COPILOT,
    keys = editor_keymaps.keymaps.copilot_chat,
    opts = {
      model = require("utils.my_ai_constants").DEFAULT_COPILOT_MODEL,
    },
  },
  {
    "yetone/avante.nvim",
    -- Single canonical spec for Avante: do not declare yetone/avante again in plugins/extra/avante.lua.
    -- lazy.nvim merges plugin fragments but does not merge `config` — a second fragment's config would replace this one.
    enabled = true,
    -- https://github.com/yetone/avante.nvim?tab=readme-ov-file#default-setup-configuration
    config = function(_, opts)
      require("avante").setup(opts)

      -- Avante model selector iterates over `avante.config.providers` keys and will
      -- try to list models for each provider. Avante defaults include `copilot`,
      -- so remove it entirely when Copilot is disabled to avoid 403/suspended errors.
      if not ENABLE_COPILOT then
        local cfg = require "avante.config"
        cfg.providers.copilot = nil
      end

      -- Group descriptions for which-key (the originals lived in
      -- lua/plugins/extra/avante.lua's config; restore here since this config wins).
      local ok, wk = pcall(require, "which-key")
      if ok then
        wk.add {
          { "<leader>r", group = "AI / Avante" },
          { "<leader>rs", group = "Avante models (default)" },
          { "<leader>rS", group = "Avante models (AGD)" },
        }
      end
    end,
    opts = {
      -- provider = "copilot", -- You can then change this provider here
      provider = DEFAULT_PROVIDER, -- You can then change this provider here
      web_search_engine = {
        -- provider = "tavily", -- tavily, serpapi, google, kagi, brave, or searxng
        provider = "google",
      },
      -- Providers: register openai_agd (AGD proxy); optional copilot block if you re-enable Copilot
      -- See lua/utils/my_avante_utils.lua
      providers = vim.tbl_extend(
        "force",
        avante_utils.get_agoda_providers(),
        ENABLE_COPILOT and { copilot = { model = AI_CONST.DEFAULT_COPILOT_MODEL } } or {}
      ),

      acp_follow_agent_locations = false,
      selection = {
        enabled = true,
        hint_display = "none",
      },
      behavior = {
        -- auto_set_keymaps = false,
        allow_access_to_git_ignored_files = true, -- still not allow outside repo / root how ?
      },
      mappings = { -- https://github.com/yetone/avante.nvim/blob/5df39b480d438a46afa1571db6480210bccea21b/lua/avante/config.lua#L641
        ---@class AvanteConflictMappings
        sidebar = {
          switch_windows = "<C-Tab>", -- not work
        },
        files = {
          add_current = "<leader>rc", -- wil get map after avante is show
          add_all_buffers = "<leader>rC",
        },
        toggle = {
          debug = "<leader>rd", -- discard to some random key
          selection = "<localleader>ax",
        },
        ask = "<leader>ra",    -- Change 'Ask' to <leader>ua
        select_history = "<leader>rh",
        focus = "<localleader>ax", -- discard to some random key
        select_model = "<leader>rM",
        select_acp_model = "<localleader>arM",
        select_acp_mode = "<localleader>arm", -- discard key, avoid <leader>am collision
      },
    },
    keys = editor_keymaps.keymaps.avante,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    opts = {
      file_types = { "markdown", "Avante" },
    },
    ft = { "markdown", "Avante" },
  },
  --#endregion AI tools moved from myEditor.lua
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { vim.g.ai_prefix_key or "<leader>A", group = "Code Companion", mode = { "n", "v" } },
        { "<leader>ah", group = "MCPHub", mode = { "n" } },
        { "<leader>am", group = "Minuet", icon = "󱗻", mode = { "n" } },
        { "<leader>amd",  group = "Duet 🔮" },
        { "<leader>amS", group = "servers/FIM", icon = "󰒋", mode = { "n" } },
        { "<leader>aM", group = "sidekick", icon = "󰚩", mode = { "n" } },
        { "<leader>aMm", group = "NES", icon = "󰚩", mode = { "n" } },
        { "<leader>Am", group = "Commit Message", mode = { "n" } },
        { "<leader>Amm", desc = "Git staged commit msg", mode = { "n" } },
        { "<leader>AmM", desc = "Git staged commit msg (large files)", mode = { "n" } },
        { "<leader>Amf", desc = "Review staged commit (fast, gpt-4.1)", mode = { "n" } },
        { "<leader>C", group = "Claude Code", mode = { "n", "v" }, icon = "🤖" },
      },
    },
  },

  {
    "ravitemer/mcphub.nvim",
    version = "6.2.0",
    -- MCPHub.nvim - MCP client and tool bridge for AI chat plugins
    --     require("mcphub")
    --     Do more investigation on integration and amed the documentation of dependencies check to reflect the investigations on these sites:
    -- @{fetch_webpage}
    --
    -- @{full_stack_dev}
    --
    -- https://ravitemer.github.io/mcphub.nvim/extensions/avante.html
    -- https://ravitemer.github.io/mcphub.nvim/extensions/codecompanion
    -- https://ravitemer.github.io/mcphub.nvim/extensions/copilotchat.html
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    cmd = "MCPHub",
    build = "bundled_build.lua",
    -- MCPHub extension - enables MCP tools/resources in CodeCompanion
    -- Usage:
    --   @{mcp}           - All tools via use_mcp_tool
    --   @{server}        - All tools from a server
    --   @{server__tool}  - Specific tool
    --   #{mcp:resource}  - Resource as variable
    --   /mcp:prompt      - MCP prompt as slash command
    --
    config = function(_, opts)
      local auth = require "utils.mcphub_auth"
      -- MCPHubClearAuth user command
      -- Clears stale OAuth credentials from ~/.local/share/mcp-hub/oauth-storage.json.
      -- Use when an upstream MCP server resets its client registry (pod restart / DCR eviction)
      -- causing "client ID not found in server's client registry" on the consent page.
      -- After clearing, restart the server from :MCPHub UI (press R on the server row).
      -- See: lua/utils/mcphub_auth.lua, docs/memory/mcphub.md

      vim.api.nvim_create_user_command("MCPHubClearAuth", function(cmdopts)
        local url = vim.trim(cmdopts.args or "")
        if url == "" then
          auth.pick_and_clear()
        else
          auth.clear_notify(url)
        end
      end, {
        nargs = "?",
        desc = "Clear MCPHub OAuth credentials (no arg = picker, arg = server URL)",
        complete = function(_, _, _)
          return require("utils.mcphub_auth").list_all_urls()
        end,
      })
      require("mcphub").setup(opts)
    end,
    opts = {
      use_bundled_binary = mcphub_backend.use_bundled_binary,
      server_url = mcphub_backend.server_url,
      cmd = mcphub_backend.cmd,
      cmdArgs = mcphub_backend.cmdArgs,
      config = vim.fn.expand "~/dotfiles/ai/mcp/mcphub.json",
      shutdown_delay = 60 * 60 * 1000, -- 60min ~ Delay in ms before shutting down the server when last instance closes (default: 5 minutes)
      port = is_git_worktree_profile and 37374 or 37373,
      -- Disable workspace mode for consistent port access by CLI agents on worktree profiles.
      -- Main checkout keeps workspace mode enabled.
      -- Without this, workspace mode creates per-directory hubs on random ports (40000-41000)
      workspace = {
        -- enabled = false,
        enabled = not is_git_worktree_profile,
        look_for = { ".mcphub/servers.json" },
        port_range = { min = 40000, max = 41000 }, -- Port range for generating unique workspace ports
        -- TODO: check if needed
        get_port = function()
          -- Derive unique port per profile to prevent multi-profile conflicts
          -- (see tasks/open/mcphub-multi-profile-port-conflict.md)
          -- local appname = vim.env.NVIM_APPNAME or "nvim"
          -- if appname:find("nvimwt") then
          --   return 47475 -- worktree profile
          -- end
          return is_git_worktree_profile and 47475 or 47474
        end,
        -- more tried notes + config ./mypoc.lua
        -- mcp-hub --port 47474 --config ~/dotfiles/ai/mcp/mcphub.json --config ./.mcphub/project.json
      },
      auto_approve = false,
      auto_toggle_mcp_servers = true,
      extensions = {
        copilotchat = {
          enabled = ENABLE_COPILOT,
          convert_tools_to_functions = true,
          convert_resources_to_functions = true,
          add_mcp_prefix = false,
        },
        avante = {
          make_slash_commands = true,
        },
      },
      ui = {
        window = {
          width = 0.8,
          height = 0.8,
        },
        -- patch 05: endpoints + agent registry sections in :MCPHub main view
        endpoints = {
          enabled = true,
        },
        agent_registry = {
          enabled = true,
          default_agent_id = "claude",
          default_scope = "user",
          agents = {
            {
              name = "claude",
              binding_flat = "mcphub",
              binding_lean = "mcphub-lean",
              config_alternates = {
                {
                  key ="m",
                  label = "e_mng",
                  path = "/Library/Application Support/ClaudeCode/managed-settings.json"
                },
                {
                  key = "1",
                  label = "pm",
                  path = "~/.claude/settings.json",
                  matcher = ".permissions",
                },
                {
                  key = "2",
                  label = "og_pm",
                  path = "~/dotfiles/ai/claude/settings.json",
                  matcher = ".permissions",
                },
                {
                  key = "s",
                  label = "jsn",
                  path = "~/.claude.json",
                  matcher = ".mcpServers",
                },
              },
            },
            {
              id = "claude-agd",
              preset = "claude",
              label = "claude-agd",
              command = "claude",
              config_dir = "~/.claude-agd",
              config_path = "~/.claude-agd/.claude.json",
              config_alternates = {
                {
                  key = "1",
                  label = "pm",
                  path = "~/.claude-agd/settings.json",
                  matcher = ".permissions",
                },
                {
                  key = "2",
                  label = "og_pm",
                  path = "~/dotfiles/ai/claude/cc-agd/settings.json",
                  matcher = ".permissions",
                },
                {
                  key = "s",
                  label = "jsn",
                  path = "~/.claude-agd/.claude.json",
                  matcher = ".mcpServers",
                },
              },
              binding_flat = "mcphub",
              binding_lean = "mcphub-lean",
              scopes = { "user" },
            },
            {
              name = "codex",
              binding_flat = "mcphub",
              binding_lean = "mcphub-lean",
              config_alternates = {
                {
                  key = "1",
                  label = "s_mc",
                  path = "~/.codex/config.toml",
                  matcher = ".mcp_servers",
                },
              },
            },
            {
              name = "cursor",
              binding_flat = "mcphub",
              binding_lean = "mcphub-lean",
              config_alternates = {
                {
                  key = "1",
                  label = "usr_mcp",
                  path = "~/.cursor/mcp.json",
                  matcher = ".mcpServers",
                },
                {
                  key = "2",
                  label = "p_mcp",
                  path = "./.cursor/mcp.json",
                  matcher = ".mcpServers",
                },
              },
            },
            { name = "opencode", binding_flat = "mcphub", binding_lean = "mcphub-lean" },
          },
          scopes = { "user", "project" },
        },
        token_counts = {
          enabled = true,
          servers = true,
          tools = true,
        },
      },
      log = {
        -- level = vim.log.levels.WARN, -- patch03 apply this correctly on UI to hide SSE client connection
        level = vim.log.levels.INFO,
        to_file = false,
      },
    },
    keys = {
      { "<leader>ah", "<cmd>MCPHub<cr>", desc = "MCPHub" },
      {
        "<leader>aHx",
        function()
          require("utils.mcphub_auth").pick_and_clear()
        end,
        desc = "Clear MCPHub OAuth (picker)",
      },
    },
  },

  -- Blink.cmp integration for Avante completion
  -- Provides autocomplete for MCP prompts, tools, and resources in Avante chat
  -- does rank lower than custom settings in lua/plugins/extra/myEditor.lua:1275
  -- {
  --   "saghen/blink.cmp",
  --   dependencies = {
  --     "Kaiser-Yang/blink-cmp-avante", -- same as manual (need to configure order again)
  --   },
  --   opts = {
  --     sources = {
  --       default = { 'avante', 'lsp', 'path', 'snippets', 'buffer' },
  --       -- default = { 'avante' }, -- avante should be on top of the list (else get other merged)
  --       providers = {
  --         avante = {
  --           name = "Avante",
  --           module = "blink-cmp-avante",
  --           -- Show Avante completions alongside other sources
  --           -- Disabled by default in Avante chat context to avoid conflicts
  --           opts = {},
  --         },
  --       },
  --     },
  --   },
  -- },
  -- CodeCompanion spec moved to lua/plugins/extra/myCodecomp.lua
  {
    "greggh/claude-code.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      command = "claude --allow-dangerously-skip-permissions",
    },
  },
  {
    "coder/claudecode.nvim",
    opts = {
      -- terminal_cmd = "claude --allow-dangerously-skip-permissions",
      terminal_cmd = vim.env.HOME .. "/dotfiles/ai/claude/cc-agd/cag.sh --allow-dangerously-skip-permissions",
      -- terminal_cmd = "claude",
    },
    -- lua/plugins/extra/claude-code.lua:194
    keys = {
      {
        CLAUDE_CODER_MAPPING_PREFIX .. "C",
        "<cmd>ClaudeCode --continue <cr>",
        desc = "Toggle Claude Continue",
      },
      { CLAUDE_CODER_MAPPING_PREFIX .. "M", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
      {
        "<leader>as",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file",
        ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
      },
    },
  },
}
