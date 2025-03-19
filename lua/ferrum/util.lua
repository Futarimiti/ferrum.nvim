local Util = {}

-- Like pcall, but try to trim any debug info in error message
---@param f function
---@return boolean successful
---@return any result
Util.safe = function(f, ...)
  local ok, res = pcall(f, ...)
  if ok then
    return true, res
  else
    ---@cast res string
    local msg = res:match '^%[.-%]:%d+: (.*)$' or res
    return false, msg
  end
end

return Util
