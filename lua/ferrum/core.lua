local M = {}

-- Try to spawn a REPL session in given window and focus on it.
---@param win integer window id to spawn REPL in. Must contain an unmodified buffer
---@param cmd string[] shell command to run; use empty table to use b:repl
---@param on_exit fun(job:integer,exitcode:integer,event:string)
---@return integer job
M.spawn = function(win, cmd, on_exit)
  vim.api.nvim_set_current_win(win)
  -- this spawns in current buffer
  local job = vim.fn.jobstart(cmd, { term = true, on_exit = on_exit })
  assert(job ~= 0 and job ~= -1, 'failing to spawn job')
  return job
end

-- Send text to a REPL session.
-- Panics when sending to invalid jobs, or failing in sending.
---@param job integer job id
---@param text string|string[] text, or lines of text
M.send = function(job, text)
  local ok, ret = pcall(vim.fn.chansend, job, text)
  if not ok then error(ret) end
  if ret == 0 then error 'zero bytes sent' end
end

-- Send text to a REPL session, followed by a newline.
-- Panics when sending to invalid jobs, or failing in sending.
---@param job integer job id
---@param text string|string[] text, or lines of text
M.sendln = function(job, text)
  M.send(job, text)
  M.send(job, '\n')
end

-- End a REPL session.
---@type fun(job:integer)
M.stop = vim.fn.jobstop

return M
