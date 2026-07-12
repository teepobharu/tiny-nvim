---
title: "Cursor Migration - AI Tools Container Setup"
status: "open"
assignee: "ai"
created: 2026-01-28
updated: 2026-07-02
priority: "medium"
category: "ai-tooling"
related:
  - [Docker Compose](tasks/open/cursor-migration/docker-compose.yml)
  - [Dockerfile](tasks/open/cursor-migration/Dockerfile)
  - [Current Avante](lua/plugins/extra/avante.lua)
  - [CodeCompanion](lua/plugins/extra/codecompanion.lua)
---

## Objective

Explore and setup Cursor-like AI capabilities for Neovim via containerized environment with multiple profiles and persistent sessions.

## Investigation scope

*New*
- code companion cursor integration and model selection for the cursor adapater / provider vs copilot

*Done*
- [x] Find alternatives for nvim plugins copilot.vim auto completion → **minuet-ai.nvim** (see Minuet completion phase below)

## Action Items

- [ ] Split completed Minuet notes into a permanent memory doc if they should outlive this migration task.
- [ ] Decide whether the remaining work is container testing, Cursor ACP integration, or Minuet completion verification.
- [ ] Run the unchecked container profile tests only if the container path is still relevant.
- [ ] Update this task's lifecycle location after deciding whether it belongs in `tasks/open/` or `tasks/wip/`.

## Points to Confirm

- [ ] Confirm whether Cursor CLI/ACP integration is still the goal, or whether Minuet plus CodeCompanion is enough.
- [ ] Confirm whether Docker/container testing should continue on this repo or be archived as superseded.
- [ ] Confirm the final completion stack when Copilot is disabled: Minuet AGD, local FIM, or both.

## Checklist

### Setup Phase
- [x] Research Cursor-Neovim integration options
- [x] Create Docker container with AI CLIs
- [x] Setup plugin overlay system
- [x] Configure multiple profiles (minimal, standard, full, cursor)
- [x] Add host integrations (git, ssh, clipboard)
- [x] Setup persistent volumes for sessions

### Testing Phase
- [ ] Build container: `make build`
- [ ] Test standard profile: `make run`
- [ ] Test full profile: `make run-full`
- [ ] Test GPU profile: `make run-gpu` (if NVIDIA available)
- [ ] Verify plugin overlay works
- [ ] Test goose CLI: `make goose`

### Integration Phase
- [ ] Decide which plugins to adopt (goose.lua, agentic.lua)
- [ ] Copy chosen plugins to lua/plugins/extra/
- [ ] Configure keybindings
- [ ] Update docs/memory/avante.md with learnings

## Key Findings

1. **No official Cursor-Neovim plugin** - Community solutions only
2. **Best alternatives**:
   - `avante.nvim` (17k stars) - Already installed, enable Zen Mode
   - `goose.nvim` - Open-source agent from Block
   - `agentic.nvim` - Multi-provider ACP client
3. **Container approach** allows testing without polluting host config

## Tools compatibility
- opencode (requires local sv run): https://github.com/Nomadcxx/opencode-cursor

## User notes (DO NOT EDIT)
### Refs
- https://cursor.com/docs/cli/acp#ide-integrations
Nvim plugins
- https://github.com/milanglacier/minuet-ai.nvim
  - rich integration: profile and endpoint configure ollama / llama.cpp, support preset with openai compatible
  - try with openai provider : https://github.com/milanglacier/minuet-ai.nvim#openai
- llama only ? https://github.com/ggml-org/llama.vim

### Quota comparison
Agoda License:
- Copilot - 300 interactions / mo
- Cursor - 500 interactions + 250$ credit / mo

### Findings
- Sidekick NES only integrates copilot

### Alternatives for completion
https://github.com/cursortab/cursortab.nvim#providers
- allow llama.cpp local models qwen 0.8B local fast (not sure about multiple instances RAM perf)

---

## Migration Options

| Approach | Plugin | Stars | Status |
|----------|--------|-------|--------|
| Direct CLI wrapper | `cursor-agent.nvim` | 49 | Active |
| ACP multi-provider | `agentic.nvim` | 162 | Active |
| Full Cursor-like UX | `avante.nvim` | 17.2k | **Recommended** |
| Open-source agent | `goose.nvim` | 304 | Active |

### Option 1: Enhance Existing Avante (Minimal Change)

```lua
-- lua/plugins/extra/avante.lua enhancements
{
  "yetone/avante.nvim",
  opts = {
    provider = "claude",
    auto_suggestions_provider = "copilot",
    behaviour = {
      auto_apply_diff_after_generation = true,
      support_paste_from_clipboard = true,
    },
  },
}
```

### Option 2: cursor-agent.nvim (Direct Cursor CLI)

Requires Cursor Pro subscription and CLI. See `sample-plugins/cursor-agent.lua`.

### Option 3: agentic.nvim (Multi-Provider ACP)

Supports Claude, Gemini, Cursor, Codex. See `sample-plugins/agentic.lua`.

### Option 4: goose.nvim (Open-Source)

Uses Block's Goose AI agent. See `sample-plugins/goose.lua`.

## Quick Start

```bash
cd tasks/open/cursor-migration
cp .env.example .env
# Edit .env with API keys

make build        # Build container
make run          # Standard profile
make run-full     # All AI tools + MCP Hub
make run-minimal  # Base config only
make run-cursor   # Cursor CLI focus
make run-gpu      # With Ollama local LLMs
```

## Project Structure

```
cursor-migration/
├── Dockerfile            # Neovim + AI CLIs (goose, aider, cursor-acp)
├── docker-compose.yml    # Multi-profile container stack
├── Makefile              # Convenience commands
├── entrypoint.sh         # Plugin overlay system
├── configs/
│   ├── goose-config.yaml # Goose agent settings
│   ├── mcp-servers.json  # MCP Hub config
│   └── .cursorrules      # Cursor rules example
└── sample-plugins/
    ├── agentic.lua       # Multi-provider ACP
    ├── goose.lua         # Open-source agent
    ├── cursor-agent.lua  # Direct Cursor CLI
    └── avante-enhanced.lua
```

## Feature Comparison

| Feature | Copilot | Cursor | Avante | CodeCompanion |
|---------|---------|--------|--------|---------------|
| Inline completion | ✅ | ✅ | ✅ | ❌ |
| Chat sidebar | ✅ | ✅ | ✅ | ✅ |
| Agentic mode | ✅ | ✅ | ✅ | ✅ |
| Plan mode | ❌ | ✅ | ✅ | ❌ |
| MCP support | ❌ | ✅ | ✅ | ✅ |
| Price | $10/mo | $20/mo | Free | Free |

---

## Minuet-AI Completion Setup

Replaces copilot inline completion when `vim.g.ai_enable_copilot = false`.
File: [`lua/plugins/extra/myMinuet.lua`](lua/plugins/extra/myMinuet.lua)

### Profile matrix

All provider slots loaded at startup; switch without restart:

| Slot | Provider type | Default model | Prereqs |
|------|--------------|---------------|---------|
| `openai_compatible` (default) | chat via AGD proxy | `gemini-3-flash-preview` | `GENAIAG` env set |
| `openai` | chat via AGD proxy (OpenAI format) | `gpt-5.4-nano` | `GENAIAG` env set |
| `openai_fim_compatible` (ollama) | FIM/local | `qwen2.5-coder:3b-base` | `ollama serve` + model pulled |
| `openai_fim_compatible` (llamacpp) | FIM/local | `qwen2.5-coder-1.5b` GGUF | `llama-server` running port 8012 |

Per-project FIM default: `vim.g.ai_minuet_fim_profile = "llamacpp"` in `.nvim-config.lua`

> **FIM requires `-base` model variants** — instruct models (qwen2.5-coder:3b without `-base`) do not support fill-in-middle tokens.

### Per-project FIM switch

```lua
-- .nvim-config.lua
vim.g.ai_minuet_fim_profile = "llamacpp"           -- FIM backend (ollama|llamacpp)
vim.g.ai_ollama_model = "qwen2.5-coder:7b-base"  -- override ollama model
vim.g.ai_minuet_profile = "ollama"                -- back-compat alias for fim_profile
```

### Keymap

All minuet/duet normal-mode keys under `<leader>am*`. Servers + FIM under `<leader>amS*`. Sidekick NES under `<leader>aMm*`.

| Key | Mode | Action |
|-----|------|--------|
| `<C-c>` | i | blink.cmp: show minuet (copilot when enabled, minuet when disabled) |
| `<A-]>` / `<A-[>` | i | virttext cycle next / prev |
| `<A-A>` / `<A-a>` / `<A-z>` / `<A-e>` | i | virttext accept full / line / N lines / dismiss |
| `<A-d>` / `<A-c>` / `<A-x>` | i | duet predict / apply / dismiss |
| `<leader>amm` | n | virttext toggle |
| `<leader>ame` / `<leader>amE` | n | virttext enable (action / cmd) |
| `<leader>amd` / `<leader>amD` | n | virttext dismiss / disable |
| `<leader>amp` / `<leader>ama` / `<leader>amx` | n | duet predict / apply / dismiss |
| `<leader>amu` | n | duet predict (alt) |
| `<leader>amM` | n | pick model (`:Minuet change_model`) |
| `<leader>amP` | n | pick preset (`:MinuetPresetPick` — agd/fim_ollama/fim_llamacpp/original) |
| `<leader>amSo` | n | start Ollama in bg (`:MinuetOllamaStart`) |
| `<leader>amSc` | n | start llama.cpp in bg (`:MinuetLlamacppStart`) |
| `<leader>amSf` / `<leader>amSF` | n | switch FIM → Ollama / llama.cpp |
| `<leader>amSs` | n | status (live provider/model/endpoint) |
| `<leader>aMmt` / `<leader>aMme` / `<leader>aMmd` / `<leader>aMmu` | n | Sidekick NES toggle / enable / disable / update |

### Helper commands

| Command | Action |
|---------|--------|
| `:MinuetOllamaStart` | Start `ollama serve` background (OLLAMA_NUM_PARALLEL=2) |
| `:MinuetOllamaPull [model]` | Pull FIM model into ollama (terminal buffer) |
| `:MinuetLlamacppStart [model]` | Start `llama-server` port 8012 background |
| `:MinuetFimSwitch ollama\|llamacpp` | Swap FIM backend at runtime (endpoint+model only) |

### Preset menu (`<leader>aP`)

`:Minuet change_preset` does an atomic deep-merge switch of provider+endpoint+model:

| Preset | Provider | Backend |
|--------|----------|---------|
| `agd` | `openai_compatible` | AGD proxy, `gemini-3-flash-preview` |
| `fim_ollama` | `openai_fim_compatible` | ollama localhost:11434, `qwen2.5-coder:3b-base` |
| `fim_llamacpp` | `openai_fim_compatible` | llama.cpp localhost:8012, `qwen2.5-coder-1.5b` |
| `original` | (initial config) | auto-captured by minuet at setup |

Use `<leader>aP` for full profile swaps. Use `:MinuetFimSwitch` for quick ollama↔llamacpp toggling (skips provider reset).

### Local model guide (M4 Max 36 GB, ~3 GB nvim baseline)
- **AGD profile**: `<leader>aS` → picker shows `openai_compatible:<model>` (AGD top_choices). Selecting one keeps AGD backend/endpoint/token, only model ID changes.
- **Non-AGD picks** (`gemini:*`, `claude:*`, `openai:*`) switch to direct backends — need `GEMINI_API_KEY` / `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`. Picking `gemini:gemini-3.1-flash-lite-preview` works when `GEMINI_API_KEY` is set.
- `<leader>aM` shows live status — confirm `subprovider.name=AGD` + AGD proxy endpoint to verify AGD routing.
**Model weights load once** in ollama/llama.cpp — shared across all nvim instances.
**KV cache grows per concurrent request** (~300–700 MB @ 4k ctx depending on model).
**Metal backend serializes decode** — N nvim instances queue, not parallel GPU.

#### Model comparison (Q4_K_M, M4 Max)

| Model | FIM | RAM (wt) | TTFT | tok/s | KV/req@4k | Notes |
|-------|-----|----------|------|-------|-----------|-------|
| qwen2.5-coder:1.5b-base | ✅ | ~1 GB | ~80ms | ~110 | ~200 MB | Snappy, many instances |
| qwen2.5-coder:3b-base | ✅ | ~2 GB | ~150ms | ~65 | ~350 MB | **Default rec** |
| qwen2.5-coder:7b-base | ✅ | ~4.7 GB | ~400ms | ~30 | ~700 MB | 1–2 nvim, quality |
| qwen3-coder:30b-a3b (MoE) | ❌ | ~18 GB | ~700ms | ~40 | ~1.5 GB | Chat-style only, no FIM |
| deepseek-coder-v2:16b-lite-base | ✅ | ~9 GB | ~500ms | ~50 | ~1 GB | Heavy backup |
| qwen3:4b/8b | ❌ | 2.6/5.2 GB | — | — | — | Instruct-only, skip |

#### Memory budget (macOS ~10 GB + nvim × N × 3 GB + model)

| Setup | 2× nvim | 4× nvim |
|-------|---------|---------|
| + 1.5b-base | ~18 GB | ~24 GB |
| + 3b-base | ~19 GB | ~26 GB |
| + 7b-base | ~23 GB | ~30 GB |
| + 30b-a3b | ~34 GB | swap risk |

#### Multi-instance behavior

- Set `OLLAMA_NUM_PARALLEL=2` — 2 in-flight requests; rest queue (no extra model copies)
- llama.cpp: `--parallel 2 --ctx-size 8192` splits context across slots
- **Safe setup**: 4 nvim + 3b-base ≈ 26 GB — fine on 36 GB

### Checklist — Minuet completion phase

- [ ] **AGD profile**: restart nvim, `:Lazy` shows `minuet-ai.nvim` loaded; open buffer, `<A-]>` → ghost text within 3s; `<C-c>` → blink menu shows AGD completion
- [ ] `:lua =require('blink.cmp.config').sources.providers.minuet` → table present
- [ ] **change_model AGD**: `<leader>aS` → picker lists `openai_compatible:gpt-4.1-mini`, `openai_compatible:claude-sonnet-4-6`, etc.; `<leader>aM` shows `subprovider.name=AGD` + AGD proxy endpoint
- [ ] **Copilot ON guard**: `.nvim-config.lua` → `vim.g.ai_enable_copilot = true`, restart → `minuet-ai.nvim` NOT in `:Lazy`; `<C-c>` shows copilot; `<A-]>` noop
- [ ] **Ollama profile**: `vim.g.ai_minuet_profile = "ollama"`, `ollama serve`, pull `qwen2.5-coder:3b-base`, `<A-]>` → FIM ghost text
- [ ] **Ollama silent fallback**: kill ollama, `<A-]>` → timeout ~3s, no error popup (check `:messages`)
- [ ] **llama.cpp profile**: `llama-server -m qwen2.5-coder-1.5b-q4_k_m.gguf --port 8012 --parallel 2`, `vim.g.ai_minuet_profile = "llamacpp"`, `<A-]>` → FIM ghost text

---

## Verification (User)

To check minuet
- [ ] multi profile suggestion, icon customization on blink
- [ ] duet mode nes fuinction
- [ ] ghost virtual text
- [ ] toggle change profile ?

Prerequisites:

```bash
cd tasks/open/cursor-migration
cp .env.example .env
# Edit .env with your API keys
```

### Build & Run
- [ ] `make build` - Container builds without errors
- [ ] `make run` - Opens nvim with your config
- [ ] Plugins load correctly (check `:Lazy`)
- [ ] Exit nvim cleanly

### Profiles
- [ ] `make run-minimal` - Opens minimal config
- [ ] `make run-full` - Opens with all AI tools
- [ ] Plugin overlay visible in `lua/plugins/extra/`

### AI Tools
- [ ] `make goose` - Goose CLI starts
- [ ] `make shell` - Can access container shell
- [ ] `make mcp` - MCP Hub starts on :5555

### Host Integration
- [ ] Git operations work inside container
- [ ] Can edit files in /workspace
- [ ] Changes persist after container restart
