#! /mnt/onboard/.adds/koreader/luajit
-- FIXME: Build & bundle LuaJIT, luafilesystem & FBInk ourselves.

--[[
	NanoClock: A persnickety clock for Kobo devices
	Inspired by @frostschutz's MiniClock <https://github.com/frostschutz/Kobo/tree/master/MiniClock>.

	Copyright (C) 2021 NiLuJe <ninuje@gmail.com>
	SPDX-License-Identifier: GPL-3.0-or-later
--]]

-- TODO: Shell wrapper to handle udev workarounds, wait_for_nickel & the Aura FW check
--       And, of course, the kernel module loading. Probably going to need a minimal cli fbink build to handle the PLATFORM detect.

-- FIXME: Log to syslog instead of using print & error.

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
local util = require("util")
local Geom = require("geometry")
local INIFile = require("inifile")
local FBInk = ffi.load("lib/libfbink.so.1.0.0")

local NanoClock = {
	temp_folder = "/tmp/NanoClock", -- FIXME: probably won't need that, we have lfs to handle stat calls.
	data_folder = "/usr/local/NanoClock",
	addon_folder = "/mnt/onboard/.adds/nanoclock",
	config_file = "nanoclock.ini",
	nickel_config = "/mnt/onboard/.kobo/Kobo/Kobo eReader.conf",

	-- State tracking
	damage_marker = 0,
	damage_area = Geom:new{x = 0, y = 0, w = math.huge, h = math.huge},
}

function NanoClock:init()
	-- Setup logging
	C.openlog("nanoclock", bit.band(C.LOG_CONS, C.LOG_PID, C.LOG_NDELAY), C.LOG_DAEMON)

	self.config_path = self.addon_folder .. "/" .. self.config_file

	-- If we don't have a custom config file, copy the defaults
	if C.access(self.config_path, C.F_OK) ~= 0 then
		self.defaults_path = self.data_folder .. "/etc/" .. self.config_file
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
		error("Failed to open the framebuffer, aborting . . .")
	end

	if FBInk.fbink_init(self.fbink_fd, self.fbink_cfg) < 0 then
		error("Failed to initialize FBInk, aborting . . .")
	end

	-- TODO: Do a state dump and store the platform to be able to lookup frontlight via sysfs on Mk. 7?
end

function NanoClock:initDamage()
	self.damage_fd = C.open("/dev/fbdamage", bit.bor(C.O_RDONLY, C.O_NONBLOCK, C.O_CLOEXEC))
	if self.damage_fd == -1 then
		error("Failed to open the fbdamage device, aborting . . .")
	end
end

function NanoClock:reloadConfig()
	-- TODO: ts check
	self.cfg = INIFile.parse(self.config_path)

	-- TODO: Honor config :D
end

function NanoClock:prepareClock()
	-- TODO: Actually honor settings ;p.
	self.clock_string = os.date("%X")
end

function NanoClock:displayClock()
	self:prepareClock()

	-- TODO: Actually honor settings ;p.
	FBInk.fbink_print(self.fbink_fd, self.clock_string, self.fbink_cfg)

	-- Remember our marker to be able to ignore its damage event, otherwise we'd be stuck in an infinite loop ;).
	self.damage_marker = FBInk.fbink_get_last_marker()

	-- Remember our damage area to detect if we actually need to repaint
	local rect = FBInk.fbink_get_last_rect()
	-- We might get an empty rectangle if the previous update failed,
	-- and we *never* want to store an empty rectangle in self.damage_area,
	-- because nothing can ever intersect with it, which breaks the area check ;).
	if rect.width > 0 and rect.height > 0 then
		self.damage_area.x = rect.left
		self.damage_area.y = rect.top
		self.damage_area.w = rect.width
		self.damage_area.h = rect.height
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
				error(string.format("poll: %s", C.strerror(errno)))
			end
		end

		if poll_num > 0 then
			if bit.band(pfd.revents, C.POLLIN) then
				local damage = ffi.new("mxcfb_damage_update")

				while true do
					local len = C.read(self.damage_fd, damage, ffi.sizeof(damage))

					if len < 0 then
						local errno = ffi.errno()
						if errno == C.EAGAIN then
							-- Damage ring buffer drained, back to poll!
							break
						end

						error(string.format("read: %s", C.strerror(errno)))
					end

					if len == 0 then
						-- Should never happen
						local errno = C.EPIPE;
						error(string.format("read: %s", C.strerror(errno)))
					end

					if len ~= ffi.sizeof(damage) then
						-- Should *also* never happen ;p.
						local errno = C.EINVAL;
						error(string.format("read: %s", C.strerror(errno)))
					end

					-- Okay, check that the damage event is actually valid...
					if damage.format == C.DAMAGE_UPDATE_DATA_V1_NTX or
					   damage.format == C.DAMAGE_UPDATE_DATA_V1 or
					   damage.format == C.DAMAGE_UPDATE_DATA_V2 then
						-- Then, check that it isn't our own damage event...
						if damage.data.update_marker ~= self.damage_marker then
							-- Then, that it actually drew over our clock...
							local update_area = Geom:new{
								x = damage.data.update_region.left,
								y = damage.data.update_region.top,
								w = damage.data.update_region.width,
								h = damage.data.update_region.height,
							}
							if update_area:intersectWith(self.damage_area) then
								print("Updating clock")
								self:displayClock()
							else
								print("No clock update required")
							end
						end
					else
						print("Invalid damage event!")
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

	self:reloadConfig()

	-- Main loop
	self:waitForEvent()

	self:fini()
end

function NanoClock:fini()
	FBInk.fbink_close(self.fbink_fd)
	C.close(self.damage_fd)
	C.closelog()
end

return NanoClock:main()
