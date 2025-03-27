local Jobs = require 'ferrum.jobs'
local Util = require 'ferrum.util'
local safe = Util.safe
local echoerr = Util.echoerr
local Buffer = require 'ferrum.buffer'
local Repl = require 'ferrum.core'

local Autocmds = {}
Autocmds.Buflocal = require 'ferrum.autocmds.buflocal'
Autocmds.User = require 'ferrum.autocmds.user'

local Commands = {}
Commands.Buflocal = require 'ferrum.commands.buflocal'

-- Spawn a REPL session in a new window.
---@param source_win integer
---@param mods string `<mods>`; modifiers for opening the new window
---@param cmd string[]
---@param focus boolean focus on the new split?
---@param on_exit fun(job:integer,exitcode:integer,event:string)
---@return integer job
---@return JobInfo info
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

  Autocmds.User.fire.FerrumSpawnREPLPost {
    repl = buf,
    cmd = cmd,
    job = job,
    client = vim.api.nvim_win_get_buf(source_win),
  }

  if focus then
    vim.cmd.startinsert()
  else
    ---@diagnostic disable-next-line: param-type-mismatch
    vim.fn.cursor('$', 0) -- XXX makes repl scroll automatically
    vim.api.nvim_set_current_win(source_win) -- jump back
  end

  ---@cast job integer
  return job, { buf = buf, cmd = vim.fn.join(cmd) }
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
    return ret
  else
    -- expand special keywords like % before use

    ---@type string
    local joined = type(bvar) == 'string' and bvar
      or type(bvar) == 'table' and vim.fn.join(bvar)
      or error(('invalid b:ferrum value: %s'):format(vim.inspect(bvar)))
    ---@type string
    local expanded = vim.fn.expandcmd(joined, { errmsg = true }) -- let it crash
    return vim.split(expanded, '%s+', { trimempty = true })
  end
end

---@param o vim.api.keyset.create_user_command.command_args
---@return integer job
---@return JobInfo job info
local get_target_job = function(o)
  if o.args == '' then
    local jobs = Jobs.all()
    if vim.tbl_isempty(jobs) then
      error 'no active jobs'
    elseif vim.tbl_count(jobs) == 1 then
      ---@type integer
      local job = vim.tbl_keys(jobs)[1]
      return job, jobs[job]
    else
      local job
      vim.ui.select(vim.tbl_keys(jobs), {
        prompt = 'Select session:',
        format_item = function(j)
          return ('job #%d (!%s)'):format(j, jobs[j].cmd)
        end,
      }, function(item, _)
        ---@cast item integer?
        job = assert(item, 'no session selected')
      end)
      return job, jobs[job]
    end
  else
    local arg1 = vim.split(o.args, '%s+')[1]
    local job =
      assert(tonumber(arg1), ('not an integer: %s'):format(vim.inspect(arg1)))
    assert(
      job >= 0 and job % 1 == 0,
      ('positive integer required: %d'):format(job)
    )
    local info = assert(Jobs.all()[job], ('invalid job #%d'):format(job))
    return job, info
  end
end

---@param source integer
---@param job integer
---@param info JobInfo
local link_repl = function(source, job, info)
  local cmd = vim.split(info.cmd, '%s+', { trimempty = true })
  local repl_buf = info.buf

  local o = {
    client = source,
    repl = repl_buf,
    job = job,
    cmd = cmd,
  }

  Autocmds.User.fire.FerrumLinkREPLPre(o)

  Buffer.free(source, true)

  vim.b[source].ferrum_job = job

  Commands.Buflocal.setup(o)
  Autocmds.Buflocal.setup(o)
  Autocmds.User.fire.FerrumLinkREPLPost(o)
end

---@param o vim.api.keyset.create_user_command.command_args
local LinkREPL = function(o)
  local job, info = get_target_job(o)
  link_repl(vim.api.nvim_get_current_buf(), job, info)
end

---@param o vim.api.keyset.create_user_command.command_args
local REPL = function(o)
  local source = {
    buf = o.count == 0 and vim.api.nvim_get_current_buf()
      or vim.api.nvim_buf_is_valid(o.count) and o.count
      or error(('invalid buffer: %d'):format(o.count)),
    win = vim.api.nvim_get_current_win(),
  }

  local cmd = get_cmd(o, source.buf)
  local focus = not o.bang

  local job, info = spawn_repl_session(
    source.win,
    o.mods,
    cmd,
    focus,
    function(_, _, _) end
  )

  vim.notify(
    (':!%s (job %d)'):format(vim.fn.join(cmd), job),
    vim.log.levels.INFO
  )

  link_repl(source.buf, job, info)
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
      local ret = vim
        .iter(pairs(Jobs.all()))
        :map(function(job, info)
          ---@cast job integer
          ---@cast info JobInfo
          if not vim.startswith(tostring(job), arglead) then return nil end
          return ('%d (!%s)'):format(job, info.cmd)
        end)
        :totable()
      if vim.tbl_isempty(ret) then
        vim.notify('No active terminal sessions', vim.log.levels.ERROR)
      end
      return ret
    end,
  })
end

return Commands
