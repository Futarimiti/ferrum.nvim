local Commands = { Buflocal = require 'ferrum.commands.buflocal' }

local Buffer = {}

-- If the given buffer is a client, unlink it and clear any buflocal commands
---@param buf integer client buffer
---@param say_something? boolean should be self explaining
---@param tolerate? boolean tolerate invalid buffer?
---@param target_job? integer only free the buffer if it's linking to this job
Buffer.free = function(buf, say_something, tolerate, target_job)
  if not vim.api.nvim_buf_is_valid(buf) then
    if tolerate then
      return
    else
      error(('invalid buffer: %d'):format(buf))
    end
  end

  ---@type integer?
  local old_job = vim.b[buf].ferrum_job
  if target_job ~= nil and target_job ~= old_job then
    -- not this job; do nothing
    return
  end

  -- 1. set b:ferrum_job to nil
  if old_job ~= nil then
    vim.b[buf].ferrum_job = nil
    if say_something then
      vim.notify(('Unlinked job #%d'):format(old_job), vim.log.levels.INFO)
    end
  end

  -- 2. cleanup buflocal commands
  Commands.Buflocal.cleanup(buf)
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
