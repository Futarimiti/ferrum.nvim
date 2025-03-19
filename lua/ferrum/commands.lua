local Util = require 'ferrum/util'
local safe = Util.safe
local Repl = require 'ferrum/core'

-- Cleanup source buffer: remove b:repl and buflocal commands created by :REPL
---@param source_buf integer
local cleanup = function(source_buf)
  if not vim.api.nvim_buf_is_valid(source_buf) then return end
  vim.b[source_buf].repl = nil
  pcall(vim.api.nvim_buf_del_user_command, source_buf, 'SendREPL')
  pcall(vim.api.nvim_buf_del_user_command, source_buf, 'SendlnREPL')
  pcall(vim.api.nvim_buf_del_user_command, source_buf, 'SendRangeREPL')
  pcall(vim.api.nvim_buf_del_user_command, source_buf, 'FocusREPL')
  pcall(vim.api.nvim_buf_del_user_command, source_buf, 'StopREPL')
end

-- Setup buflocal commands (used by :REPL)
---@param buf integer source buffer
local buffer_local_commands_setup = function(buf)
  -- Shortcut for implementing :Send and :SendLine
  ---@param f fun(_:integer,_:string|string[])
  ---@return fun(_:vim.api.keyset.create_user_command.command_args)
  local sendcmd = function(f)
    return function(o)
      ---@type integer?
      local job = vim.tbl_get(vim.b[buf], 'repl', 'job')
      if job == nil then
        error 'no REPL bound to current buffer'
      else
        local ok, res = safe(f, job, o.args)
        if not ok then
          ---@cast res string
          vim.api.nvim_echo({ { res, 'ErrorMsg' } }, true, { err = true })
        end
      end
    end
  end

  -- write to REPL
  vim.api.nvim_buf_create_user_command(buf, 'SendREPL', sendcmd(Repl.send), {
    desc = 'Send text to REPL session bound to current buffer',
    nargs = 1,
  })
  vim.api.nvim_buf_create_user_command(
    buf,
    'SendlnREPL',
    sendcmd(Repl.sendln),
    {
      desc = 'Send a line to REPL session bound to current buffer',
      nargs = 1,
    }
  )
  vim.api.nvim_buf_create_user_command(buf, 'SendRangeREPL', function(o)
    ---@type string[]
    local lines = vim.fn.getline(o.line1, o.line2)
    ---@type integer?
    local job = vim.tbl_get(vim.b[buf], 'repl', 'job')
    Repl.sendln(job, lines)
  end, {
    desc = 'Send range of lines (default .) to REPL session bound to current buffer',
    nargs = 0,
    range = true,
  })

  -- if REPL session buffer is displayed in any window, focus on one of them
  -- otherwise split a new window and put REPL session in, then focus
  vim.api.nvim_buf_create_user_command(buf, 'FocusREPL', function(o)
    ---@type integer
    local repl_buf = vim.b[buf].repl.buf
    -- winids where the REPL session buffer is being displayed
    local display_wins = vim.fn.win_findbuf(repl_buf)
    ---@type integer? randomly select a window, if any
    local maybe_random_win = display_wins[math.random(#display_wins)]
    if maybe_random_win == nil then
      vim.b[buf].repl.win = vim.api.nvim_open_win(repl_buf, true, {
        split = 'above' --[[hardcoded TODO]],
      })
    else
      vim.api.nvim_set_current_win(maybe_random_win)
    end
    if o.bang then vim.cmd.startinsert() end
  end, {
    desc = 'Focus on REPL session bound to current buffer (! to startinsert)',
    nargs = 0,
    bang = true,
  })

  vim.api.nvim_buf_create_user_command(buf, 'StopREPL', function(o)
    local bvars = vim.b[buf]
    ---@type integer?
    local job = vim.tbl_get(bvars, 'repl', 'job')
    if job then Repl.stop(job) end
    if o.bang then
      ---@type integer?
      local repl_buf = vim.tbl_get(bvars, 'repl', 'buf')
      ---@type integer?
      local repl_win = vim.tbl_get(bvars, 'repl', 'win')
      -- tolerate invalid ids
      if repl_buf then
        pcall(vim.api.nvim_buf_delete, repl_buf, { force = true })
      end
      if repl_win then pcall(vim.api.nvim_win_close, repl_win, true) end
    end

    cleanup(buf)
  end, {
    desc = 'Stop the REPL session bound to current buffer (! to also close window)',
    bang = true,
  })
end

local group = vim.api.nvim_create_augroup('REPL', {})

-- Set up autocmds:
-- * When repl buffer gets wiped out (:bw! or <CR> after process finishes):
--   do cleanup (delete buffer-local commands and variables) on source buffer
--   (buffer still accessible after :bd'ed)
---@param buf integer repl buf
local autocmd_setup = function(buf)
  vim.api.nvim_create_autocmd('BufWipeout', {
    desc = ('cleanup work for REPL session at buf %d'):format(buf),
    buffer = buf,
    group = group,
    callback = function()
      local source = vim.b[buf].source
      vim.notify(
        ('Finished: !%s (job %d)'):format(vim.fn.join(source.cmd), source.job),
        vim.log.levels.INFO
      )
      cleanup(source.buf)
    end,
  })
end

local Commands = {}

-- Set up :REPL command.
Commands.setup = function()
  -- Spawn REPL session in a split
  -- unless the buffer is alreadys bound with a REPL buffer
  vim.api.nvim_create_user_command('REPL', function(o)
    local current = {
      buf = vim.api.nvim_get_current_buf(),
      win = vim.api.nvim_get_current_win(),
    }

    if vim.tbl_get(vim.b[current.buf], 'repl') ~= nil then
      local repl = vim.b[current.buf].repl
      vim.notify(
        ('already bound to REPL session at buffer %d (job %d: !%s)'):format(
          repl.buf,
          repl.job,
          vim.fn.join(repl.cmd)
        ),
        vim.log.levels.WARN
      )
      vim.notify_once(
        ':Stop existing bound REPL session first before starting another',
        vim.log.levels.WARN
      )
      return
    end

    local repl = (function()
      local newbuf = vim.api.nvim_create_buf(true, true)
      -- must enter - can only spawn job in currently focused buffer
      local enter = true
      -- TODO need to look at modifiers the user provides. for now just above
      -- print('mods:', vim.inspect(o.mods))
      local split = 'above'
      return {
        buf = newbuf,
        win = vim.api.nvim_open_win(newbuf, enter, {
          split = split,
          win = current.win,
        }),
      }
    end)()

    ---@type string[]
    local cmd = (function()
      if not vim.tbl_isempty(o.fargs) then return o.fargs end
      local bvar = vim.b[current.buf].ferrum
      if bvar == nil then
        return vim.split(
          vim.fn.input('> ', '', 'shellcmdline'),
          '%s+',
          { trimempty = true }
        )
      end
      if type(bvar) == 'string' then
        return vim.split(bvar, '%s+', { trimempty = true })
      end
      if type(bvar) == 'table' then return bvar end
      error(('invalid b:ferrum value: %s'):format(vim.inspect(bvar)))
    end)()

    local ok, res = safe(Repl.spawn, repl.win, cmd)
    if not ok then
      pcall(vim.api.nvim_buf_delete, repl.buf, { force = true })
      pcall(vim.api.nvim_win_close, repl.win, true)
      vim.api.nvim_set_current_win(current.win)
      ---@cast res string
      vim.api.nvim_echo({ { res, 'ErrorMsg' } }, true, { err = true })
      return
    end
    ---@type integer
    local job = res
    print((':!%s (job %d)'):format(vim.fn.join(cmd), job))

    -- now we may jump back
    local stay = o.bang
    if stay then
      vim.api.nvim_set_current_win(current.win)
    else
      vim.cmd.startinsert()
    end

    -- record info in source buffer, to be used by other commands in future
    vim.b[current.buf].repl = {
      buf = repl.buf,
      win = repl.win,
      job = job,
      cmd = cmd,
    }

    -- record info in repl buffer, to be used by autocmds
    vim.b[repl.buf].source = {
      buf = current.buf,
      win = current.win,
      job = job,
      cmd = cmd,
    }

    -- setup buffer-local REPL commands
    buffer_local_commands_setup(current.buf)
    autocmd_setup(repl.buf)
  end, {
    desc = 'Spawn a new REPL session',
    nargs = '*',
    complete = 'shellcmdline',
    bang = true,
  })
end

return Commands
