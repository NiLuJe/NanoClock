--[[
	Minor helper functions to deal with the FBInk ffi bindings.

	Copyright (C) 2021 NiLuJe <ninuje@gmail.com>
	SPDX-License-Identifier: GPL-3.0-or-later
--]]

local ffi = require("ffi")
local C = ffi.C

require("ffi/fbink_h")

local fbink_util = {}

-- Convert a color name to a FG_COLOR_INDEX_T constant
function fbink_util.FGColor(name)

end

-- Convert a color name to a BG_COLOR_INDEX_T constant
function fbink_util.BGColor(name)

end

-- Convert a font name to a FONT_INDEX_T constant
function fbink_util.Font(name)

end

return fbink_util
