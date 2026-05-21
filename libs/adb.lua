local component = require("component")
local event = require("event")
local os = require("os")

-- Address DataBase
-- not Android Debug Bridge

local adb = {}

function adb.waitForNewAddress(filter)
    while true do
        local _, address, type = event.pull("component_added")

        if not filter or type == filter then
            return address
        end
    end
end

return adb