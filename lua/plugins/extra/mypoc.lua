return {
  {
    -- Test workspace,
    -- -- result = cant swtich to open new profile on the run
    -- workspace will still inherit global tools
    -- TRIED:
    -- - toggle workspace also toggle off global, cant override project json : false
    -- - if we toggle off global will it affect  - yes
    -- - ✅ can override disable tools by input any command ie echo 123 (and toggle disabled true) will not inherit this tool
    -- TODO:
    -- if needed run on the fly| enable new port toggle
    -- can reuse internal code the internal coed workspace ?
    -- show in UI but require workspace to enable hub switch
    -- mcp-hub --port 47474 --config ~/dotfiles/ai/mcp/mcphub.json --config ./.mcphub/project.json
    -- extra server will also show in UI and can change dir with gc key
    -- mcp-hub --port 47474 --config ~/dotfiles/ai/mcp/mcphub.json --config ./.mcphub/project.json
    "ravitemer/mcphub.nvim",
    -- workspace = {
    --   -- enabled = false,
    --   enabled = true,
    --   look_for = { "~/dotfiles/ai/mcp/mcphub.json", ".mcphub/servers.json", ".vscode/mcp.json", ".cursor/mcp.json" }, -- Files to look for when detecting project boundaries (VS Code format supported)
    --   -- look_for = { "~/dotfiles/ai/mcp/mcphub.json", ".mcphub/servers.json", ".vscode/mcp.json", ".cursor/mcp.json" }, -- Files to look for when detecting project boundaries (VS Code format supported)
    --   reload_on_dir_changed = true, -- Automatically switch hubs on DirChanged event
    -- },
    overrideFn = function(PORT)
      -- check if port is already used
      -- testconf ai/mcp/mcphub.json 1:1
      PORT = 47474
      -- local lsof_output = vim.fn.systemlist("lsof -i :" .. PORT)
      -- if #lsof_output > 1 then -- lsof outputs at least a header line if something is found
      --   print("Port " .. PORT .. " is already in use.")
      --   -- prompt to kill process using the port
      --   local answer = vim.fn.input("Kill process using port " .. PORT .. "? (y/n): ")
      --   if answer:lower() == "y" then
      --     local pid_list = vim.fn.systemlist("lsof -t -i :" .. PORT)
      --     if #pid_list > 0 and pid_list[1] ~= "" then
      --       vim.fn.system("kill -9 " .. pid_list[1])
      --       print("Killed process " .. pid_list[1] .. " using port " .. PORT)
      --     else
      --       print("No PID found to kill on port " .. PORT)
      --     end
      --   end
      -- end
      -- @lua/plugins/extra/mypoc.lua L38:C14-L40:C2147483647
      require("mcphub").setup {
        config = vim.fn.expand "~/dotfiles/ai/mcp/mcphub.json",
        port = 47474,
        mcp_request_timeout = 10000, --Max time allowed for a MCP tool or resource to execute in milliseconds, set longer for long running tasks
        workspace = {
          enabled = true,
          look_for = { ".mcphub/servers.json", ".vscode/mcp.json", ".cursor/mcp.json" }, -- Files to look for when detecting project boundaries (VS Code format supported)
          reload_on_dir_changed = true, -- Automatically switch hubs on DirChanged event
          port_range = { min = 40000, max = 41000 }, -- Port range for generating unique workspace ports
          get_port = function()
            return PORT
          end, -- Optional function returning custom port number. Called when generating ports to allow custom port assignment logic
        },
      }
      vim.print "DONE"
    end,
    on_ready = function(hub)
      vim.print("MCPHub is ready on port " .. hub.port)
    end,
    on_error = function(err)
      -- Called on errors
    end,
  },
}
