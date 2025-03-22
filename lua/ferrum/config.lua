-- User configuration
local Config = {}

---@class ferrum.Config
-- Sorry, nothing here yet

---@type ferrum.Config
Config.defaults = {}

-- Gives a validated config based on user input
---@param user any?
---@return ferrum.Config
Config.validate = function(user)
  vim.validate('config', user, { 'table', 'nil' })
  ---@cast user table?
  local overriden = vim.tbl_extend('force', Config.defaults, user or {})
  -- TODO: insert vim.validate checks here
  ---@cast overriden ferrum.Config
  return overriden
end

return Config
