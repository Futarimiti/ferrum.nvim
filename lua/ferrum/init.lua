local Commands = require 'ferrum.commands'
local Config = require 'ferrum.config'

local Ferrum = {}

-- `user` could be anything; validation is necessary.
-- It's typed `ferrum.Config` only so luals hints will be available.
---@param user? ferrum.Config arbitrary user input
Ferrum.setup = function(user)
  ---@cast user any
  local config = Config.validate(user)
  Commands.setup(config)
end

return Ferrum
