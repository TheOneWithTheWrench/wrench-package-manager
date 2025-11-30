-- lua/wrench/log.lua

local M = {}

local log_levels = vim.log.levels

-- The prefix for all log messages from this plugin.
local PREFIX = "[wrench]"

--- Logs a message using vim.notify.
-- @param msg (string) The message to log.
-- @param level (number) A value from `vim.log.levels`.
local function log(msg, level)
  -- Prepend the prefix to the message.
  vim.notify(string.format("%s %s", PREFIX, msg), level)
end

function M.trace(msg)
  log(msg, log_levels.TRACE)
end

function M.debug(msg)
  log(msg, log_levels.DEBUG)
end

function M.info(msg)
  log(msg, log_levels.INFO)
end

function M.warn(msg)
  log(msg, log_levels.WARN)
end

function M.error(msg)
  log(msg, log_levels.ERROR)
end

return M
