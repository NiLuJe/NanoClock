#! ./bin/luajit

--[[
	NanoClock: A persnickety clock for Kobo devices
	Inspired by @frostschutz's MiniClock <https://github.com/frostschutz/Kobo/tree/master/MiniClock>,
	and my own previous take on it at <https://github.com/NiLuJe/Kobo/tree/master/MiniClock>.

	Copyright (C) 2021 NiLuJe <ninuje@gmail.com>
	SPDX-License-Identifier: GPL-3.0-or-later
--]]

local bit = require("bit")
local ffi = require("ffi")
local C = ffi.C

require("ffi/fbink_h")
require("ffi/mxcfb_h")
require("ffi/mxcfb_damage_h")
require("ffi/posix_h")

-- Mangle package search paths to sart looking inside lib/ first...
package.path =
    "lib/?.lua;" ..
    package.path
package.cpath =
    "lib/?.so;" ..
    package.cpath

local fbink_util = require("fbink_util")
local lfs = require("lfs")
local logger = require("logger")
local util = require("util")
local Geom = require("geometry")
local INIFile = require("inifile")
local FBInk = ffi.load("lib/libfbink.so.1.0.0")

local NanoClock = {
	data_folder = "/usr/local/NanoClock",
	addon_folder = "/mnt/onboard/.adds/nanoclock",
	config_file = "nanoclock.ini",
	nickel_config = "/mnt/onboard/.kobo/Kobo/Kobo eReader.conf",

	-- fds
	fbink_fd = -1,
	damage_fd = -1,
	inotify_fd = -1,
	clock_fd = -1,
	pfds = ffi.new("struct pollfd[3]"),
	inotify_wd = {},

	-- State tracking
	clock_marker = 0,
	marker_found = false,
	clock_area = Geom:new{x = 0, y = 0, w = math.huge, h = math.huge},
	nickel_mtime = 0,
	fl_brightness = "??",

	-- I18N stuff
	days_map = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" },
	months_map = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" },
}

function NanoClock:die(msg)
	logger.crit(msg)
	self:fini()
	error(msg)
end

function NanoClock:init()
	-- Setup logging
	C.openlog("nanoclock", bit.bor(C.LOG_CONS, C.LOG_PID, C.LOG_NDELAY), C.LOG_DAEMON)

	self.defaults_path = self.data_folder .. "/etc/" .. self.config_file
	self.config_path = self.addon_folder .. "/" .. self.config_file

	-- If we don't have a custom config file, copy the defaults
	if lfs.attributes(self.config_path, "mode") ~= "file" then
		if lfs.attributes(self.defaults_path, "mode") ~= "file" then
			self:die("Default config file is missing, aborting!")
		end

		if lfs.attributes(self.addon_folder, "mode") ~= "directory" then
			util.makePath(self.addon_folder)
		end
		util.copyFile(self.defaults_path, self.config_path)
	end

	self.version = util.readFileAsString(self.data_folder .. "/etc/VERSION")
	if self.version == "" then
		self.version = "vDEV"
	end
end

function NanoClock:initFBInk()
	self.fbink_cfg = ffi.new("FBInkConfig")
	self.fbink_ot = ffi.new("FBInkOTConfig")
	self.fbink_state = ffi.new("FBInkState")
	self.fbink_dump = ffi.new("FBInkDump")

	-- Enable logging to syslog ASAP
	self.fbink_cfg.is_verbose = true
	self.fbink_cfg.is_quiet = false
	self.fbink_cfg.to_syslog = true
	FBInk.fbink_update_verbosity(self.fbink_cfg)

	self.fbink_fd = FBInk.fbink_open()
	if self.fbink_fd == -1 then
		self:die("Failed to open the framebuffer, aborting!")
	end

	if FBInk.fbink_init(self.fbink_fd, self.fbink_cfg) < 0 then
		self:die("Failed to initialize FBInk, aborting!")
	end

	-- We may need to do some device-specific stuff down the line...
	FBInk.fbink_get_state(self.fbink_cfg, self.fbink_state)
	self.device_platform = ffi.string(self.fbink_state.device_platform)

	-- So far, this has held across the full lineup
	self.battery_sysfs = "/sys/devices/platform/pmic_battery.1/power_supply/mc13892_bat/capacity"
end

function NanoClock:initDamage()
	self.damage_fd = C.open("/dev/fbdamage", bit.bor(C.O_RDONLY, C.O_NONBLOCK, C.O_CLOEXEC))
	if self.damage_fd == -1 then
		self:die("Failed to open the fbdamage device, aborting!")
	end
end

function NanoClock:armTimer()
	if self.clock_fd ~= -1 then
		return
	end

	self.clock_fd = C.timerfd_create(C.CLOCK_REALTIME, bit.bor(C.TFD_NONBLOCK, C.TFD_CLOEXEC))
	if self.clock_fd == -1 then
		local errno = ffi.errno()
		self:die(string.format("timerfd_create: %s", C.strerror(errno)))
	end

	-- Arm it to get a tick on every minute, on the dot.
	local now_ts = ffi.new("struct timespec")
	C.clock_gettime(C.CLOCK_REALTIME, now_ts)
	local clock_timer = ffi.new("struct itimerspec")
	-- Round the current timestamp up to the next multiple of 60 to get us the next minute on the dot.
	clock_timer.it_value.tv_sec = math.floor((now_ts.tv_sec + 60 - 1) / 60) * 60
	clock_timer.it_value.tv_nsec = 0
	-- Tick every minute
	clock_timer.it_interval.tv_sec = 60
	clock_timer.it_interval.tv_nsec = 0
	if C.timerfd_settime(self.clock_fd, C.TFD_TIMER_ABSTIME, clock_timer, nil) == -1 then
		local errno = ffi.errno()
		self:die(string.format("timerfd_settime: %s", C.strerror(errno)))
	end

	-- And update the poll table
	self.pfds[2].fd = self.clock_fd
end

function NanoClock:disarmTimer()
	if self.clock_fd == -1 then
		return
	end

	C.close(self.clock_fd)
	-- Keep it set to a negative value to make poll ignore it
	self.clock_fd = -1
	self.pfds[2].fd = -1
end

function NanoClock:initInotify()
	self.inotify_fd = C.inotify_init1(bit.bor(C.IN_NONBLOCK, C.IN_CLOEXEC))
	if self.inotify_fd == -1 then
		local errno = ffi.errno()
		self:die(string.format("inotify_init1: %s", C.strerror(errno)))
	end
end

function NanoClock:setupInotify()
	-- We're called on each iteration right before poll, in order to recreate the wd after an unmount.
	-- But in most cases, the wd will be alive and well, so, only proceed if:
	-- * the watch was never actually created (e.g., first ever poll call)
	-- * or it was destroyed by an unmount, in which case we try to recreate it
	if self.inotify_wd[self.config_path] and self.inotify_wd[self.config_path] ~= -1 then
		return
	end

	-- If a watch for that file was previously created, that means it's been destroyed by an unmount
	local was_destroyed = false
	if self.inotify_wd[self.config_path] then
		-- Given the early return check, we know it's going to be set to -1, which is our "destroyed" marker.
		was_destroyed = true
	end

	self.inotify_wd[self.config_path] = C.inotify_add_watch(self.inotify_fd, self.config_path, C.IN_CLOSE_WRITE)
	if self.inotify_wd[self.config_path] == -1 then
		local errno = ffi.errno()
		-- We allow ENOENT as it *will* happen when onboard is unmounted during an USBMS session!
		-- (Granted, the only damage events we should catch during an USBMS session are ours,
		-- and the only way that can happen is via timerfd ticks ;)).
		if errno ~= C.ENOENT then
			self:die(string.format("inotify_add_watch: %s", C.strerror(errno)))
		end
	else
		-- If we've just recreated the watch after an unmount/remount cycle, force a config reload,
		-- as it may have been updated outside of our oversight (e.g., USBMS)...
		if was_destroyed then
			self:reloadConfig()
		end
	end
end

function NanoClock:initConfig()
	local config_mtime = lfs.attributes(self.config_path, "modification")
	if not config_mtime then
		-- Can't find the config file *and* we never parsed it?
		-- This should never happen, as the startup script should have ensured onboard is mounted by now,
		-- and :init() that we've got a user config file in there...
		self:die("Config file is missing, aborting!")
	end

	-- Start by loading the defaults...
	self.defaults = INIFile.parse(self.defaults_path)
	-- Then the user config...
	self.cfg = INIFile.parse(self.config_path)

	self:sanitizeConfig()

	self:handleConfig()
end

function NanoClock:reloadConfig()
	logger.notice("Config file was modified, reloading it")
	-- NOTE: We're only called on inotify events, so we *should* have a guarantee that the file actually exists...
	self.cfg = INIFile.parse(self.config_path)
	self:sanitizeConfig()
	self:handleConfig()

	-- Force a clock refresh for good measure,
	-- (and also to ease recovering from print failures stemming from config issues).
	self:handleFBInkReinit()
	self:displayClock()
end

function NanoClock:sanitizeConfig()
	-- Fill in anything that's missing in the user config with the defaults.
	for section, st in pairs(self.defaults) do
		if self.cfg[section] == nil then
			self.cfg[section] = {}
		end
		for k, v in pairs(st) do
			if self.cfg[section][k] == nil then
				self.cfg[section][k] = v
			end
		end
	end
end

function NanoClock:handleConfig()
	-- Was an uninstall requested?
	if self.cfg.global.uninstall ~= 0 then
		os.rename(self.config_path, self.addon_folder .. "/uninstalled-" .. os.date("%Y%m%d-%H%M") .. ".ini")
		os.remove("/etc/udev/rules.d/99-nanoclock.rules")
		os.execute("rm -rf /usr/local/NanoClock")
		self:die("Uninstalled!")
	end

	-- Was debug logging requested?
	if self.cfg.global.debug == 0 then
		logger:setLevel(logger.levels.info)
	else
		logger:setLevel(logger.levels.dbg)
	end

	-- Massage various settings into a usable form
	if self.cfg.display.backgroundless ~= 0 then
		self.fbink_cfg.is_bgless = true
	else
		self.fbink_cfg.is_bgless = false
	end
	if self.cfg.display.overlay ~= 0 then
		self.fbink_cfg.is_overlay = true
	else
		self.fbink_cfg.is_overlay = false
	end

	-- If autorefresh is enabled in conjunction with a "no background" drawing mode,
	-- we'll need to resort to some trickery to avoid overlapping prints...
	if self.cfg.display.autorefresh ~= 0 and (self.cfg.display.backgroundless ~= 0 or self.cfg.display.overlay ~= 0) then
		self.overlap_trick = true
	else
		self.overlap_trick = false
	end

	if self.cfg.display.truetype_format == nil then
		self.cfg.display.truetype_format = self.cfg.display.format
	end
	if self.cfg.display.truetype_padding ~= 0 then
		self.cfg.display.truetype_format = " " .. self.cfg.display.truetype_format .. " "
	end

	-- Handle the localization mappings...
	if self.cfg.display.days ~= nil then
		local user_days = {}
		for day in self.cfg.display.days:gmatch("%S+") do
			table.insert(user_days, day)
		end

		local en_days = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }
		self.days_map = {}
		for k, v in ipairs(en_days) do
			self.days_map[k] = user_days[k] or v
		end
	end

	if self.cfg.display.months ~= nil then
		local user_months = {}
		for month in self.cfg.display.months:gmatch("%S+") do
			table.insert(user_months, month)
		end

		local en_months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
		self.months_map = {}
		for k, v in ipairs(en_months) do
			self.months_map[k] = user_months[k] or v
		end
	end

	-- Make sure the font paths are absolute, because our $PWD is not self.addon_folder but self.data_folder ;).
	if self.cfg.display.truetype ~= nil then
		if self.cfg.display.truetype:sub(1, 1) ~= "/" then
			self.cfg.display.truetype = self.addon_folder .. "/" .. self.cfg.display.truetype
		end
	end
	if self.cfg.display.truetype_bold ~= nil then
		if self.cfg.display.truetype_bold:sub(1, 1) ~= "/" then
			self.cfg.display.truetype_bold = self.addon_folder .. "/" .. self.cfg.display.truetype_bold
		end
	end
	if self.cfg.display.truetype_italic ~= nil then
		if self.cfg.display.truetype_italic:sub(1, 1) ~= "/" then
			self.cfg.display.truetype_italic = self.addon_folder .. "/" .. self.cfg.display.truetype_italic
		end
	end
	if self.cfg.display.truetype_bolditalic ~= nil then
		if self.cfg.display.truetype_bolditalic:sub(1, 1) ~= "/" then
			self.cfg.display.truetype_bolditalic = self.addon_folder .. "/" .. self.cfg.display.truetype_bolditalic
		end
	end

	-- Setup FBInk according to those settings...
	if self.cfg.display.truetype ~= nil then
		if FBInk.fbink_add_ot_font(self.cfg.display.truetype, C.FNT_REGULAR) ~= 0 then
			logger.warn("Failed to load Regular font `%s`", self.cfg.display.truetype)
			self.cfg.display.truetype = nil
		end
	end
	if self.cfg.display.truetype_bold ~= nil then
		if FBInk.fbink_add_ot_font(self.cfg.display.truetype_bold, C.FNT_BOLD) ~= 0 then
			logger.warn("Failed to load Bold font `%s`", self.cfg.display.truetype_bold)
			self.cfg.display.truetype_bold = nil
		end
	end
	if self.cfg.display.truetype_italic ~= nil then
		if FBInk.fbink_add_ot_font(self.cfg.display.truetype_italic, C.FNT_ITALIC) ~= 0 then
			logger.warn("Failed to load Italic font `%s`", self.cfg.display.truetype_italic)
			self.cfg.display.truetype_italic = nil
		end
	end
	if self.cfg.display.truetype_bolditalic ~= nil then
		if FBInk.fbink_add_ot_font(self.cfg.display.truetype_bolditalic, C.FNT_BOLD_ITALIC) ~= 0 then
			logger.warn("Failed to load BoldItalic font `%s`", self.cfg.display.truetype_bolditalic)
			self.cfg.display.truetype_bolditalic = nil
		end
	end

	-- Do we use the OT codepath at all?
	if self.cfg.display.truetype or
	   self.cfg.display.truetype_bold or
	   self.cfg.display.truetype_italic or
	   self.cfg.display.truetype_bolditalic then
		self.with_ot = true
	else
		self.with_ot = false
	end

	-- OT setup
	self.fbink_ot.size_pt = self.cfg.display.truetype_size
	self.fbink_ot.size_px = self.cfg.display.truetype_px
	self.fbink_ot.margins.top = self.cfg.display.truetype_y
	self.fbink_ot.margins.left = self.cfg.display.truetype_x
	if self.cfg.display.truetype_bold or
	   self.cfg.display.truetype_italic or
	   self.cfg.display.truetype_bolditalic then
		self.fbink_ot.is_formatted = true
	else
		self.fbink_ot.is_formatted = false
	end
	if self.with_ot then
		self.fbink_cfg.fg_color = fbink_util.FGColor(self.cfg.display.truetype_fg)
		self.fbink_cfg.bg_color = fbink_util.BGColor(self.cfg.display.truetype_bg)
	else
		self.fbink_cfg.fg_color = fbink_util.FGColor(self.cfg.display.fg_color)
		self.fbink_cfg.bg_color = fbink_util.BGColor(self.cfg.display.bg_color)
	end

	-- Fixed cell setup
	self.fbink_cfg.col = self.cfg.display.column
	self.fbink_cfg.hoffset = self.cfg.display.offset_x
	self.fbink_cfg.row = self.cfg.display.row
	self.fbink_cfg.voffset = self.cfg.display.offset_y
	self.fbink_cfg.fontname = fbink_util.Font(self.cfg.display.font)
	self.fbink_cfg.fontmult = self.cfg.display.size

	-- Some settings require an fbink_init to take...
	FBInk.fbink_init(self.fbink_fd, self.fbink_cfg)

	-- Toggle timerfd
	if self.cfg.display.autorefresh ~= 0 then
		self:armTimer()
	else
		self:disarmTimer()
	end
end

function NanoClock:getFrontLightLevel()
	-- We can poke sysfs directly on Mark 7
	if self.device_platform == "Mark 7" then
		local brightness = util.readFileAsNumber("/sys/class/backlight/mxc_msp430.0/actual_brightness")
		return tostring(brightness) .. "%"
	else
		-- Otherwise, we have to look inside Nickel's config...
		-- Avoid parsing it again if it hasn't changed.
		local nickel_mtime = lfs.attributes(self.nickel_config, "modification")
		if not nickel_mtime then
			return self.fl_brightness
		end

		if nickel_mtime == self.nickel_mtime then
			return self.fl_brightness
		else
			self.nickel_mtime = nickel_mtime
		end

		local nickel = INIFile.parse(self.nickel_config)
		if nickel and nickel.PowerOptions and nickel.PowerOptions.FrontLightLevel then
			self.fl_brightness = tostring(nickel.PowerOptions.FrontLightLevel) .. "%"
			return self.fl_brightness
		else
			return "??"
		end
	end
end

function NanoClock:getBatteryLevel()
	local gauge = util.readFileAsNumber(self.battery_sysfs)
	if gauge >= self.cfg.display.battery_min and gauge <= self.cfg.display.battery_max then
		return tostring(gauge) .. "%"
	else
		return ""
	end
end

function NanoClock:getUserDay()
	local k = tonumber(os.date("%u"))

	return self.days_map[k]
end

function NanoClock:getUserMonth()
	local k = tonumber(os.date("%m"))

	return self.months_map[k]
end

local function expandPatterns(m)
	-- NOTE: We pass a function to gsub instead of a simple replacement table in order to be able to only
	--       actually run the function that generates the substitution string as necessary...
	if m == "{battery}" then
		return NanoClock:getBatteryLevel()
	elseif m == "{frontlight}" then
		return NanoClock:getFrontLightLevel()
	elseif m == "{day}" then
		return NanoClock:getUserDay()
	elseif m == "{month}" then
		return NanoClock:getUserMonth()
	end
end

function NanoClock:prepareClock()
	-- If the clock was stopped, we're done.
	if self.cfg.global.stop ~= 0 then
		return false
	end

	-- Run the appropriate user format string through strftime...
	if self.with_ot then
		self.clock_string = os.date(self.cfg.display.truetype_format)
	else
		self.clock_string = os.date(self.cfg.display.format)
	end

	-- Do we have substitutions to handle?
	if not self.clock_string:find("%b{}") then
		-- We don't, no need to compute fancy stuff
		return true
	end

	-- Let gsub do the rest ;).
	self.clock_string = self.clock_string:gsub("(%b{})", expandPatterns)

	return true
end

function NanoClock:invalidateClockArea()
	self.clock_area.x = 0
	self.clock_area.y = 0
	self.clock_area.w = math.huge
	self.clock_area.h = math.huge
end

function NanoClock:handleFBInkReinit()
	local reinit = FBInk.fbink_reinit(self.fbink_fd, self.fbink_cfg)
	if reinit > 0 then
		-- Refresh our state copy
		FBInk.fbink_get_state(self.fbink_cfg, self.fbink_state)

		if bit.band(reinit, C.OK_BPP_CHANGE) ~= 0 then
			logger.notice("Handled a framebuffer bitdepth change")
		end

		-- In case of rotation, our clock area is now meaningless,
		-- so, make sure to invalidate it so we force a repaint at the "new" coordinates...
		if bit.band(reinit, C.OK_LAYOUT_CHANGE) ~= 0 then
			logger.notice("Handled a framebuffer orientation change")
			self:invalidateClockArea()
		elseif bit.band(reinit, C.OK_ROTA_CHANGE) ~= 0 then
			logger.notice("Handled a framebuffer rotation change")
			self:invalidateClockArea()
		end
	end
end

function NanoClock:grabClockBackground()
	if not self.overlap_trick then
		return
	end

	-- We'd need the *unrotated* clock area to be able to handle quirky landscapes...
	-- As this should not happen outside of the boot anim on current FW versions,
	-- just forget about it...
	-- FIXME: Err, do we, actually?
	--[[
	if self.fbink_state.is_ntx_quirky_landscape then
		return
	end
	--]]

	logger.dbg("Grabbing clock bg")
	FBInk.fbink_rect_dump(self.fbink_fd, self.fbink_last_rect, self.fbink_dump)

	logger.dbg("Dump: %hux%hu+%hu+%hu",
	           ffi.cast("unsigned short int", self.fbink_dump.area.width),
	           ffi.cast("unsigned short int", self.fbink_dump.area.height),
	           ffi.cast("unsigned short int", self.fbink_dump.area.left),
	           ffi.cast("unsigned short int", self.fbink_dump.area.top))
end

function NanoClock:restoreClockBackground()
	if not self.overlap_trick then
		return
	end

	--[[
	if self.fbink_state.is_ntx_quirky_landscape then
		return
	end
	--]]

	logger.dbg("Restoring clock bg")
	-- NOTE: FBInk will complain if we restore without a dump first (harmless)
	self.fbink_cfg.no_refresh = true
	FBInk.fbink_restore(self.fbink_fd, self.fbink_cfg, self.fbink_dump)
	self.fbink_cfg.no_refresh = false
end

function NanoClock:displayClock()
	if not self:prepareClock() then
		-- The clock was stopped, we're done
		logger.dbg("Clock is stopped")
		return
	end

	-- Finally, do the thing ;).
	local ret
	if self.with_ot then
		ret = FBInk.fbink_print_ot(self.fbink_fd, self.clock_string, self.fbink_ot, self.fbink_cfg, nil)
	else
		ret = FBInk.fbink_print(self.fbink_fd, self.clock_string, self.fbink_cfg)
	end
	if ret < 0 then
		logger.warn("FBInk failed to display the string `%s`", self.clock_string)

		-- NOTE: On failure, FBInk's own marker will have incremented,
		--       but a failure means we'll potentially never have a chance to *ever* catch a damage event for it,
		--       depending on where in the chain of events the failure happened.
		--       (i.e., if it's actually the *ioctl* that failed, we *would* catch it,
		--       but any earlier and there won't be any ioctl at all, so no damage event for us ;)).
		-- In any case, we don't want to get stuck in a display loop in case of failures,
		-- so always resetting the damage tracking makes sense.
		-- We simply force a clock display when we successfully reload the config,
		-- allowing the user to recover if the failure stems from a config snafu...
	end

	-- Remember our marker to be able to ignore its damage event, otherwise we'd be stuck in an infinite loop ;).
	-- c.f., the whole logic in :waitForEvent().
	self.clock_marker = FBInk.fbink_get_last_marker()
	logger.dbg("Updated clock (marker: %u)", ffi.cast("unsigned int", self.clock_marker))
	-- Reset the damage tracker
	self.marker_found = false

	-- Remember our damage area (if necessary, in the same quirky rotated state as the actual ioctls),
	-- to detect if we actually need to repaint...
	self.fbink_last_rect = FBInk.fbink_get_last_rect(self.fbink_state.is_ntx_quirky_landscape)
	-- We might get an empty rectangle if the previous update failed,
	-- and we *never* want to store an empty rectangle in self.damage_area,
	-- because nothing can ever intersect with it, which breaks the area check ;).
	if self.fbink_last_rect.width > 0 and self.fbink_last_rect.height > 0 then
		self.clock_area.x = self.fbink_last_rect.left
		self.clock_area.y = self.fbink_last_rect.top
		self.clock_area.w = self.fbink_last_rect.width
		self.clock_area.h = self.fbink_last_rect.height
	end
end

function NanoClock:waitForEvent()
	local buf = ffi.new("char[4096]")
	local damage = ffi.new("mxcfb_damage_update")
	local exp = ffi.new("uint64_t[1]")

	self.pfds[0].fd = self.damage_fd
	self.pfds[0].events = C.POLLIN
	self.pfds[1].fd = self.inotify_fd
	self.pfds[1].events = C.POLLIN
	self.pfds[2].fd = self.clock_fd
	self.pfds[2].events = C.POLLIN

	while true do
		-- Try to watch the config file for changes (we need to check this on each iteration,
		-- because an unmount destroys the inotify watch).
		self:setupInotify()

		local poll_num = C.poll(self.pfds, 3, -1)

		if poll_num == -1 then
			local errno = ffi.errno()
			if errno ~= C.EINTR then
				self:die(string.format("poll: %s", C.strerror(errno)))
			end
		elseif poll_num > 0 then
			if bit.band(self.pfds[1].revents, C.POLLIN) ~= 0 then
				while true do
					local len = C.read(self.inotify_fd, buf, ffi.sizeof(buf))

					if len < 0 then
						local errno = ffi.errno()
						if errno == C.EAGAIN then
							-- Inotify kernel buffer drained, back to poll!
							break
						end

						if errno ~= C.EINTR then
							self:die(string.format("read: %s", C.strerror(errno)))
						end
					elseif len == 0 then
						-- Should never happen
						local errno = C.EPIPE
						self:die(string.format("read: %s", C.strerror(errno)))
					elseif len < ffi.sizeof("struct inotify_event") then
						-- Should *also* never happen ;p.
						local errno = C.EINVAL
						self:die(string.format("read: %s", C.strerror(errno)))
					else
						local ptr = buf
						while ptr < buf + len do
							local event = ffi.cast("const struct inotify_event*", ptr)

							-- NOTE: If we happened to watch multiple files,
							--       this is where we'd match event.wd against out own mapping in self.inotify_wd
							--       But we don't, so, always assume event.wd == self.inotify_wd[self.config_path]

							if bit.band(event.mask, C.IN_CLOSE_WRITE) ~= 0 then
								logger.dbg("Tripped IN_CLOSE_WRITE for wd %d (config's: %d)",
								           ffi.cast("int", event.wd),
								           ffi.cast("int", self.inotify_wd[self.config_path]))

								-- Blank the previous clock area to avoid overlapping displays
								if self.fbink_last_rect then
									FBInk.fbink_cls(self.fbink_fd, self.fbink_cfg, self.fbink_last_rect, self.fbink_state.is_ntx_quirky_landscape)
								end

								self:reloadConfig()
							end

							if bit.band(event.mask, C.IN_UNMOUNT) ~= 0 then
								logger.dbg("Tripped IN_UNMOUNT for wd %d (config's: %d)",
								           ffi.cast("int", event.wd),
								           ffi.cast("int", self.inotify_wd[self.config_path]))

								-- Flag the wd as destroyed by the system
								self.inotify_wd[self.config_path] = -1
							end

							if bit.band(event.mask, C.IN_IGNORED) ~= 0 then
								logger.dbg("Tripped IN_IGNORED for wd %d (config's: %d)",
								           ffi.cast("int", event.wd),
								           ffi.cast("int", self.inotify_wd[self.config_path]))

								-- Flag the wd as destroyed by the system
								self.inotify_wd[self.config_path] = -1
							end

							if bit.band(event.mask, C.IN_Q_OVERFLOW) ~= 0 then
								logger.warn("Tripped IN_Q_OVERFLOW")

								-- We only watch a single file, so, we don't really have anything to do, this just means we lost events.
							end

							-- Next event!
							ptr = ptr + ffi.sizeof("struct inotify_event") + event.len
						end
					end
				end
			end

			if bit.band(self.pfds[2].revents, C.POLLIN) ~= 0 then
				-- We don't actually care about the expiration count, so just read to clear the event
				C.read(self.clock_fd, exp, ffi.sizeof(exp[0]))

				self:handleFBInkReinit()
				self:restoreClockBackground()
				self:displayClock()
			end

			if bit.band(self.pfds[0].revents, C.POLLIN) ~= 0 then
				local overflowed = false

				while true do
					local len = C.read(self.damage_fd, damage, ffi.sizeof(damage))

					if len < 0 then
						local errno = ffi.errno()
						if errno == C.EAGAIN then
							-- Damage ring buffer drained, back to poll!
							break
						end

						if errno ~= C.EINTR then
							self:die(string.format("read: %s", C.strerror(errno)))
						end
					elseif len == 0 then
						-- Should never happen
						local errno = C.EPIPE
						self:die(string.format("read: %s", C.strerror(errno)))
					elseif len ~= ffi.sizeof(damage) then
						-- Should *also* never happen ;p.
						local errno = C.EINVAL
						self:die(string.format("read: %s", C.strerror(errno)))
					else
						-- Okay, check that we're iterating over a valid event.
						if damage.format == C.DAMAGE_UPDATE_DATA_V1_NTX or
						damage.format == C.DAMAGE_UPDATE_DATA_V1 or
						damage.format == C.DAMAGE_UPDATE_DATA_V2 then
							-- Track our own marker so we can *avoid* reacting to it,
							-- because that'd result in a neat infinite loop ;).
							if damage.data.update_marker == self.clock_marker then
								self.marker_found = true
							end

							-- If there was an overflow, we may *never* find our previous clock marker,
							-- so remember that so we can deal with it once we're caught up...
							-- (An overflow obviously implies that we've got a full queue ahead of us,
							-- i.e., queue_size == 63).
							if damage.overflow_notify > 0 then
								logger.notice("Damage event queue overflow! %d events have been lost!",
									ffi.cast("int", damage.overflow_notify))
								overflowed = true
							end

							if damage.queue_size > 1 then
								-- We'll never react to anything that isn't the final event in the queue.
								logger.dbg("Stale damage event (%d more ahead)!",
									ffi.cast("int", damage.queue_size - 1))
							else
								-- If we're at the end of the queue *after* an overflow,
								-- assume we actually caught our own marker,
								-- as it might have been lost.
								if overflowed then
									self.marker_found = true
									overflowed = false
								end

								-- Otherwise, check that it is *not* our own damage event,
								-- *and* that we previously *did* see ours...
								if self.marker_found and damage.data.update_marker ~= self.clock_marker then
									-- We need to handle potential changes in the framebuffer format/layout,
									-- because that could mean that the clock area we remember may now be stale...
									self:handleFBInkReinit()

									-- Then, that it actually drew over our clock...
									local update_area = Geom:new{
										x = damage.data.update_region.left,
										y = damage.data.update_region.top,
										w = damage.data.update_region.width,
										h = damage.data.update_region.height,
									}
									if update_area:intersectWith(self.clock_area) then
										-- We'll need to know if nightmode is currently enabled to do the same...
										if bit.band(damage.data.flags, C.EPDC_FLAG_ENABLE_INVERSION) ~= 0 then
											self.fbink_cfg.is_nightmode = true
										else
											self.fbink_cfg.is_nightmode = false
										end

										self:grabClockBackground()
										self:displayClock()
									else
										logger.dbg("No clock update necessary: damage rectangle %s does not intersect with the clock's %s",
											tostring(update_area), tostring(self.clock_area))
									end
								else
									logger.dbg("No clock update necessary: damage marker: %u vs. clock marker: %u (found: %s)",
											ffi.cast("unsigned int", damage.data.update_marker),
											ffi.cast("unsigned int", self.clock_marker),
											tostring(self.marker_found))
								end
							end
						else
							-- This should admittedly never happen...
							logger.warn("Invalid damage event (format: %d)!",
									ffi.cast("int", damage.format))
						end
					end
				end
			end
		end
	end
end

function NanoClock:main()
	self:init()
	self:initFBInk()
	self:initDamage()
	self:initInotify()
	self:initConfig()
	logger.info("Initialized NanoClock %s with FBInk %s", self.version, FBInk.fbink_version())

	-- Display the clock once on startup, so that we start with sane clock marker & area tracking
	self:displayClock()

	-- Main loop
	self:waitForEvent()

	self:fini()
end

function NanoClock:fini()
	if self.fbink_dump.data ~= nil then
		FBInk.fbink_free_dump_data(self.fbink_dump)
	end
	FBInk.fbink_close(self.fbink_fd)
	if self.damage_fd ~= -1 then
		C.close(self.damage_fd)
	end
	if self.inotify_fd ~= -1 then
		C.close(self.inotify_fd)
	end
	if self.clock_fd ~= -1 then
		C.close(self.clock_fd)
	end
	os.execute("rmmod mxc_epdc_fb_damage")
	C.closelog()
end

return NanoClock:main()
