-- Attach-mode adapters for mcphub.nvim.
-- Apply whenever MCP_HUB_MODE resolves to attach (remote/tunneled hub), not a host fingerprint.
--
-- 1. Remote hubs report config_source paths from *their* machine. If that path is not
--    readable here, read MCPHUB_CONFIG instead of mkdir-ing foreign prefixes.
-- 2. SSE curl 56 is common on tunneled attach; retry before marking Stopped.

local backend = require "utils.mcphub_backend"

local M = {}

function M.local_config_path()
  return backend.config_path()
end

function M.remap_config_path(path)
  if not path or path == "" then
    return path
  end
  if vim.fn.filereadable(path) == 1 then
    return path
  end
  local local_cfg = M.local_config_path()
  if local_cfg ~= "" and vim.fn.filereadable(local_cfg) == 1 then
    return local_cfg
  end
  return path
end

function M.rewrite_server_config_sources(servers)
  if not servers then
    return
  end
  for _, server in ipairs(servers) do
    if server.config_source then
      server.config_source = M.remap_config_path(server.config_source)
    end
  end
end

function M.install()
  local mode = backend.mode()
  if mode ~= "attach" then
    return
  end

  local local_cfg = M.local_config_path()
  if vim.fn.filereadable(local_cfg) ~= 1 then
    vim.notify("mcphub attach: missing config " .. local_cfg, vim.log.levels.WARN)
    return
  end

  local config_manager = require "mcphub.utils.config_manager"
  local State = require "mcphub.state"

  local orig_load = config_manager.load_config
  config_manager.load_config = function(file_path)
    local local_path = M.remap_config_path(file_path)
    local success, err = orig_load(local_path)

    -- get_server_config indexes State.config_files_cache by the path supplied by
    -- the remote hub, rather than by get_config_source(). Keep that remote key
    -- as an alias of the local config after loading it.
    if success and file_path ~= local_path and State.config_files_cache then
      State.config_files_cache[file_path] = State.config_files_cache[local_path]
    end

    return success, err
  end

  local orig_get_source = config_manager.get_config_source
  config_manager.get_config_source = function(server)
    return M.remap_config_path(orig_get_source(server))
  end

  local orig_get_active = config_manager.get_active_config_files
  config_manager.get_active_config_files = function(reverse)
    if State.config and State.config.server_url and State.config.server_url ~= "" then
      local files = { local_cfg }
      if reverse then
        return vim.fn.reverse(vim.deepcopy(files))
      end
      return files
    end
    local files = orig_get_active(reverse) or {}
    for i, path in ipairs(files) do
      files[i] = M.remap_config_path(path)
    end
    return files
  end

  local orig_notify = State.notify_subscribers
  State.notify_subscribers = function(self, changes, update_type)
    if self.server_state and self.server_state.servers then
      M.rewrite_server_config_sources(self.server_state.servers)
    end
    return orig_notify(self, changes, update_type)
  end

  orig_load(local_cfg)
  M.install_sse_recovery()
end

function M.install_sse_recovery()
  local ok, Hub = pcall(require, "mcphub.hub")
  if not ok or not Hub._attempt_sse_recovery then
    return
  end
  if Hub._attach_sse_recovery_patched then
    return
  end
  Hub._attach_sse_recovery_patched = true

  local orig = Hub._attempt_sse_recovery
  function Hub:_attempt_sse_recovery(exit_code)
    self._attach_sse_recovery_attempts = (self._attach_sse_recovery_attempts or 0) + 1
    local max_attempts = 6
    local delay_ms = 5000

    local function probe()
      if self.is_shutting_down then
        return
      end
      local was_ready = self.ready
      self.ready = false
      self:check_server(function(is_running, is_our_server)
        if is_running and is_our_server then
          self.ready = was_ready
          self._attach_sse_recovery_attempts = 0
          if not self.sse_job then
            self:connect_sse()
          end
          return
        end
        if exit_code == 56 and self._attach_sse_recovery_attempts < max_attempts then
          vim.defer_fn(probe, delay_ms)
          return
        end
        self._attach_sse_recovery_attempts = 0
        orig(self, exit_code)
      end)
    end
    probe()
  end
end

return M
