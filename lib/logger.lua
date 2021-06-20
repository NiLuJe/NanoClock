-- Pilfered from KOReader <https://github.com/koreader/koreader/blob/master/frontend/logger.lua>
-- SPDX-License-Identifier: AGPL-3.0-or-later

--[[--
Logger module.
See @{Logger.levels} for list of supported levels.

Example:

    local logger = require("logger")
    logger.info("Something happened.")
    logger.err("House is on fire!")
]]

local ffi = require("ffi")
local C = ffi.C
require("ffi/posix_h")

--- Supported logging levels
-- @table Logger.levels
-- @field dbg debug
-- @field info informational (default level)
-- @field notice normal, but significant
-- @field warn warning
-- @field err error
local LOG_PRIO = {
	dbg = C.LOG_DEBUG,
	info = C.LOG_INFO,
	notice = C.LOG_NOTICE,
	warn = C.LOG_WARNING,
	err = C.LOG_ERR,
	crit = C.LOG_CRIT,
}

local noop = function() end

local Logger = {
	levels = LOG_PRIO,
}

local function log(prio, ...)
	C.syslog(prio, ...)
end

local LVL_FUNCTIONS = {
	dbg = function(...) log(LOG_PRIO.dbg, ...) end,
	info = function(...) log(LOG_PRIO.info, ...) end,
	notice = function(...) log(LOG_PRIO.notice, ...) end,
	warn = function(...) log(LOG_PRIO.warn, ...) end,
	err = function(...) log(LOG_PRIO.err, ...) end,
	crit = function(...) log(LOG_PRIO.crit, ...) end,
}

--[[--
Set logging level. By default, level is set to info.

@int new_lvl new logging level, must be one of the levels from @{Logger.levels}

@usage
Logger:setLevel(Logger.levels.warn)
]]
function Logger:setLevel(new_lvl)
	for lvl_name, lvl_value in pairs(LOG_PRIO) do
		if new_lvl >= lvl_value then
			self[lvl_name] = LVL_FUNCTIONS[lvl_name]
		else
			self[lvl_name] = noop
		end
	end
end

Logger:setLevel(LOG_PRIO.info)

return Logger
