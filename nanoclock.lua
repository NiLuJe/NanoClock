#! ./bin/luajit
-- FIXME: Build & bundle LuaJIT, luafilesystem & FBInk ourselves.

--[[
	NanoClock: A persnickety clock for Kobo devices
	Inspired by @frostschutz's MiniClock <https://github.com/frostschutz/Kobo/tree/master/MiniClock>.

	Copyright (C) 2021 NiLuJe <ninuje@gmail.com>
	SPDX-License-Identifier: GPL-3.0-or-later
--]]

-- TODO: Shell wrapper to handle udev workarounds, wait_for_nickel & the Aura FW check
--       And, of course, the kernel module loading.
--       Probably going to need a minimal cli fbink build to handle the PLATFORM detect.
local bit = require("bit")
local ffi = require("ffi")
local C = ffi.C

require("ffi/fbink_h")
require("ffi/mxcfb_damage_h")
require("ffi/posix_h")
-- TODO: nightmode flag detection
require("ffi/mxcfb_h")

-- Mangle package search paths to sart looking inside lib/ first...
package.path =
    "lib/?.lua;" ..
    package.path
package.cpath =
    "lib/?.so;" ..
    package.cpath

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
	if C.access(self.config_path, C.F_OK) ~= 0 then
		if C.access(self.defaults_path, C.F_OK) ~= 0 then
			self:die("Default config file is missing, aborting!")
		end

		util.copyFile(self.defaults_path, self.config_path)
	end
end

function NanoClock:initFBInk()
	self.fbink_cfg = ffi.new("FBInkConfig")

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

	-- TODO: Do a state dump and store the platform to be able to lookup frontlight via sysfs on Mk. 7?
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
		return
	end

	if config_mtime == self.config_mtime then
		-- No change, we're done
		return
	else
		self.config_mtime = config_mtime
	end

	logger.notice("Config file was modified, reloading it")
	self.cfg = INIFile.parse(self.config_path)
	self:sanitizeConfig()
	self:handleConfig()

	-- Force a clock refresh, to be able to recover from config-induced display failures...
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
	-- Was debug logging requested?
	if self.cfg.global.debug == 0 then
		logger:setLevel(logger.levels.info)
	else
		logger:setLevel(logger.levels.dbg)
	end

	-- TODO: Honor config :D
end

function NanoClock:prepareClock()
	-- Check if the config has been updated, and reload it if necessary...
	self:reloadConfig()

	-- TODO: Actually honor settings ;p.
	self.clock_string = os.date("%X")
end

function NanoClock:displayClock()
	self:prepareClock()

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

	-- TODO: Actually honor settings ;p.
	local ret = FBInk.fbink_print(self.fbink_fd, self.clock_string, self.fbink_cfg)
	if ret < 0 then
		logger.warn("FBInk failed to display the string `%s`", self.clock_string)

		-- NOTE: On failure, FBInk's own marker will have incremented,
		--       but a failure means we'll potentially never have a chance to *ever* catch a damage event for it,
		--       depending on where in the chain of events the failure happened.
		--       (i.e., if it's actually the *ioctl* that failed, we *would* catch it,
		--       but any earlier and there won't be any ioctl at all, so no damage event for us ;)).
		-- In any case, we don't want to get stuck in a display loop in case of failures,
		-- so always resetting the damage tracking makes sense.
		-- We simply force a clock display when we reload the config,
		-- allowing to user to recover if the failure stems from a config snafu...
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
	local pfd = ffi.new("struct pollfd")
	pfd.fd = self.damage_fd
	pfd.events = C.POLLIN

	while true do
		local poll_num = C.poll(pfd, 1, -1);

		if poll_num == -1 then
			local errno = ffi.errno()
			if errno ~= C.EINTR then
				self:die(string.format("poll: %s", C.strerror(errno)))
			end
		end

		if poll_num > 0 then
			if bit.band(pfd.revents, C.POLLIN) then
				local damage = ffi.new("mxcfb_damage_update")
				local overflowed = false

				while true do
					local len = C.read(self.damage_fd, damage, ffi.sizeof(damage))

					if len < 0 then
						local errno = ffi.errno()
						if errno == C.EAGAIN then
							-- Damage ring buffer drained, back to poll!
							break
						end

						self:die(string.format("read: %s", C.strerror(errno)))
					end

					if len == 0 then
						-- Should never happen
						local errno = C.EPIPE;
						self:die(string.format("read: %s", C.strerror(errno)))
					end

					if len ~= ffi.sizeof(damage) then
						-- Should *also* never happen ;p.
						local errno = C.EINVAL;
						self:die(string.format("read: %s", C.strerror(errno)))
					end

					-- Okay, check that weiterating over a valid event.
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
						if damage.overflow_notify > 0 then
							logger.notice("Damage event queue overflow! %d events have been lost!",
							              ffi.cast("int", damage.overflow_notify))
							overflowed = true
						end

						if damage.queue_size > 1 then
							-- We'll never react to anything that isn't the final event in the queue.
							logger.warn("Stale damage event (%d more ahead)!",
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
									self:displayClock()
								else
									logger.dbg("No clock update necessary: %s does not intersect with %s",
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
						logger.warn("Invalid damage event (format: %d)!",
								ffi.cast("int", damage.format))
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

	-- Display the clock once on startup, so that we start with a sane clock marker & area
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
