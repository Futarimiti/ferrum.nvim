local Jobs = require 'ferrum.jobs'
local Util = require 'ferrum.util'
local safe = Util.safe
local echoerr = Util.echoerr
local Buffer = require 'ferrum.buffer'
local Repl = require 'ferrum.core'

local Commands = {}

Commands.Buflocal = require 'ferrum.commands.buflocal'

-- Spawn a REPL session in a new split, relative to source win.
---@param source_win integer
---@param mods string `<mods>`; modifiers for opening the new window
---@param cmd string[]
---@param focus boolean focus in the new split?
---@param on_exit fun(job:integer,exitcode:integer,event:string)
---@return integer job
---@return integer repl buffer
local spawn_repl_session = function(source_win, mods, cmd, focus, on_exit)
  vim.cmd(mods .. ' new') -- XXX
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  local ok, job = safe(Repl.spawn, win, cmd, on_exit)
  if not ok then
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.api.nvim_set_current_win(source_win)

    ---@type string
    local msg = job
    error(msg)
  end

  if focus then
    vim.cmd.startinsert()
  else
    ---@diagnostic disable-next-line: param-type-mismatch
    vim.fn.cursor('$', 0)
    vim.api.nvim_set_current_win(source_win) -- jump back
  end

  ---@cast job integer
  return job, buf
end

-- Determine which shell command to run.
---@param o vim.api.keyset.create_user_command.command_args
---@param buf integer client buffer
---@return string[] shell cmd
local get_cmd = function(o, buf)
  if not vim.tbl_isempty(o.fargs) then return o.fargs end
  local var = 'ferrum' -- b:ferrum
  local bvar = vim.b[buf][var]
  if bvar == nil then
    local ret = vim.split(
      vim.fn.input('> ', '', 'shellcmdline'),
      '%s+',
      { trimempty = true }
    )
    print '' -- flush input line
    return ret
  else
    -- expand special keywords like % before use

    ---@type string
    local joined = type(bvar) == 'string' and bvar
      or type(bvar) == 'table' and vim.fn.join(bvar, ' ')
      or error(('invalid b:ferrum value: %s'):format(vim.inspect(bvar)))
    ---@type string
    local expanded = vim.fn.expandcmd(joined, { errmsg = true }) -- let it crash
    return vim.split(expanded, '%s+', { trimempty = true })
  end
end

---@param o vim.api.keyset.create_user_command.command_args
local REPL = function(o)
  local source = {
    buf = o.count == 0 and vim.api.nvim_get_current_buf()
      or vim.api.nvim_buf_is_valid(o.count) and o.count
      or error(('invalid buffer: %d'):format(o.count)),
    win = vim.api.nvim_get_current_win(),
  }

  Buffer.free(source.buf, true)

  local cmd = get_cmd(o, source.buf)
  local focus = not o.bang

  local job, repl_buf = spawn_repl_session(
    source.win,
    o.mods,
    cmd,
    focus,
    function(job, _, _)
      vim.notify(
        ('Finished: !%s (job %d)'):format(vim.fn.join(cmd, ' '), job),
        vim.log.levels.INFO
      )
      vim.iter(assert(Jobs.get(job)).clients):each(function(client)
        ---@cast client integer
        Buffer.free(client, false, true)
      end)
      Jobs.del(job)
    end
  )

  vim.notify(
    (':!%s (job %d)'):format(vim.fn.join(cmd), job),
    vim.log.levels.INFO
  )

  Jobs.set(job, {
    clients = { source.buf },
    repl = repl_buf,
    cmd = cmd,
  })

  vim.b[source.buf].ferrum_job = job

  Commands.Buflocal.setup {
    client = source.buf,
    repl = repl_buf,
    cmd = cmd,
    job = job,
  }
end

---@param o vim.api.keyset.create_user_command.command_args
---@return integer job
---@return JobRecord job record
local get_target_job = function(o)
  if o.args == '' then
    local jobs = Jobs.all()
    if vim.tbl_isempty(jobs) then
      error 'no ferrum jobs'
    elseif vim.tbl_count(jobs) == 1 then
      ---@type integer
      local job = vim.tbl_keys(jobs)[1]
      return job, jobs[job]
    else
      local job
      vim.ui.select(vim.tbl_keys(jobs), {
        prompt = 'Select ferrum session:',
        format_item = function(j)
          return ('job #%d (!%s)'):format(j, vim.fn.join(jobs[j].cmd, ' '))
        end,
      }, function(item, _)
        ---@cast item integer?
        job = assert(item, 'no session selected')
      end)
      return job, jobs[job]
    end
  else
    local arg1 = vim.split(o.args, '%s+')[1]
    local job = assert(tonumber(arg1), ('not an integer: %s'):format(arg1))
    assert(
      job >= 0 and job % 1 == 0,
      ('positive integer required: %d'):format(job)
    )
    local record = assert(Jobs.get(job), ('invalid job #%d').format(job))
    return job, record
  end
end

---@param o vim.api.keyset.create_user_command.command_args
local LinkREPL = function(o)
  local source_buf = vim.api.nvim_get_current_buf()
  local job, record = get_target_job(o)
  local repl_buf = record.repl
  local cmd = record.cmd

  Buffer.free(source_buf, true)

  Jobs.link(job, source_buf)

  vim.b[source_buf].ferrum_job = job

  Commands.Buflocal.setup {
    client = source_buf,
    repl = repl_buf,
    cmd = cmd,
    job = job,
  }
end

-- Set up :REPL and :LinkREPL command.
Commands.setup = function()
  -- Spawn REPL session in a split
  -- unless the buffer is alreadys bound with a REPL buffer
  vim.api.nvim_create_user_command('REPL', function(o)
    local ok, msg = safe(REPL, o)
    if not ok then echoerr(msg) end
  end, {
    desc = 'Spawn a new REPL session',
    nargs = '*',
    count = 0,
    complete = 'shellcmdline',
    bang = true,
  })

  -- Link this buffer to an existing REPL session
  vim.api.nvim_create_user_command('LinkREPL', function(o)
    local ok, msg = safe(LinkREPL, o)
    if not ok then echoerr(msg) end
  end, {
    desc = 'Link to an existing REPL session',
    nargs = '?',
    complete = function(arglead, _, _)
      ---@cast arglead string
      return vim
        .iter(pairs(Jobs.all()))
        :filter(function(job, _)
          ---@cast job integer
          return vim.startswith(tostring(job), arglead)
        end)
        :map(function(job, record)
          ---@cast job integer
          ---@cast record JobRecord
          return ('%d (!%s)'):format(job, vim.fn.join(record.cmd, ' '))
        end)
        :totable()
    end,
  })
end

return Commands
