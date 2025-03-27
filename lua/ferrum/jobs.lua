-- Job utilities

local Jobs = {}

-- List all active terminal jobs that are connected to a buffer.
---@return Jobs
Jobs.all = function()
  return vim.iter(vim.api.nvim_list_chans()):fold({}, function(acc, chaninfo)
    if
      chaninfo.buffer ~= nil and chaninfo.pty ~= '' -- pty empty when job done
    then
      acc[chaninfo.id] = {
        buf = chaninfo.buffer,
        cmd = (function()
          local argv = chaninfo.argv
          if argv == nil or vim.tbl_isempty(argv) then
            -- argv got to be non-nil right? ...right?
            return '--No cmd--'
          end
          argv[1] = vim.fn.fnamemodify(argv[1], ':t')
          return vim.fn.join(argv)
        end)(),
      }
    end
    return acc
  end)
end

return Jobs

---@alias JobInfo {cmd:string,buf:integer}
---@alias Jobs table<integer,JobInfo>
