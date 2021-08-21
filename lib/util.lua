-- Pilfered from KOReader <https://github.com/koreader/koreader-base/blob/master/ffi/util.lua>
-- SPDX-License-Identifier: AGPL-3.0-or-later

local lfs = require("lfs")

local util = {}

--- Copies file.
function util.copyFile(from, to)
	local ffp, err = io.open(from, "rb")
	if err ~= nil then
		return err
	end
	local tfp = io.open(to, "wb")
	while true do
		local bytes = ffp:read(4096)
		if not bytes then
			ffp:close()
			break
		end
		tfp:write(bytes)
	end
	tfp:close()
end

--- mkdir -p
function util.makePath(path)
	local parent = path:sub(1, 1) == "/" and "/" or ""
	for component in path:gmatch("[^/]+") do
		parent = parent .. component .. "/"
		lfs.mkdir(parent)
	end
end

--- Read single-line files (e.g., sysfs)
function util.readFileAsNumber(file)
	local fd = io.open(file, "r")
	if fd then
		local int = fd:read("*number")
		fd:close()
		return int or 0
	else
		return 0
	end
end

function util.readFileAsString(file)
	local fd = io.open(file, "r")
	if fd then
		local str = fd:read("*line")
		fd:close()
		return str
	else
		return ""
	end
end

-- pairs(), but with *keys* sorted alphabetically.
-- c.f., http://lua-users.org/wiki/SortedIteration
-- See also http://lua-users.org/wiki/SortedIterationSimple
local function __genOrderedIndex(t)
	local orderedIndex = {}
	for key in pairs(t) do
		table.insert(orderedIndex, key)
	end
	table.sort(orderedIndex)
	return orderedIndex
end

local function orderedNext(t, state)
	-- Equivalent of the next function, but returns the keys in the alphabetic order.
	-- We use a temporary ordered key table that is stored in the table being iterated.

	local key = nil
	--print("orderedNext: state = "..tostring(state) )
	if state == nil then
		-- the first time, generate the index
		t.__orderedIndex = __genOrderedIndex(t)
		key = t.__orderedIndex[1]
	else
		-- fetch the next value
		for i = 1, #t.__orderedIndex do
			if t.__orderedIndex[i] == state then
				key = t.__orderedIndex[i+1]
			end
		end
	end

	if key then
		return key, t[key]
	end

	-- no more value to return, cleanup
	t.__orderedIndex = nil
	return
end

function util.orderedPairs(t)
	-- Equivalent of the pairs() function on tables. Allows to iterate in order
	return orderedNext, t, nil
end

-- c.f., Version:getNormalizedVersion @ <https://github.com/koreader/koreader/blob/master/frontend/version.lua>
function util.getNormalizedVersion(nickel_ver)
	local major, minor, build = nickel_ver:match("(%d+)%.(%d+)%.?(%d*)")

	major = tonumber(major) or 0
	minor = tonumber(minor) or 0
	build = tonumber(build) or 0

	return major * 1000000000 + minor * 1000000 + build
end

return util
