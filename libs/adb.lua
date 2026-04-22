local component = require("component")

local adb = {}

function adb.set(filter)
    local filteredList = component.list(filter)
    
end

return adb