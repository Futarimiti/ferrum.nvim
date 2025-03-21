-- Buflocal commands setup & de-setup

local Repl = require 'ferrum.core'
local Util = require 'ferrum.util'
local safe = Util.safe
local echoerr = Util.echoerr

local Buflocal = {}

-- All buflocal commands: names to definitions.
-- Some of these throw errors - might need to wrap a bit before turning them into commands.
---@type table<string,BuflocalCommandsDefinitionFunc>
local commands = {
  SendREPL = function(args)
    local job = args.job
    local cmd = vim.fn.join(args.cmd, ' ')
    return {
      callback = function(o) Repl.send(job, o.args) end,
      opts = {
        desc = ('Send text to job #%d (!%s)'):format(job, cmd),
        nargs = 1,
      },
    }
  end,
  SendlnREPL = function(args)
    local job = args.job
    local cmd = vim.fn.join(args.cmd, ' ')
    return {
      callback = function(o) Repl.sendln(job, o.args) end,
      opts = {
        desc = ('Send a line to job #%d (!%s)'):format(job, cmd),
        nargs = 1,
      },
    }
  end,
  SendRangeREPL = function(args)
    local job = args.job
    local cmd = vim.fn.join(args.cmd, ' ')
    return {
      callback = function(o)
        local lines = vim.fn.getline(o.line1, o.line2)
        Repl.sendln(job, lines)
      end,
      opts = {
        desc = ('Send range of lines (default .) to job #%d (!%s)'):format(
          job,
          cmd
        ),
        nargs = 0,
        range = true,
      },
    }
  end,
  FocusREPL = function(args)
    local job = args.job
    local cmd = vim.fn.join(args.cmd, ' ')
    local repl_buf = args.repl
    return {
      callback = function(o)
        -- wins where the REPL session buffer is being displayed
        local display_wins = vim.fn.win_findbuf(repl_buf)

        -- if REPL session buffer is displayed in any window, focus on one of them
        -- otherwise split a new window and put REPL session in, then focus

        ---@type integer? random window
        local maybe_random_win = display_wins[math.random(#display_wins)]
        if maybe_random_win == nil then
          vim.api.nvim_open_win(repl_buf, true, {
            split = 'above' --[[hardcoded TODO]],
          })
        else
          vim.api.nvim_set_current_win(maybe_random_win)
        end
        if o.bang then vim.cmd.startinsert() end
      end,
      opts = {
        desc = ('Focus on job #%d (!%s) (! to startinsert)'):format(job, cmd),
        nargs = 0,
        bang = true,
      },
    }
  end,
  StopREPL = function(args)
    local repl_buf = args.repl
    local job = args.job
    local cmd = vim.fn.join(args.cmd, ' ')
    return {
      callback = function(o)
        Repl.stop(job) -- triggers on_exit which frees all clients
        if o.bang then
          -- if opened in a window that should also be closed
          pcall(vim.api.nvim_buf_delete, repl_buf, { force = true })
        end
      end,
      opts = {
        desc = ('Finish job #%d (!%s) (! to also close window)'):format(
          job,
          cmd
        ),
        bang = true,
      },
    }
  end,
  UnlinkREPL = function(args)
    local client_buf = args.client
    local job = args.job
    local cmd = vim.fn.join(args.cmd, ' ')
    return {
      callback = function(_)
        -- lazy loading to avoid cyclic dependency
        require('ferrum.buffer').free(client_buf)
      end,
      opts = { desc = ('Unlink job #%d (!%s)'):format(job, cmd) },
    }
  end,
}

-- Remove all buflocal commands created by `Buflocal.setup`.
---@param buf integer
---@param tolerate boolean tolerate invalid buffers?
Buflocal.cleanup = function(buf, tolerate)
  if not vim.api.nvim_buf_is_valid(buf) then
    if not tolerate then error(('invalid buffer: %d'):format(buf)) end
    return
  end
  vim.iter(vim.tbl_keys(commands)):each(
    function(command) pcall(vim.api.nvim_buf_del_user_command, buf, command) end
  )
end

-- Create buflocal commands on given client buffer.
---@param args BuflocalCommandsSetupArgs
Buflocal.setup = function(args)
  vim.iter(pairs(commands)):each(
    ---@param name string
    ---@param define BuflocalCommandsDefinitionFunc
    function(name, define)
      local definition = define(args)
      local callback, opts = definition.callback, definition.opts
      vim.api.nvim_buf_create_user_command(
        args.client,
        name,
        ---@param o vim.api.keyset.create_user_command.command_args
        function(o)
          local ok, msg = safe(callback, o)
          if not ok then
            ---@cast msg string
            echoerr(msg)
          end
        end,
        opts
      )
    end
  )
end

return Buflocal

---@alias BuflocalCommandsSetupArgs {client:integer,repl:integer,job:integer,cmd:string[]}
---@alias BuflocalCommandsDefinitionFunc fun(args:BuflocalCommandsSetupArgs):{callback:fun(o:vim.api.keyset.create_user_command.command_args),opts:vim.api.keyset.user_command}
