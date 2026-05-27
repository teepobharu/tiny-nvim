-- AI completion fallback via minuet-ai.nvim (active only when Copilot is OFF)
-- AGD default: openai_compatible → gemini-3-flash-preview via AGD proxy
-- All provider slots loaded at startup; switch at runtime via:
--   :Minuet change_provider openai_fim_compatible  (→ FIM / local)
--   :MinuetFimSwitch ollama|llamacpp               (swap local backend)
--   <leader>amM → :Minuet change_model             (virttext model picker)
--   <leader>amd* → duet subgroup (m=model, P=provider, s=status, p/a/x=predict/apply/dismiss)
-- GPT-5+/o-series compat: rewrite_gpt5_max_tokens transform swaps max_tokens →
-- max_completion_tokens at request time (gemini/claude/gpt-4.x unaffected).
-- Per-project FIM override: vim.g.ai_minuet_fim_profile = "llamacpp" in .nvim-config.lua
-- Docs: https://github.com/milanglacier/minuet-ai.nvim

local AI_CFG = require "utils.my_ai_default_config"
local AI = require "utils.my_ai_constants"

if AI_CFG.ENABLE_COPILOT then
  return {} -- copilot path active; skip minuet
end

-- FIM backend: "ollama" (default) | "llamacpp"
-- vim.g.ai_minuet_profile kept as back-compat alias
local fim_profile = vim.g.ai_minuet_fim_profile or vim.g.ai_minuet_profile or "ollama"

-- openai_base.complete_openai_fim_base unconditionally calls options.template.prompt(...)
-- upstream deepseek/codestral presets include template; full slot override loses it → nil crash
local ok_cfg, minuet_cfg = pcall(require, "minuet.config")
local default_fim_template = (ok_cfg and minuet_cfg.default_fim_template) or {
  prompt = function(before, _, _) return before end,
  suffix = function(_, after, _) return after end,
}

local fim_presets = {
  ollama = {
    api_key = "TERM", -- dummy; ollama ignores auth
    name = "Ollama",
    end_point = (vim.g.ai_ollama_endpoint or "http://localhost:11434") .. "/v1/completions",
    model = vim.g.ai_ollama_model or "qwen2.5-coder:3b-base",
    stream = true,
    template = default_fim_template,
    optional = { max_tokens = 256, top_p = 0.9 },
    get_text_fn = {}, -- required by backend; empty = use builtin json.choices[1].text
    transform = {},
  },
  llamacpp = {
    api_key = "TERM", -- dummy
    name = "llama.cpp",
    end_point = (vim.g.ai_llamacpp_endpoint or "http://localhost:8012") .. "/v1/completions",
    model = vim.g.ai_llamacpp_model or "qwen2.5-coder-1.5b",
    stream = true,
    template = default_fim_template,
    optional = { max_tokens = 256, top_p = 0.9 },
    get_text_fn = {},
    transform = {},
  },
}

-- AGD/OpenAI: GPT-5+ and o-series reject `max_tokens`, requiring `max_completion_tokens`.
-- Gemini/Claude/GPT-4.x via the same AGD chat endpoint still accept `max_tokens`,
-- so this transform only mutates the wire body when the model name matches.
-- Wired into every openai_compatible / openai slot below as `transform = { rewrite_gpt5_max_tokens }`.
local function rewrite_gpt5_max_tokens(t)
  local body = t.body
  if type(body) == "table" and type(body.model) == "string" and body.max_tokens then
    local m = body.model
    if m:match "^gpt%-5" or m:match "^gpt%-o" or m:match "^o%d" then
      body.max_completion_tokens = body.max_tokens
      body.max_tokens = nil
    end
  end
  return t
end

-- All provider slots populated at load so :Minuet change_provider works without restart.
-- stream=true + request_timeout=3: timeout cancels mid-flight but keeps partial tokens.
-- If AGD proxy doesn't forward SSE → completions empty → flip stream=false + timeout=10.
local setup_opts = {
  provider = "openai_compatible", -- AGD default
  notify = "debug",
  request_timeout = 3,
  n_completions = 3,
  context_window = 16000,
  throttle = 1000,
  debounce = 400,
  provider_options = {
    openai_compatible = {
      end_point = AI.endpoints.agoda.OPENAI_PROXY_CHAT,
      api_key = "GENAIAG",
      model = AI.models.gemini.GEMINI_3_FLASH .. "-preview",
      name = "AGD",
      stream = true,
      optional = { max_tokens = 256, top_p = 0.9 },
      transform = { rewrite_gpt5_max_tokens },
    },
    openai_fim_compatible = fim_presets[fim_profile] or fim_presets.ollama,
    -- openai slot: OpenAI model names routed through AGD proxy (same endpoint + key)
    openai= {
      model = AI.providers.openai_agd.top_choices.gpt.default.XS,
      end_point = AI.endpoints.agoda.OPENAI_PROXY_CHAT,
      api_key = "GENAIAG",
      stream = true,
      optional = {},
      transform = { rewrite_gpt5_max_tokens },
    },
    -- gemini / claude use minuet defaults; require GEMINI_API_KEY / ANTHROPIC_API_KEY
  },
  virtualtext = {
    auto_trigger_ft = {},
    keymap = {
      accept = "<A-A>",
      accept_line = "<A-a>",
      accept_n_lines = "<A-z>",
      prev = "<A-[>",
      next = "<A-]>",
      dismiss = "<A-e>",
    },
    show_on_completion_menu = false,
  },
}
-- Duet has its own config namespace (NOT shared with setup_opts.provider_options).
-- M.config.duet.provider selects the backend (gemini|openai|claude|openai_compatible);
-- M.config.duet.provider_options[<provider>] holds endpoint/key/model.
-- Built-in :Minuet change_model only edits M.config.provider_options, NOT duet —
-- switch duet model at runtime via :MinuetDuetModel / <leader>amD.
setup_opts.duet = {
  provider = "openai_compatible",
  provider_options = {
    openai_compatible = {
      end_point = AI.endpoints.agoda.OPENAI_PROXY_CHAT,
      api_key = "GENAIAG",
      model = AI.models.gemini.GEMINI_3_FLASH .. "-preview",
      name = "AGD",
      optional = { max_tokens = 512, top_p = 0.9 },
      transform = { rewrite_gpt5_max_tokens },
    },
  },
}

-- Presets for :Minuet change_preset — atomic provider+endpoint+model switch
-- "original" preset is auto-registered by minuet (captures initial config)
setup_opts.presets = {
  agd = {
    provider = "openai_compatible",
    provider_options = {
      openai_compatible = {
        end_point = AI.endpoints.agoda.OPENAI_PROXY_CHAT,
        api_key = "GENAIAG",
        model = AI.models.gemini.GEMINI_3_FLASH .. "-preview",
        name = "AGD",
        stream = true,
        optional = { max_tokens = 256, top_p = 0.9 },
        transform = { rewrite_gpt5_max_tokens },
      },
    },
  },
  fim_ollama = {
    provider = "openai_fim_compatible",
    provider_options = { openai_fim_compatible = fim_presets.ollama },
  },
  fim_llamacpp = {
    provider = "openai_fim_compatible",
    provider_options = { openai_fim_compatible = fim_presets.llamacpp },
  },
}

return {
  {
    "milanglacier/minuet-ai.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "InsertEnter",
    cmd = { "Minuet" },
    main = "minuet",
    config = function(_, opts)
      require("minuet").setup(opts)


      -- Inject AGD subprovider into modelcard so :Minuet change_model surfaces AGD top_choices.
      -- minuet keys subprovider by lower(provider_options[p].name) → "agd"
      -- Apply provider_model_remap (e.g. gemini-3.1-flash-lite → gemini-3.1-flash-lite-preview)
      -- so AGD chat endpoint accepts the model ID.
      local modelcard = require "minuet.modelcard"
      modelcard.models.openai_compatible = modelcard.models.openai_compatible or {}
      local agd_models = AI.get_top_choice_models "openai_agd"
      local agd_remap = (AI.provider_model_remap or {})[AI.providers.openai_agd.adapter_name] or {}
      local agd_models_remapped = {}
      for _, m in ipairs(agd_models) do
        table.insert(agd_models_remapped, agd_remap[m] or m)
      end
      modelcard.models.openai_compatible.agd = agd_models_remapped

      -- Inject ollama + llama.cpp FIM model lists so :Minuet change_model shows FIM options.
      -- Key = lower(fim_presets.*.name): "ollama" → Ollama, "llama.cpp" → llama.cpp
      modelcard.models.openai_fim_compatible = modelcard.models.openai_fim_compatible or {}
      modelcard.models.openai_fim_compatible.ollama = {
        "qwen2.5-coder:1.5b-base",
        "qwen2.5-coder:3b-base",
        "qwen2.5-coder:7b-base",
        "deepseek-coder-v2:16b-lite-base",
      }
      modelcard.models.openai_fim_compatible["llama.cpp"] = {
        "qwen2.5-coder-0.5b",
        "qwen2.5-coder-1.5b",
        "qwen2.5-coder-3b",
      }

      -- Helper: start local ollama server in background
      vim.api.nvim_create_user_command("MinuetOllamaStart", function()
        local endpoint = vim.g.ai_ollama_endpoint or "http://localhost:11434"
        vim.fn.jobstart({ "sh", "-c", "OLLAMA_NUM_PARALLEL=2 ollama serve" }, { detach = true })
        vim.notify("ollama serve started — " .. endpoint, vim.log.levels.INFO, { title = "Minuet" })
      end, { desc = "Start local ollama server (background)" })

      -- Helper: pull FIM base model into ollama (opens terminal buffer)
      vim.api.nvim_create_user_command("MinuetOllamaPull", function(a)
        local model = a.args ~= "" and a.args or (vim.g.ai_ollama_model or "qwen2.5-coder:3b-base")
        vim.cmd("terminal ollama pull " .. model)
      end, { nargs = "?", desc = "Pull ollama FIM base model" })

      -- Helper: start llama.cpp server in background
      vim.api.nvim_create_user_command("MinuetLlamacppStart", function(a)
        local model = a.args ~= "" and a.args
          or (vim.env.LLAMACPP_MODEL or "~/models/qwen2.5-coder-1.5b-q4_k_m.gguf")
        local port = (vim.g.ai_llamacpp_endpoint or ""):match(":(%d+)$") or "8012"
        local cmd = string.format(
          "llama-server -m %s --port %s --parallel 2 --ctx-size 8192",
          vim.fn.expand(model),
          port
        )
        vim.fn.jobstart({ "sh", "-c", cmd }, { detach = true })
        vim.notify("llama-server started on :" .. port, vim.log.levels.INFO, { title = "Minuet" })
      end, { nargs = "?", desc = "Start llama.cpp server (background)" })

      -- Helper: preset picker (vim.ui.select). :Minuet change_preset with no arg errors
      -- "preset not supported" — wrap in picker for keymap use.
      vim.api.nvim_create_user_command("MinuetPresetPick", function()
        local m = require "minuet"
        local presets = {}
        for k, _ in pairs(m.presets or {}) do
          table.insert(presets, k)
        end
        table.sort(presets)
        vim.ui.select(presets, { prompt = "Minuet preset:" }, function(choice)
          if choice then
            m.change_preset(choice)
          end
        end)
      end, { desc = "Pick minuet preset (agd/fim_ollama/fim_llamacpp/original)" })

      -- Duet pickers — operate on M.config.duet.* (separate from virttext M.config.provider_options.*)
      -- :MinuetDuetModel — pick AGD model for duet's openai_compatible slot.
      vim.api.nvim_create_user_command("MinuetDuetModel", function()
        local m = require "minuet"
        if not m.config then
          vim.notify("minuet not loaded", vim.log.levels.WARN, { title = "Duet" })
          return
        end
        vim.ui.select(agd_models_remapped, { prompt = "Duet AGD model:" }, function(choice)
          if not choice then return end
          m.config.duet.provider = "openai_compatible"
          m.config.duet.provider_options.openai_compatible.model = choice
          vim.notify("Duet model → " .. choice, vim.log.levels.INFO, { title = "Duet" })
        end)
      end, { desc = "Pick duet model (AGD openai_compatible)" })

      -- :MinuetDuetProvider — switch duet backend (openai_compatible/gemini/openai/claude).
      vim.api.nvim_create_user_command("MinuetDuetProvider", function()
        local m = require "minuet"
        local providers = {}
        for k, _ in pairs(m.config.duet.provider_options or {}) do
          table.insert(providers, k)
        end
        table.sort(providers)
        vim.ui.select(providers, { prompt = "Duet provider:" }, function(choice)
          if not choice then return end
          m.config.duet.provider = choice
          local po = m.config.duet.provider_options[choice] or {}
          vim.notify(
            string.format("Duet provider → %s (%s)", choice, po.model or "?"),
            vim.log.levels.INFO,
            { title = "Duet" }
          )
        end)
      end, { desc = "Pick duet provider (openai_compatible/gemini/openai/claude)" })

      -- :MinuetDuetStatus — show live duet config (separate from :MinuetStatus / amSs).
      vim.api.nvim_create_user_command("MinuetDuetStatus", function()
        local m = require "minuet"
        if not m.config then
          vim.notify("minuet not loaded", vim.log.levels.WARN, { title = "Duet" })
          return
        end
        local prov = m.config.duet.provider
        local po = (m.config.duet.provider_options or {})[prov] or {}
        vim.notify(
          string.format(
            "duet (live)\n  provider=%s\n  model=%s\n  endpoint=%s\n  api_key_env=%s",
            prov, po.model or "?", po.end_point or "?", po.api_key or "?"
          ),
          vim.log.levels.INFO,
          { title = "Duet" }
        )
      end, { desc = "Show live duet provider/model/endpoint" })

      -- Helper: swap FIM backend at runtime without restart
      vim.api.nvim_create_user_command("MinuetFimSwitch", function(a)
        local preset = fim_presets[a.args]
        if not preset then
          vim.notify("usage: :MinuetFimSwitch {ollama|llamacpp}", vim.log.levels.WARN, { title = "Minuet" })
          return
        end
        require("minuet").config.provider_options.openai_fim_compatible = preset
        require("minuet").config.provider = "openai_fim_compatible"
        vim.notify(
          "minuet FIM → " .. a.args .. " (" .. preset.end_point .. ")",
          vim.log.levels.INFO,
          { title = "Minuet" }
        )
      end, {
        nargs = 1,
        complete = function() return { "ollama", "llamacpp" } end,
        desc = "Swap FIM backend at runtime",
      })
    end,
    opts = setup_opts,
    keys = {
      -- Insert-mode triggers
      { "<A-d>", "<cmd>Minuet duet predict<cr>", mode = "i", desc = "Duet: predict 🔮" },
      { "<A-c>", "<cmd>Minuet duet apply<cr>",   mode = "i", desc = "Duet: yes ✅" },
      { "<A-x>", "<cmd>Minuet duet dismiss<cr>", mode = "i", desc = "Duet: no ❌" },
      -- Normal-mode under <leader>am* (which-key group in myAi.lua)
      -- Virttext
      { "<leader>amm", "<cmd>Minuet virtualtext toggle<cr>", desc = "Virttext: toggle" },
      {
        "<leader>ame",
        function() require("minuet.virtualtext").action.enable_auto_trigger() end,
        desc = "Virttext: on 🟢",
      },
      {
        "<leader>amf",
        function() require("minuet.virtualtext").action.disable_auto_trigger() end,
        desc = "Virttext: off 🔴",
      },
      {
        "<leader>amZ",
        function() require("minuet.virtualtext").action.accept() end,
        desc = "Virttext: ✅ A-a | ❌ A-e | 🔄 A-]/A-[",
      },
      { "<leader>am.", "<cmd>Minuet duet predict<cr>",
        desc = "Duet: predict 🔮 A-d | ✅ A-c | ❌ A-x",
      },
      -- Duet subgroup under <leader>amd*
      { "<leader>amd",  group = "Duet 🔮" },
      { "<leader>amdp", "<cmd>Minuet duet predict<cr>", desc = "predict 🔮 A-d" },
      { "<leader>amda", "<cmd>Minuet duet apply<cr>",   desc = "yes ✅ A-c" },
      { "<leader>amdx", "<cmd>Minuet duet dismiss<cr>", desc = "no ❌ A-x" },
      { "<leader>amdm", "<cmd>MinuetDuetModel<cr>",     desc = "model 🎯" },
      { "<leader>amdP", "<cmd>MinuetDuetProvider<cr>",  desc = "provider 🔌" },
      { "<leader>amds", "<cmd>MinuetDuetStatus<cr>",    desc = "status ℹ️" },
      -- Model + preset pickers
      { "<leader>amM", "<cmd>Minuet change_model<cr>", desc = "Pick model (:Minuet change_model)" },
      { "<leader>amP", "<cmd>MinuetPresetPick<cr>", desc = "Pick preset (agd/fim_ollama/fim_llamacpp/original)" },
      -- Servers + FIM submenu under amS
      { "<leader>amSo", "<cmd>MinuetOllamaStart<cr>", desc = "Start Ollama in bg (:MinuetOllamaStart)" },
      { "<leader>amSc", "<cmd>MinuetLlamacppStart<cr>", desc = "Start llama.cpp in bg (:MinuetLlamacppStart)" },
      { "<leader>amSf", "<cmd>MinuetFimSwitch ollama<cr>", desc = "Switch FIM → Ollama" },
      { "<leader>amSF", "<cmd>MinuetFimSwitch llamacpp<cr>", desc = "Switch FIM → llama.cpp" },
      {
        "<leader>amSs",
        function()
          local ok, m = pcall(require, "minuet")
          if not ok or not m.config then
            vim.notify("minuet not loaded", vim.log.levels.WARN, { title = "Minuet" })
            return
          end
          local prov = m.config.provider
          local po = (m.config.provider_options or {})[prov] or {}
          vim.notify(
            string.format(
              "minuet (live)\n  provider=%s\n  subprovider.name=%s\n  model=%s\n  endpoint=%s\n  fim_profile(init)=%s",
              prov,
              po.name or "?",
              po.model or "?",
              po.end_point or "?",
              vim.g.ai_minuet_fim_profile or vim.g.ai_minuet_profile or "ollama"
            ),
            vim.log.levels.INFO,
            { title = "Minuet" }
          )
        end,
        desc = "Status (live provider/model/endpoint)",
      },
    },
  },
  {
    -- Extend blink.cmp with minuet provider + manual trigger via <C-c>.
    -- <C-c> is the unified AI-completion key: copilot (myCoding.lua) when enabled, minuet here when disabled.
    -- This file early-returns {} when ENABLE_COPILOT=true, so no conflict.
    "saghen/blink.cmp",
    opts = {
      keymap = {
        ["<C-c>"] = {
          function(cmp)
            return cmp.show { providers = { "minuet" } }
            -- if ENABLE_COPILOT cmp.show {providers = { "minuet",  "copilot" } } works ?
          end,
          "fallback",
        },
      },
      sources = {
        -- Register minuet as available source (NOT in default — manual trigger via <C-c>)
        providers = {
          minuet = {
            name = "minuet",
            module = "minuet.blink",
            score_offset = 50,
            async = true,
            timeout_ms = 3000,
          },
        },
      },
      completion = {
        trigger = {
          prefetch_on_insert = false, -- required by minuet to avoid duplicate requests
        },
      },
    },
  },
}
