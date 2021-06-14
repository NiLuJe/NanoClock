--[[
	Minor helper functions to deal with the FBInk ffi bindings.

	Copyright (C) 2021 NiLuJe <ninuje@gmail.com>
	SPDX-License-Identifier: GPL-3.0-or-later
--]]

local ffi = require("ffi")
local C = ffi.C

require("ffi/fbink_h")

local fbink_util = {}

local FG_COLOR = {
	BLACK = C.FG_BLACK,
	GRAY1 = C.FG_GRAY1,
	GRAY2 = C.FG_GRAY2,
	GRAY3 = C.FG_GRAY3,
	GRAY4 = C.FG_GRAY4,
	GRAY5 = C.FG_GRAY5,
	GRAY6 = C.FG_GRAY6,
	GRAY7 = C.FG_GRAY7,
	GRAY8 = C.FG_GRAY8,
	GRAY9 = C.FG_GRAY9,
	GRAYA = C.FG_GRAYA,
	GRAYB = C.FG_GRAYB,
	GRAYC = C.FG_GRAYC,
	GRAYD = C.FG_GRAYD,
	GRAYE = C.FG_GRAYE,
	WHITE = C.FG_WHITE,
}

-- Convert a color name to a FG_COLOR_INDEX_T constant
function fbink_util.FGColor(name)
	return FG_COLOR[name:upper()] or C.FG_BLACK
end

local BG_COLOR = {
	WHITE = C.BG_WHITE,
	GRAYE = C.BG_GRAYE,
	GRAYD = C.BG_GRAYD,
	GRAYC = C.BG_GRAYC,
	GRAYB = C.BG_GRAYB,
	GRAYA = C.BG_GRAYA,
	GRAY9 = C.BG_GRAY9,
	GRAY8 = C.BG_GRAY8,
	GRAY7 = C.BG_GRAY7,
	GRAY6 = C.BG_GRAY6,
	GRAY5 = C.BG_GRAY5,
	GRAY4 = C.BG_GRAY4,
	GRAY3 = C.BG_GRAY3,
	GRAY2 = C.BG_GRAY2,
	GRAY1 = C.BG_GRAY1,
	BLACK = C.BG_BLACK,
}
-- Convert a color name to a BG_COLOR_INDEX_T constant
function fbink_util.BGColor(name)
	return BG_COLOR[name:upper()] or C.BG_WHITE
end

local FONT = {
	IBM = C.IBM,
	UNSCII = C.UNSCII,
	UNSCII_ALT = C.UNSCII_ALT,
	UNSCII_THIN = C.UNSCII_THIN,
	UNSCII_FANTASY = C.UNSCII_FANTASY,
	UNSCII_MCR = C.UNSCII_MCR,
	UNSCII_TALL = C.UNSCII_TALL,
	BLOCK = C.BLOCK,
	LEGGIE = C.LEGGIE,
	VEGGIE = C.VEGGIE,
	KATES = C.KATES,
	FKP = C.FKP,
	CTRLD = C.CTRLD,
	ORP = C.ORP,
	ORPB = C.ORPB,
	ORPI = C.ORPI,
	SCIENTIFICA = C.SCIENTIFICA,
	SCIENTIFICAB = C.SCIENTIFICAB,
	SCIENTIFICAI = C.SCIENTIFICAI,
	TERMINUS = C.TERMINUS,
	TERMINUSB = C.TERMINUSB,
	FATTY = C.FATTY,
	SPLEEN = C.SPLEEN,
	TEWI = C.TEWI,
	TEWIB = C.TEWIB,
	TOPAZ = C.TOPAZ,
	MICROKNIGHT = C.MICROKNIGHT,
	VGA = C.VGA,
	UNIFONT = C.UNIFONT,
	UNIFONTDW = C.UNIFONTDW,
	COZETTE = C.COZETTE,
}

-- Convert a font name to a FONT_INDEX_T constant
function fbink_util.Font(name)
	return FONT[name:upper()] or C.IBM
end

return fbink_util
