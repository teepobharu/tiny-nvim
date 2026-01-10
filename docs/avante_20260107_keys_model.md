## References

- https://deepwiki.com/search/can-inline-chat-be-configure-t_6c87bca5-1c57-4d88-bb36-526af7632f5e?mode=fast

## 0. refactor model config to be in new file - Done

../lua/utils/my_avante_utils.lua
- refactor *_agd config into external utils file setting and import to be used in initial config - import and use in myeditor file

## 1. Avante: Key Mappings to Select Different Models
-- In your config (e.g., init.lua)  
local function ask_with_provider(provider, model)  
  -- Temporarily override the provider configuration  
  require('avante.config').override({  
    provider = provider,  
    providers = {  
      [provider] = {  
        model = model,  
      },  
    },  
  })  
    
  -- Call ask with the overridden configuration  
  require('avante.api').ask()  
end  
  
-- Normal map
<leader>rm -> select model with lean provider (without custom agd models)
<leader>rM -> select model with all providers (with custom agd models)

-- Map keys visual mode  , x mode
prefix key = <leader>rs = select ask / select model from copilot provider

prefix+f (mnemonic: fast)
ask_with_provider('copilot', 'gpt-4.1-mini')  
prefix+F (mnemonic: fast-2)
ask_with_provider('copilot', 'gpt-5-mini')  

prefix+h (mnemonic: heavy)
ask_with_provider('copilot', 'claude-sonnet-4-5')
prefix+H
ask_with_provider('copilot', 'claude-opus-4-5')

prefix+c (mnemonic: codex)
ask_with_provider('copilot', 'gpt-5.1-codex-max')
prefix+C
ask_with_provider('copilot', 'gpt-5.1-codex-mini')

prefix key = <leader>rS = select agd / select model~ from custom agd source 

Use the same prefix mapping from above but make sure the model_names and sources are from agd custom models.

-- Map in normal map with these prefix select the model (without asking but notification Snacks.notify.warn("... switch message to model"))
prefix key = <leader>rs and <leader>rS 



## 2. Avante: Key Mappings to Select Models Remove agd specific providers 
- then add utility fns to remove those providers (to speed up AvanteModels selection)
- map the key to choose lean providers config
- remap <leader>rM key to choose with added providers config (if not exist else just run :AvanteModels)


## 3. Avante Fix sources
Claude does not seem to work with agd source properly - need to fix the source mapping for claude models in agd source

Sample error source 1

```text
- Datetime: 2026-01-07 21:26:40
- Model:    claude_agd/claude-3-7-sonnet
- Selected files:
  - /Users/tharutaipree/Personal/mynotes/study/Programming/algorithms/agoda_interview/code_signals/hackerrank/easy/printbook.ts

> hi


Error: API request failed with status 401. Body: 'Failed to maybeAuthenticate with headers: host: [genai-gateway.agoda.is], user-agent: [curl/8.7.1], accept: [*/*], accept-encoding: [deflate, gzip], x-api-key: [eyJraWQ
```

Sample error source 2
```text
Model:    vertex_vclaude_2/claude-3-7-sonnet
- Selected files:
  - /Users/tharutaipree/Personal/mynotes/study/Programming/algorithms/agoda_interview/code_signals/hackerrank/easy/printbook.ts

> hi

Error: API request failed with status 401. Body: 'Failed to maybeAuthenticate with headers: host: [genai-gateway.agoda.is],
```
