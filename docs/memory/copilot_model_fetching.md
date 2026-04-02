# Copilot Adapter Model Fetching Research

## Overview
This document maps the complete lifecycle of how CodeCompanion's Copilot adapter fetches, caches, and displays available models. The key finding: **on first UI call, only the default fallback model (gpt-4.1) is shown because async background fetching is non-blocking**.

---

## 1. Model Fetching Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                    INITIALIZATION PHASE                      │
└─────────────────────────────────────────────────────────────┘

Adapter Resolution
  ↓
  resolve() handler called (async background fetch)
    - Checks if models already being fetched (_fetching_models flag)
    - Calls get_models.choices(adapter, { async = true })
    - Non-blocking: returns immediately, fetch happens in background
    - vim.schedule() defers the fetch to next event loop cycle
  ↓
Cache expires after 30 minutes (1800 seconds)


┌─────────────────────────────────────────────────────────────┐
│                    USER ACTION PHASE (setup)                 │
└─────────────────────────────────────────────────────────────┘

Before request is made:
  setup() handler called (blocking if async=false)
    - Calls get_models.choices(self, { async = false })
    - FORCES synchronous fetch with 3-second timeout
    - Blocks until models cached or timeout
    - This ensures model capabilities known before request


┌─────────────────────────────────────────────────────────────┐
│                  MODEL PICKER PHASE (GUI)                    │
└─────────────────────────────────────────────────────────────┘

get_adapter_models(adapter_name, use_dynamic)
  ↓
  Calls: adapter.schema.model.choices(adapter, { async = async_val })
    - async = use_dynamic ? false : true
    - Static: async=true  → returns cached (non-blocking, picker gets 1 model)
    - Dynamic: async=false → forces sync fetch (3s timeout, picker gets full list)
```

---

## 2. Key Files & Mechanisms

### A. `get_models.lua` - Core Fetching Logic

**Module-Level Caching Variables** (lines 19-23):
```lua
local _cached_models           -- Store fetched models
local _cached_adapter          -- Store adapter instance for async callback
local _cache_expires           -- Expiry timestamp (30 min default)
local _fetch_in_progress = false -- Prevent concurrent fetches
```

#### Function: `fetch_async(adapter, opts)` (lines 55-183)
**Purpose**: Non-blocking HTTP request to `/models` endpoint  
**Behavior**:
1. Check if cache still valid → return true (skip fetch)
2. Check if fetch already in progress → return true (wait for it)
3. Set `_fetch_in_progress = true`
4. Get Copilot token (non-forcing, skips if unavailable)
5. HTTP GET to: `{base_url}/models` with headers:
   - `Authorization: Bearer {copilot_token}`
   - `X-Github-Api-Version: 2025-10-01`
6. **Async callback** via `Curl.get()` with `vim.schedule_wrap()`:
   - Parse JSON response
   - Filter by `model.model_picker_enabled == true` and `chat` capability
   - Extract model capabilities (streaming, tools, vision, limits)
   - Store in `_cached_models`
   - Set cache expiry: `config.adapters.http.opts.cache_models_for` (default 1800s)
   - Set `_fetch_in_progress = false`

**Return**: `true` (fetch queued) or `false` (no token, cache expired)

#### Function: `fetch(adapter, opts)` (lines 189-202)
**Purpose**: Synchronous blocking fetch  
**Behavior**:
1. Call `fetch_async(adapter, opts)` to queue request
2. **BLOCK** with `vim.wait()` for up to 3 seconds (CONSTANTS.TIMEOUT)
3. Poll every 10ms (CONSTANTS.POLL_INTERVAL) for `get_cached_models() ~= nil`
4. Return cached models or timeout error

#### Function: `M.choices(adapter, opts)` (lines 208-220) **← KEY FUNCTION**
**Purpose**: Canonical interface for `schema.model.choices` implementations  
**Behavior**:
```lua
opts.async = opts.async ~= false -- Default to true
if opts.async == false then
  return fetch(adapter, opts)       -- SYNCHRONOUS: blocks 3s for HTTP
end
-- Non-blocking: start async fetch, return whatever is cached
fetch_async(adapter, { token = opts.token, force = false })
return get_cached_models()           -- May return nil on first call!
```

**CRITICAL**: When `async=true` (default):
- Queues HTTP request in background
- **Returns immediately** (cache may be empty = nil)
- Picker receives nil or cached models from previous session

---

### B. `copilot/init.lua` - Adapter & Schema Definition

#### Handler: `resolve()` (lines 119-136)
```lua
handlers = {
  resolve = function(self)
    if _fetching_models then return end  -- Prevent duplicate queues
    _fetching_models = true
    
    vim.schedule(function()
      pcall(function()
        -- Only fetch if cached token available
        local cached_token = token.fetch()
        if cached_token and cached_token.copilot_token then
          get_models.choices(self, { token = cached_token, async = true })  -- ASYNC!
        end
      end)
      _fetching_models = false
    end)
  end,
  ...
}
```

**Timing**: Called early, background fetch queued but returns immediately

#### Handler: `setup()` (lines 141-165)
```lua
setup = function(self)
  -- Ensure models are fetched SYNCHRONOUSLY before checking capabilities
  local fetched_token = token.fetch({ force = true })
  if fetched_token and fetched_token.copilot_token then
    -- FORCE synchronous model fetch
    get_models.choices(self, { token = fetched_token, async = false })
  end
  
  local model_opts = resolve_model_opts(self)
  
  -- Check streaming/tools/vision support AFTER models fetched
  if (self.opts and self.opts.stream) and (model_opts and model_opts.opts and model_opts.opts.can_stream) then
    self.parameters.stream = true
  else
    self.parameters.stream = nil
  end
  ...
end
```

**Timing**: Called just before request, forces sync fetch with 3s timeout

#### Schema: `model.choices()` (lines 366-376)
```lua
choices = function(self, opts)
  opts = opts or {}
  -- Force token for sync requests (user-initiated model selection)
  -- Don't force for async (background operations)
  local force = opts.async == false
  local fetched = token.fetch({ force = force })
  if not fetched or not fetched.copilot_token then
    return { ["gpt-4.1"] = { opts = {} } }  -- FALLBACK!
  end
  return get_models.choices(self, { token = fetched, async = opts.async })
end
```

**Fallback Behavior**: Returns only `gpt-4.1` if no token available

---

### C. `my_codecompanion_actions.lua` - User Interface Layer

#### Function: `get_adapter_models(adapter_name, use_dynamic)` (lines 397-427)
```lua
local function get_adapter_models(adapter_name, use_dynamic)
  local config = require "codecompanion.config"
  local adapter_config = config.adapters.http[adapter_name] or config.adapters.acp[adapter_name]
  if not adapter_config then
    return {}
  end
  local adapter = require("codecompanion.adapters").resolve(adapter_config)
  if not adapter or not adapter.schema or not adapter.schema.model then
    return {}
  end

  local models = adapter.schema.model.choices
  if type(models) == "function" then
    -- KEY DECISION POINT:
    -- async = use_dynamic ? false : true
    -- Static:  async=true  → non-blocking, returns immediately (1 model or cached)
    -- Dynamic: async=false → blocking, 3s timeout (full list on success)
    local async_val = use_dynamic and false or true
    models = models(adapter, { async = async_val, use_dynamic_fetch = use_dynamic or false })
  end

  -- Normalize hash to array for picker
  if type(models) == "table" and not vim.islist(models) then
    local keys = vim.tbl_keys(models)
    table.sort(keys)
    models = keys
  end

  return models or {}
end
```

**Line 413**: `local async_val = use_dynamic and false or true`
- `use_dynamic=false` (default) → `async=true` → returns 1 model immediately
- `use_dynamic=true` (dynamic mode) → `async=false` → blocks for full list

#### Picker Functions

**`toggle_inline_with_picker()`** (lines 431-468)
- Calls `get_adapter_models(adapter_name)` without use_dynamic flag
- **Shows only cached/fallback models** because async=true

**`toggle_inline_with_picker_dynamic()`** (lines 524-561)
- Calls `get_adapter_models(adapter_name, true)` with use_dynamic=true
- **Shows full model list** because async=false forces sync fetch

---

## 3. Why First Call Returns Only 1 Model

### Scenario: User opens model picker immediately after Neovim starts

1. **Adapter Resolution** (0ms)
   - `resolve()` handler queues async fetch via `vim.schedule()`
   - Returns immediately without fetching
   - `_cached_models = nil`

2. **User Opens Picker** (100ms, before HTTP completes)
   - Calls `get_adapter_models(adapter_name)` (default, not dynamic)
   - Calls `choices(adapter, { async = true })` ← **Non-blocking**
   - `M.choices()` calls `fetch_async(adapter, ...)` (queues 2nd fetch)
   - Returns `get_cached_models()` ← Still nil!
   - Falls back to `schema.model.choices()` return value
   - Schema returns `{ ["gpt-4.1"] = { opts = {} } }` fallback
   - Picker shows **1 model: gpt-4.1**

3. **HTTP Finally Completes** (3-5 seconds later)
   - Models cached in `_cached_models`
   - But picker already closed and user selected default

### Sequence Diagram
```
t=0ms   ┌─ Adapter Resolution
        │  resolve() queues async fetch
        │  _cached_models = nil
        │
t=100ms ├─ User Opens Picker
        │  get_adapter_models("copilot")
        │  choices(adapter, { async = true })
        │  fetch_async() queues HTTP request
        │  get_cached_models() returns nil
        │  Falls back to { ["gpt-4.1"] = {} }
        │  Picker shows 1 model
        │
t=3000ms└─ HTTP Completes
           _cached_models populated
           But picker already closed!
```

---

## 4. The `async` Parameter Behavior

### When `async = true` (Default for Static Mode)

**In `M.choices()`** (line 216-219):
```lua
-- Non-blocking: start async fetching and return whatever is cached
fetch_async(adapter, { token = opts.token, force = false })
return get_cached_models()  -- MAY BE NIL!
```

- Queues HTTP in background
- Returns **immediately** with cached models (or nil)
- Does NOT wait for HTTP response
- Used in model picker (static/default mode)

### When `async = false` (Explicit in Dynamic Mode or setup())

**In `M.choices()`** (line 212-214):
```lua
if opts.async == false then
  return fetch(adapter, opts)  -- SYNCHRONOUS
end
```

**In `fetch()`** (line 189-202):
```lua
local function fetch(adapter, opts)
  local _ = fetch_async(adapter, { token = opts.token, force = true })
  
  -- Block until models are cached or timeout
  local ok = vim.wait(CONSTANTS.TIMEOUT, function()
    return get_cached_models() ~= nil
  end, CONSTANTS.POLL_INTERVAL)
  
  if not ok then
    return log:error("Copilot Adapter: Timeout waiting for models")
  end
  
  return _cached_models  -- GUARANTEED non-nil (if HTTP succeeded)
end
```

- Calls `fetch_async()` with `force=true` (initializes token if needed)
- **BLOCKS** for up to 3 seconds
- Polls every 10ms for cached models
- Returns nil only on timeout
- Used in:
  - `setup()` before each request (ensure model capabilities known)
  - Dynamic picker (force full list)

---

## 5. Caching Mechanism

### Cache Variables

**File**: `get_models.lua` (module level)

```lua
local _cached_models           -- Table of { [model_id]: { opts = {}, ... } }
local _cached_adapter          -- Reference to adapter for async callback
local _cache_expires           -- os.time() + seconds
local _fetch_in_progress       -- Flag to prevent concurrent fetches
```

### Cache Expiry (30 minutes)

**In `fetch_async()` callback** (line 171):
```lua
_cached_models = models
set_cache_expiry(config.adapters.http.opts.cache_models_for)
```

**In `set_cache_expiry()`** (lines 34-38):
```lua
local function set_cache_expiry(seconds)
  seconds = seconds or 1800  -- DEFAULT: 30 minutes
  _cache_expires = os.time() + seconds
  return _cache_expires
end
```

**In `get_cached_models()`** (lines 42-49):
```lua
local function get_cached_models()
  if _cached_models and _cache_expires and _cache_expires > os.time() then
    log:trace("Copilot Adapter: Using cached Copilot models")
    return _cached_models
  end
  return nil  -- Cache expired
end
```

### Cache Reset

**In `on_exit()` handler** (line 352):
```lua
on_exit = function(self, data)
  get_models.reset_cache()  -- Called after each request completes
  return handlers(self).on_exit(self, data)
end
```

**In `M.reset_cache()`** (lines 27-29):
```lua
function M.reset_cache()
  _cached_adapter = nil
end
```

**Note**: Only resets `_cached_adapter`, NOT `_cached_models` or `_cache_expires`. The 30-minute TTL still applies.

---

## 6. Token Fetching

### Token Module: `token.lua`

**Module Variables** (lines 34-41):
```lua
M._oauth_token = nil           -- GitHub OAuth token from environment/config
M._copilot_token = nil         -- Copilot-specific token
local _token_fetch_in_progress = false
local _token_wait_timeout = 5000  -- 5 seconds
local _token_wait_interval = 50   -- 50ms poll interval
```

### Function: `token.fetch(opts)`

**Signature**: `function M.fetch(opts)`

**Parameters**:
- `opts.force` (boolean): If true, reinitialize token from disk/env even if cached

**Behavior**:
1. Check `_copilot_token` cache (return if valid)
2. If not forced, return cached token
3. If forced or not cached:
   - Read OAuth token from `GITHUB_TOKEN` env or `github-copilot/hosts.json`
   - HTTP GET to GitHub OAuth endpoint for Copilot-specific token
   - Cache in `_copilot_token`
   - Return token object

**Used in**:
- `get_models.fetch_async()` (line 71): `token.fetch({ force = opts.force })`
  - force=true → reinitialize token
  - force=false → use cached token
- `schema.model.choices()` (line 371): `token.fetch({ force = opts.async == false })`
  - async=false → force token init
  - async=true → use cached token

---

## 7. Complete Request Flow: From UI to Response

### Scenario: User clicks "Inline Edit" button in visual mode

```
1. m.toggle_inline_with_picker() called (user clicks key)
   ↓
2. preserve visual context before picker opens
   ↓
3. get_available_adapters() → ["copilot", "openai_agd", ...]
   ↓
4. vim.ui.select(adapters) → user selects "copilot"
   ↓
5. get_adapter_models("copilot") called
   │  ├─ require("codecompanion.adapters").resolve(adapter_config)
   │  ├─ adapter.schema.model.choices(adapter, { async = true })
   │  │  └─ M.choices() in get_models.lua
   │  │     ├─ fetch_async() queues HTTP (non-blocking)
   │  │     └─ return get_cached_models() → may be nil!
   │  ├─ normalize { ["gpt-4.1"] = {} } to ["gpt-4.1"]
   │  └─ return ["gpt-4.1"]
   ↓
6. vim.ui.select(models) → shows 1 model: gpt-4.1
   ↓
7. user selects gpt-4.1 (only option)
   ↓
8. M.inline_with_adapter("copilot", "gpt-4.1", preserved_context)
   ├─ resolve adapter instance
   ├─ set adapter.schema.model.default = "gpt-4.1"
   ├─ prompt for user input
   ├─ create inline_interaction instance
   └─ inline:prompt(input)
```

### Scenario: User clicks "Dynamic" picker (with async=false)

```
1-4. [Same as above]
   ↓
5. get_adapter_models("copilot", true) called  ← use_dynamic = true
   │  ├─ adapter.schema.model.choices(adapter, { async = false })
   │  │  └─ M.choices() in get_models.lua
   │  │     ├─ fetch() called (SYNCHRONOUS)
   │  │     │  ├─ fetch_async() queues HTTP
   │  │     │  ├─ vim.wait(3000) blocks for models
   │  │     │  └─ return _cached_models (may timeout)
   │  │     └─ return _cached_models or error
   │  ├─ normalize { ["gpt-4"] = {}, ["gpt-5"] = {}, ... } to ["gpt-4", "gpt-5", ...]
   │  └─ return ["gpt-4", "gpt-5", "o1", ...]
   ↓
6. vim.ui.select(models) → shows 10+ models
   ↓
7. user selects model (many options)
```

---

## 8. Async vs Sync Decision Points

| Context | Function Call | async | Result | Use Case |
|---------|---------------|-------|--------|----------|
| Picker (static) | `get_adapter_models(adapter)` | true | Immediate, 1-3 models | Default quick picker |
| Picker (dynamic) | `get_adapter_models(adapter, true)` | false | Wait 3s, full list | Full model browser |
| Before request | `setup()` handler | false | Wait 3s | Ensure capabilities known |
| Background init | `resolve()` handler | true | Immediate | Early queuing |
| Schema fallback | `choices()` direct | null | Depends on caller | Direct adapter usage |

---

## 9. Recommendations for Warming the Cache

### Problem
First model picker shows only 1 model because async fetch hasn't completed yet.

### Solutions

**Option 1: Warm Cache on Startup** (Simple)
- Add to init.lua or plugin config:
```lua
-- Pre-warm the Copilot models cache on startup
vim.schedule(function()
  local config = require "codecompanion.config"
  local adapter_config = config.adapters.http.copilot
  if adapter_config then
    local adapter = require("codecompanion.adapters").resolve(adapter_config)
    if adapter and adapter.schema and adapter.schema.model then
      local get_models = require "codecompanion.adapters.http.copilot.get_models"
      -- Warm cache with async=false on startup (blocking 3s once)
      get_models.choices(adapter, { async = false })
    end
  end
end)
```

- Trade-off: 3-second startup delay (one-time)
- Benefit: All pickers show full list immediately

**Option 2: Persist Cache to Disk** (Complex)
- Serialize `_cached_models` to JSON file on startup
- Load from disk in `get_cached_models()` if within TTL
- Benefit: Zero startup delay, cached models from previous session
- Trade-off: Need to handle disk I/O, cache invalidation

**Option 3: Use Dynamic Picker by Default** (Behavioral)
- Recommend users use `<leader>ASm` (dynamic picker) instead of `<leader>Asm`
- Dynamic picker forces async=false, blocking for full list
- Benefit: Explicit user action (picker) tolerates 3s wait
- Trade-off: Users must choose dynamic picker consciously

**Option 4: Make Static Picker Async-Aware** (UX)
- Detect if async fetch is still in progress
- Show loading indicator + partial models
- Debounce picker refresh when models arrive
- Benefit: Progressive loading UX
- Trade-off: Complex UI logic

---

## 10. Key Takeaways

1. **Fallback Model**: `gpt-4.1` is the hardcoded default when no token available (init.lua line 364)

2. **Async vs Sync**:
   - `async=true` (default): Non-blocking, returns immediately
   - `async=false`: Blocking, up to 3-second timeout

3. **Caching**: 30-minute TTL stored in module variables `_cached_models` and `_cache_expires`

4. **Two Fetch Phases**:
   - `resolve()` handler: Early async queue (background)
   - `setup()` handler: Pre-request sync fetch (ensures capabilities)

5. **Why 1 Model on First Call**:
   - Async fetch queued but not awaited
   - Picker gets fallback `gpt-4.1` immediately
   - Full list arrives after picker closed

6. **Model Filter Logic**: 
   - Only includes models with `model_picker_enabled=true`
   - Only includes `chat` capability types
   - Extracts streaming/tools/vision support from capabilities

7. **Token Strategy**:
   - Cached per session (until Neovim restart)
   - `force=true` reinitializes from disk/env
   - Async fetch uses `force=false` to avoid blocking
   - Sync fetch uses `force=true` to ensure token available

---

## 11. Code Reference Map

| Component | File | Lines | Purpose |
|-----------|------|-------|---------|
| Cache vars | `get_models.lua` | 19-23 | Module-level cache state |
| fetch_async | `get_models.lua` | 55-183 | Async HTTP to /models |
| fetch | `get_models.lua` | 189-202 | Sync wrapper with 3s timeout |
| M.choices | `get_models.lua` | 208-220 | Entry point: async vs sync decision |
| resolve | `init.lua` | 119-136 | Background fetch queue |
| setup | `init.lua` | 141-165 | Pre-request sync fetch |
| schema.choices | `init.lua` | 366-376 | Schema callback + fallback |
| get_adapter_models | `my_codecompanion_actions.lua` | 397-427 | Picker integration |
| get_available_adapters | `my_codecompanion_actions.lua` | 385-393 | Adapter list |
| Picker functions | `my_codecompanion_actions.lua` | 431-561 | UI integration (static & dynamic) |

---

**Document Version**: 2026-03-31  
**Last Verified**: CodeCompanion v19.6.0  
**Research Scope**: Read-only analysis only
