-- Buflocal autocmds setup

local M = {}

local group = vim.api.nvim_create_augroup('ferrum-repl', {})

---@param o ferrum.buflocal.commands.setup.args
M.setup = function(o)
  vim.api.nvim_create_autocmd({ 'BufWipeout', 'TermClose' }, {
    buffer = o.repl,
    group = group,
    once = true,
    desc = ('Clear buf #%d local cmds on job #%d (!%s) finish'):format(
      o.client,
      o.job,
      o.cmd
    ),
    callback = function()
      vim.notify(
        ('Finished: !%s (job %d)'):format(vim.fn.join(o.cmd, ' '), o.job),
        vim.log.levels.INFO
      )
      require('ferrum.buffer').free(o.client, false, true)
      return true
    end,
  })
end

return M

---@alias ferrum.buflocal.autocmds.setup.args {client:integer,repl:integer,job:integer,cmd:string[]}
