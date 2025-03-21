-- Buflocal autocmds setup

local Buffer = require 'ferrum.buffer'

local Buflocal = {}

local group = vim.api.nvim_create_augroup('ferrum', {})

-- Create buflocal commands for given REPL term buffer:
-- * BufWipeout: when repl buffer gets wiped out (:bw! or <CR> after process finishes):
--   do cleanup (delete buffer-local commands and variables) on all client buffers
---@param args BuflocalAutocmdsSetupArgs
Buflocal.create = function(args)
  local client_buf = args.client
  local repl_buf = args.repl
  local job = args.job
  local cmd = vim.fn.join(args.cmd, ' ')
  vim.api.nvim_create_autocmd({ 'BufWipeout', 'TermClose' }, {
    desc = ('job #%d cleanup work (!%s) for client #%d'):format(
      job,
      cmd,
      client_buf
    ),
    once = true, -- why not
    buffer = repl_buf,
    group = group,
    callback = function()
      vim.notify_once(
        ('Finished: !%s (job %d)'):format(cmd, job),
        vim.log.levels.INFO
      )
      Buffer.free(client_buf, false, true)
    end,
  })
end

return Buflocal

---@alias BuflocalAutocmdsSetupArgs {client:integer,repl:integer,job:integer,cmd:string[]}
