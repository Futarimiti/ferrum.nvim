-- Buflocal autocmds setup

local User = require 'ferrum.autocmds.user'

local M = {}

local group = vim.api.nvim_create_augroup('ferrum-repl', {})

-- As the REPL session finishes, free the client buffer (if it's still valid).
---@param o ferrum.buflocal.commands.setup.args
M.setup = function(o)
  local cmd = vim.fn.join(o.cmd)
  vim.api.nvim_create_autocmd({ 'TermClose' }, {
    buffer = o.repl,
    group = group,
    once = true,
    desc = ('client buf #%d | repl buf #%d | job #%d (!%s)'):format(
      o.client,
      o.repl,
      o.job,
      cmd
    ),
    callback = function()
      User.fire.FerrumFinishREPLPost(o)
      return true
    end,
  })
end

vim.api.nvim_create_autocmd('User', {
  group = group,
  pattern = 'FerrumFinishREPLPost',
  desc = 'Clear buflocal cmds on job finishing',
  callback = function(args)
    ---@type ferrum.autocmds.user.args
    local o = args.data
    local cmd = vim.fn.join(o.cmd)
    vim.notify(
      ('Finished: !%s (job %d)'):format(cmd, o.job),
      vim.log.levels.INFO
    )
    require('ferrum.buffer').free(o.client, false, true, o.job)
  end,
})

return M

---@alias ferrum.buflocal.autocmds.setup.args {client:integer,repl:integer,job:integer,cmd:string[]}
