-- A huge global variable storing info about each job.

-- Record for each job
---@type Jobs
local jobs = {}

local Jobs = {}

-- List all active terminal jobs that are connected to a buffer.
---@return table<integer,{cmd:string,buf:integer}> table mapping job id to info
---@deprecated Leave it for now
Jobs.all = function()
  return vim.iter(vim.api.nvim_list_chans()):fold({}, function(acc, chaninfo)
    if
      chaninfo.buffer ~= nil and chaninfo.pty ~= '' -- pty empty when job done
    then
      acc[chaninfo.id] = {
        buf = chaninfo.buffer,
        -- argv got to be non-nil right? ...right?
        cmd = chaninfo.argv and chaninfo.argv[#chaninfo.argv] or '--No cmd--',
      }
    end
    return acc
  end)
end

--- DEPRECATED

-- Allow any arbitrary mutation on jobs db.
-- If the given function returns anything, return it.
---@generic T
---@param f fun(_:Jobs): T
---@return T
---@deprecated
Jobs.mut = function(f) return f(jobs) end

---@param job integer
---@return JobRecord?
---@deprecated
Jobs.get = function(job) return Jobs.all()[job] end

---@param job integer
---@param record JobRecord
---@deprecated
Jobs.set = function(job, record)
  Jobs.mut(function(jobs_)
    jobs_[job] = record
    return nil
  end)
end

---@param job integer
---@deprecated
Jobs.del = function(job)
  ---@diagnostic disable-next-line: param-type-mismatch
  Jobs.set(job, nil)
end

-- Make {client} a client of {job}
---@param job integer
---@param client integer
---@deprecated
Jobs.link = function(job, client) table.insert(jobs[job].clients, client) end

-- Make {client} no longer a client of {job}
---@param job integer
---@param client integer
---@deprecated
Jobs.unlink = function(job, client)
  local clients = jobs[job].clients
  jobs[job].clients = vim
    .iter(clients)
    :filter(function(c) return c ~= client end)
    :totable()
end

return Jobs

---@class JobRecord
---@field clients integer[] client buffers
---@field repl integer REPL buffer
---@field cmd string[] REPL command

---@alias Jobs table<integer,JobRecord>
