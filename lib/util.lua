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

return util
