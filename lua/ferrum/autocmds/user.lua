-- User commands
local M = {}

---@param user_event string|string[]
---@param data? any
local doautocmd = function(user_event, data)
  vim.api.nvim_exec_autocmds('User', {
    pattern = user_event,
    data = data,
  })
end

-- Usage:
-- ```
-- local Autocmds = require('ferrum.autocmds.user')
-- Autocmds.fire['FerrumBuflocalCommandsSetupPre']()
-- ```
M.fire = {}

---@param o ferrum.autocmds.user.args
M.fire.FerrumBuflocalCommandsSetupPre = function(o)
  doautocmd('FerrumBuflocalCommandsSetupPre', o)
end

---@param o ferrum.autocmds.user.args
M.fire.FerrumBuflocalCommandsSetupPost = function(o)
  doautocmd('FerrumBuflocalCommandsSetupPost', o)
end

---@param o {buf:integer}
M.fire.FerrumBuflocalCommandsCleanupPre = function(o)
  doautocmd('FerrumBuflocalCommandsCleanupPre', o)
end

---@param o {buf:integer}
M.fire.FerrumBuflocalCommandsCleanupPost = function(o)
  doautocmd('FerrumBuflocalCommandsCleanupPost', o)
end

---@param o ferrum.autocmds.user.args
M.fire.FerrumLinkREPLPre = function(o) doautocmd('FerrumLinkREPLPre', o) end

---@param o ferrum.autocmds.user.args
M.fire.FerrumLinkREPLPost = function(o) doautocmd('FerrumLinkREPLPost', o) end

-- After user successfully spawn a session with ferrum
---@param o ferrum.autocmds.user.args
M.fire.FerrumSpawnREPLPost = function(o) doautocmd('FerrumSpawnREPLPost', o) end

---@param o ferrum.autocmds.user.args
M.fire.FerrumFinishREPLPost = function(o) doautocmd('FerrumFinishREPLPost', o) end

return M

---@alias ferrum.autocmds.user.args { client: integer, repl: integer, job: integer, cmd: string[] }
