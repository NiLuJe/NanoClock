-- Pilfered from KOReader <https://github.com/koreader/koreader-base/blob/master/ffi/util.lua>
-- SPDX-License-Identifier: AGPL-3.0-or-later

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

--- Read single-line files (e.g., sysfs)
function util.read_int_file(file)
    local fd = io.open(file, "r")
    if fd then
        local int = fd:read("*number")
        fd:close()
        return int or 0
    else
        return 0
    end
end

function util.read_str_file(file)
    local fd = io.open(file, "r")
    if fd then
        local str = fd:read("*line")
        fd:close()
        return str
    else
        return ""
    end
end

return util
