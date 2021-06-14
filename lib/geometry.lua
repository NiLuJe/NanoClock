-- Pilfered from KOReader <https://github.com/koreader/koreader/blob/master/frontend/ui/geometry.lua>
-- SPDX-License-Identifier: AGPL-3.0-or-later

--[[--
2D Geometry utilities

All of these apply to full rectangles:

    local Geom = require("ui/geometry")
    Geom:new{ x = 1, y = 0, w = Screen:scaleBySize(100), h = Screen:scaleBySize(200), }

Some behaviour is defined for points:

    Geom:new{ x = 0, y = 0, }

Some behaviour is defined for dimensions:

    Geom:new{ w = 600, h = 800, }

Just use it on simple tables that have x, y and/or w, h
or define your own types using this as a metatable.
]]

--[[--
Represents a full rectangle (all fields are set), a point (x & y are set), or a dimension (w & h are set).
@table Geom
]]
local Geom = {
    x = 0, -- left origin
    y = 0, -- top origin
    w = 0, -- width
    h = 0, -- height
}

function Geom:new(o)
    if not o then o = {} end
    setmetatable(o, self)
    self.__index = self
    return o
end

--[[--
Makes a deep copy of itself.
@treturn Geom
]]
function Geom:copy()
    local n = Geom:new()
    n.x = self.x
    n.y = self.y
    n.w = self.w
    n.h = self.h
    return n
end

function Geom:__tostring()
    return self.w.."x"..self.h.."+"..self.x.."+"..self.y
end

--[[--
Returns area of itself.

@treturn int
]]
function Geom:area()
    if not self.w or not self.h then
        return 0
    else
        return self.w * self.h
    end
end

--[[--
Returns true if self does not share any area with rect_b

@tparam Geom rect_b
]]
function Geom:notIntersectWith(rect_b)
    if not rect_b or rect_b:area() == 0 then return true end

    if (self.x >= (rect_b.x + rect_b.w))
    or (self.y >= (rect_b.y + rect_b.h))
    or (rect_b.x >= (self.x + self.w))
    or (rect_b.y >= (self.y + self.h)) then
        return true
    end
    return false
end

--[[--
Returns true if self geom shares area with rect_b.

@tparam Geom rect_b
]]
function Geom:intersectWith(rect_b)
    return not self:notIntersectWith(rect_b)
end

--[[--
Checks whether geom is within current rectangle

Works for dimensions, too. For points, it is basically an equality check.

@tparam Geom geom
]]
function Geom:contains(geom)
    if not geom then return false end

    if self.x <= geom.x
    and self.y <= geom.y
    and self.x + self.w >= geom.x + geom.w
    and self.y + self.h >= geom.y + geom.h
    then
        return true
    end
    return false
end

--[[--
Checks for equality.

Works for rectangles, points, and dimensions.

@tparam Geom rect_b
]]
function Geom:__eq(rect_b)
    if self.x == rect_b.x
    and self.y == rect_b.y
    and self:equalSize(rect_b)
    then
        return true
    end
    return false
end

--[[--
Checks the size of a dimension/rectangle for equality.

@tparam Geom rect_b
]]
function Geom:equalSize(rect_b)
    if self.w == rect_b.w and self.h == rect_b.h then
        return true
    end
    return false
end

--[[--
Checks if our size is smaller than the size of the given dimension/rectangle.

@tparam Geom rect_b
]]
function Geom:__lt(rect_b)
    if self.w < rect_b.w and self.h < rect_b.h then
        return true
    end
    return false
end

--[[--
Checks if our size is smaller or equal to the size of the given dimension/rectangle.
@tparam Geom rect_b
]]
function Geom:__le(rect_b)
    if self.w <= rect_b.w and self.h <= rect_b.h then
        return true
    end
    return false
end

--[[--
Resets an existing Geom object to zero.
@treturn Geom
]]
function Geom:clear()
    self.x = 0
    self.y = 0
    self.w = 0
    self.h = 0
    return self
end

--[[--
Checks if a dimension or rectangle is empty.
@treturn bool
]]
function Geom:isEmpty()
    if self.w == 0 or self.h == 0 then
        return true
    end
    return false
end

return Geom
