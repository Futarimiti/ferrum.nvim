local Commands = { Buflocal = require 'ferrum.commands.buflocal' }

local Buffer = {}

-- If the given buffer is a client, unlink it and clear any buflocal commands
---@param buf integer client buffer
---@param _? boolean no effect; for backwards compatibility
---@param tolerate? boolean tolerate invalid buffer?
Buffer.free = function(buf, _, tolerate)
  if not vim.api.nvim_buf_is_valid(buf) then
    if tolerate then
      return
    else
      error(('invalid buffer: %d'):format(buf))
    end
  end

  -- 1. cleanup buflocal commands
  Commands.Buflocal.cleanup(buf)

  -- 2. set b:ferrum_job to nil
  vim.b[buf].ferrum_job = nil
end

-- Like `vim.bo[buf].channel` but with explicit nil returns.
---@param buf integer
---@return integer?
Buffer.get_job = function(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    error(('invalid buffer: %d'):format(buf))
  end
  local chan = vim.bo[buf].channel
  if chan ~= 0 then return chan end
end

---@param buf integer
---@return boolean
Buffer.is_terminal = function(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    error(('invalid buffer: %d'):format(buf))
  end
  return vim.bo[buf].buftype == 'terminal'
end

return Buffer
