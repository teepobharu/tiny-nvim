# CodeCompanion Proxy Debugging Guide

## Overview
This guide will help you set up mitmproxy to intercept and inspect HTTP/HTTPS traffic between CodeCompanion and your LLM provider.

## Prerequisites
- Install mitmproxy: `brew install mitmproxy` (macOS) or `pip install mitmproxy`

## Step 1: Start mitmproxy

Open a terminal and run:
````bash
mitmproxy --listen-port 8080 --set block_global=false
````

Or for a web interface:
````bash
mitmweb --listen-port 8080 --set block_global=false
````

mitmproxy will:
- Listen on `http://127.0.0.1:8080`
- Show all intercepted requests in the terminal (mitmproxy) or browser (mitmweb at http://127.0.0.1:8081)

## Step 2: Configure CodeCompanion to Use the Proxy

Add this to your Neovim configuration (e.g., `~/.config/nvim/lua/plugins/codecompanion.lua`):

````lua
require("codecompanion").setup({
  adapters = {
    http = {
      opts = {
        proxy = "http://127.0.0.1:8080",  -- Route traffic through mitmproxy
        allow_insecure = true,             -- Required to accept mitmproxy's certificate
      },
    },
    -- Your other adapter configurations...
  },
})
````

**Important:** The `allow_insecure = true` setting allows curl to accept mitmproxy's self-signed certificate.

## Step 3: Alternative - Use Environment Variable

Instead of hardcoding in config, you can set the proxy via environment variable:

````bash
export HTTP_PROXY="http://127.0.0.1:8080"
export HTTPS_PROXY="http://127.0.0.1:8080"
nvim
````

Then in your config:
````lua
require("codecompanion").setup({
  adapters = {
    http = {
      opts = {
        proxy = os.getenv("HTTP_PROXY"),
        allow_insecure = true,
      },
    },
  },
})
````

## Step 4: Debug Your Configuration

### Check What's Being Sent

1. Start mitmproxy: `mitmproxy --listen-port 8080`
2. Open Neovim with CodeCompanion
3. Trigger a request (e.g., open a chat, send a message)
4. In mitmproxy, you'll see:
   - Request URL (verify it's correct)
   - Request headers (check API keys, auth tokens)
   - Request body (verify model name, parameters)
   - Response status (200, 401, 404, etc.)
   - Response body (error messages)

### Common Issues to Check

**Issue: No requests appear in mitmproxy**
- Verify proxy setting: `:lua print(vim.inspect(require("codecompanion.config").adapters.http.opts.proxy))`
- Check if adapter is using a custom request function
- Ensure `allow_insecure = true` is set

**Issue: Certificate errors**
- Set `allow_insecure = true` in config
- Or install mitmproxy CA certificate: https://docs.mitmproxy.org/stable/concepts-certificates/

**Issue: Wrong model name**
- Check the request body in mitmproxy
- Verify `schema.model.default` in your adapter

**Issue: Wrong API endpoint**
- Check the URL in mitmproxy requests
- Verify `env.url` and `env.chat_url` in adapter config

## Step 5: Inspect Specific Adapter Configuration

### Check OpenAI Compatible Adapter

Add this to your config and inspect in mitmproxy:

````lua
require("codecompanion").setup({
  adapters = {
    http = {
      openai_compatible = {
        env = {
          api_key = "OPENAI_API_KEY",           -- Your env var name
          url = "http://localhost:11434",       -- Your server URL
          chat_url = "/v1/chat/completions",    -- Chat endpoint
          models_endpoint = "/v1/models",       -- Models endpoint
        },
      },
      opts = {
        proxy = "http://127.0.0.1:8080",
        allow_insecure = true,
      },
    },
  },
  interactions = {
    chat = {
      adapter = "openai_compatible",  -- Use your adapter
    },
  },
})
````

### Check Environment Variable Resolution

Run this in Neovim to verify your env vars are being read:

````vim
:lua print(vim.inspect(vim.fn.getenv("OPENAI_API_KEY")))
:lua print(vim.inspect(require("codecompanion.config").adapters.http.openai_compatible.env))
````

## Step 6: Advanced Debugging

### Enable CodeCompanion Debug Logging

````lua
require("codecompanion").setup({
  opts = {
    log_level = "DEBUG",  -- TRACE|DEBUG|ERROR|INFO
  },
})
````

Then check the log file:
````bash
tail -f ~/.local/state/nvim/codecompanion.log
````

### Inspect Request Body Files

CodeCompanion saves request bodies to temp files. Check the log for lines like:
```
Request body file: /tmp/nvim.username/XXXXXX.json
```

View the file:
````bash
cat /tmp/nvim.username/XXXXXX.json | jq .
````

## Step 7: Testing Connectivity

### Test Direct Connection (Without Proxy)

````bash
# Test if your server is reachable
curl http://localhost:11434/v1/models

# Test with API key
curl -H "Authorization: Bearer your-api-key" \
     http://localhost:11434/v1/models
````

### Test Through Proxy

````bash
# Test with proxy
curl --proxy http://127.0.0.1:8080 \
     -H "Authorization: Bearer your-api-key" \
     http://localhost:11434/v1/models
````

## Troubleshooting Checklist

- [ ] mitmproxy is running on port 8080
- [ ] `proxy = "http://127.0.0.1:8080"` is set in config
- [ ] `allow_insecure = true` is set
- [ ] API key environment variable is exported
- [ ] Server URL is correct in adapter config
- [ ] Requests appear in mitmproxy
- [ ] Request URL matches expected endpoint
- [ ] Request headers include authorization
- [ ] Response status is 200 (or note the error code)

## Example mitmproxy Output

When working correctly, you should see requests like:

```
→ POST http://localhost:11434/v1/chat/completions
  ← 200 application/json 2.3k

Request Headers:
  Content-Type: application/json
  Authorization: Bearer sk-...

Request Body:
  {
    "model": "llama2",
    "messages": [...],
    "stream": true
  }
```

## Next Steps

Once you can see requests in mitmproxy:
1. Verify the request URL is correct
2. Check the model name in the request body
3. Verify API key is being sent
4. Check response status codes and error messages
5. Compare with working curl commands

## Cleanup

When done debugging, remove the proxy setting:

````lua
require("codecompanion").setup({
  adapters = {
    http = {
      opts = {
        proxy = nil,              -- Remove proxy
        allow_insecure = false,   -- Restore security
      },
    },
  },
})
````
