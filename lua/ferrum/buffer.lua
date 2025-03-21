local Jobs = require 'ferrum.jobs'
local Commands = { Buflocal = require 'ferrum.commands.buflocal' }

local Buffer = {}

-- If the given buffer is a client, unlink it and clear any buflocal commands
---@param buf integer client buffer
---@param notify? boolean say something
---@param tolerate? boolean tolerate invalid buffer?
Buffer.free = function(buf, notify, tolerate)
  if not vim.api.nvim_buf_is_valid(buf) then
    if tolerate then
      return
    else
      error(('invalid buffer: %d'):format(buf))
    end
  end

  -- 1. cleanup buflocal commands
  Commands.Buflocal.cleanup(buf)

  local old_job = vim.b[buf].ferrum_job
  if old_job ~= nil then
    local maybe_job_record = Jobs.get(old_job)
    if maybe_job_record ~= nil then
      -- 2. unlink jobs in job DB
      Jobs.unlink(old_job, buf)
      if notify then
        vim.notify(
          ('Unlinked job #%d (!%s)'):format(
            old_job,
            vim.fn.join(maybe_job_record.cmd, ' ')
          ),
          vim.log.levels.INFO
        )
      end
    end
    -- 3. set b:ferrum_job to nil
    vim.b[buf].ferrum_job = nil
  end
end

return Buffer
