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

	-- State tracking
	clock_marker = 0,
	marker_found = false,
	clock_area = Geom:new{x = 0, y = 0, w = math.huge, h = math.huge},
	config_mtime = 0,
	print_failed = false,
	nickel_mtime = 0,
	fl_brightness = "??",

	-- I18N stuff
	en_days = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" },
	en_months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" },
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

	-- Enable logging to syslog ASAP
	self.fbink_cfg.is_verbose = false
	self.fbink_cfg.is_quiet = true
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
	local state = ffi.new("FBInkState")
	FBInk.fbink_get_state(self.fbink_cfg, state)
	self.device_name = ffi.string(state.device_name)
	self.device_codename = ffi.string(state.device_codename)
	self.device_platform = ffi.string(state.device_platform)
	self.device_id = state.device_id
	self.can_hw_invert = state.can_hw_invert
end

function NanoClock:initDamage()
	self.damage_fd = C.open("/dev/fbdamage", bit.bor(C.O_RDONLY, C.O_NONBLOCK, C.O_CLOEXEC))
	if self.damage_fd == -1 then
		self:die("Failed to open the fbdamage device, aborting!")
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
	self.config_mtime = config_mtime

	-- Start by loading the defaults...
	self.defaults = INIFile.parse(self.defaults_path)
	-- Then the user config...
	self.cfg = INIFile.parse(self.config_path)

	self:sanitizeConfig()

	self:handleConfig()
end

function NanoClock:reloadConfig()
	-- Reload the config if it was modified since the last time we parsed it...
	local config_mtime = lfs.attributes(self.config_path, "modification")
	if not config_mtime then
		-- Can't find the config file, is onboard currently unmounted? (USBMS?)
		-- In any case, nothing more to do here ;).
		return false
	end

	if config_mtime == self.config_mtime then
		-- No change, we're done
		return false
	else
		self.config_mtime = config_mtime
	end

	logger.notice("Config file was modified, reloading it")
	self.cfg = INIFile.parse(self.config_path)
	self:sanitizeConfig()
	self:handleConfig()

	return true
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

		self.days_map = {}
		for k, v in ipairs(self.en_days) do
			self.days_map[k] = user_days[k] or v
		end
	end

	if self.cfg.display.months ~= nil then
		local user_months = {}
		for month in self.cfg.display.months:gmatch("%S+") do
			table.insert(user_months, month)
		end

		self.months_map = {}
		for k, v in ipairs(self.en_months) do
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
end

function NanoClock:getFrontLightLevel()
	-- We can poke sysfs directly on Mark 7
	if self.device_platform == "Mark 7" then
		local brightness = util.readFileAsNumber("/sys/class/backlight/mxc_msp430.0/actual_brightness")
		return tostring(brightness) .. "%"
	else
		-- Otherwise, we have to look inside Nickel's config...
		-- Avoid parsing it again if it hasn't changed, like :reloadConfig()
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
	local gauge = util.readFileAsNumber(self.cfg.display.battery_source)
	if gauge >= self.cfg.display.battery_min and gauge <= self.cfg.display.battery_max then
		return tostring(gauge) .. "%"
	else
		return ""
	end
end

function NanoClock:getUserDay()
	local k = tonumber(os.date("%u"))
	if not self.days_map then
		return self.en_days[k]
	end

	return self.days_map[k]
end

function NanoClock:getUserMonth()
	local k = tonumber(os.date("%m"))
	if not self.months_map then
		return self.en_months[k]
	end

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
	-- Check if the config has been updated, and reload it if necessary...
	self:reloadConfig()

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

function NanoClock:displayClock()
	if not self:prepareClock() then
		-- The clock was stopped, we're done
		logger.dbg("Clock is stopped")
		return
	end

	-- We need to handle potential changes in the framebuffer format/layout...
	local reinit = FBInk.fbink_reinit(self.fbink_fd, self.fbink_cfg)
	if reinit > 0 then
		if bit.band(reinit, C.OK_BPP_CHANGE) then
			logger.notice("Handled a framebuffer bitdepth change")
		end

		if bit.band(reinit, C.OK_LAYOUT_CHANGE) then
			logger.notice("Handled a framebuffer orientation change")
		elseif bit.band(reinit, C.OK_ROTA_CHANGE) then
			logger.notice("Handled a framebuffer rotation change")
		end
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
		self.print_failed = true
	else
		self.print_failed = false
	end

	-- Remember our marker to be able to ignore its damage event, otherwise we'd be stuck in an infinite loop ;).
	-- c.f., the whole logic in :waitForEvent().
	self.clock_marker = FBInk.fbink_get_last_marker()
	logger.dbg("Updated clock (marker: %u)", ffi.cast("unsigned int", self.clock_marker))
	-- Reset the damage tracker
	self.marker_found = false

	-- Remember our damage area to detect if we actually need to repaint
	local rect = FBInk.fbink_get_last_rect()
	-- We might get an empty rectangle if the previous update failed,
	-- and we *never* want to store an empty rectangle in self.damage_area,
	-- because nothing can ever intersect with it, which breaks the area check ;).
	if rect.width > 0 and rect.height > 0 then
		self.clock_area.x = rect.left
		self.clock_area.y = rect.top
		self.clock_area.w = rect.width
		self.clock_area.h = rect.height
	end
end

function NanoClock:waitForEvent()
	local damage = ffi.new("mxcfb_damage_update")

	local pfd = ffi.new("struct pollfd")
	pfd.fd = self.damage_fd
	pfd.events = C.POLLIN

	while true do
		local poll_num = C.poll(pfd, 1, -1)

		if poll_num == -1 then
			local errno = ffi.errno()
			if errno ~= C.EINTR then
				self:die(string.format("poll: %s", C.strerror(errno)))
			end
		elseif poll_num > 0 then
			if bit.band(pfd.revents, C.POLLIN) ~= 0 then
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

									-- Do attempt to recover from print failures, in case they stem from a config issue...
									-- NOTE: This would be mildly less icky if we tracked config updates via inotify,
									--       in which case we'd just have to stick a :displayClock() at the end of :reloadConfig() ;).
									if self.print_failed then
										if self:reloadConfig() then
											logger.notice("Previous clock update failed, but config was modified since, trying again")
											self:displayClock()
										end
									end
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
	self:initConfig()
	logger.info("Initialized NanoClock %s with FBInk %s", self.version, FBInk.fbink_version())

	-- Display the clock once on startup, so that we start with sane clock marker & area tracking
	self:displayClock()

	-- Main loop
	self:waitForEvent()

	self:fini()
end

function NanoClock:fini()
	if self.fbink_fd then
		FBInk.fbink_close(self.fbink_fd)
	end
	if self.damage_fd and self.damage_fd ~= -1 then
		C.close(self.damage_fd)
	end
	os.execute("rmmod mxc_epdc_fb_damage")
	C.closelog()
end

return NanoClock:main()
