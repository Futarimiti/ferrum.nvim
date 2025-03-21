-- A huge global variable storing info about each job.

-- Record for each job
---@type Jobs
local jobs = {}

local Jobs = {}

-- Allow any arbitrary mutation on jobs db.
-- If the given function returns anything, return it.
---@generic T
---@param f fun(_:Jobs): T
---@return T
Jobs.mut = function(f) return f(jobs) end

---@return Jobs
Jobs.all = function()
  return Jobs.mut(function(jobs_) return jobs_ end)
end

---@param job integer
---@return JobRecord?
Jobs.get = function(job) return Jobs.all()[job] end

---@param job integer
---@param record JobRecord
Jobs.set = function(job, record)
  Jobs.mut(function(jobs_)
    jobs_[job] = record
    return nil
  end)
end

---@param job integer
Jobs.del = function(job)
  ---@diagnostic disable-next-line: param-type-mismatch
  Jobs.set(job, nil)
end

-- Make {client} a client of {job}
---@param job integer
---@param client integer
Jobs.link = function(job, client) table.insert(jobs[job].clients, client) end

-- Make {client} no longer a client of {job}
---@param job integer
---@param client integer
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
