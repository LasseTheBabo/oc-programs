local component = require("component")
local event = require("event")
local reader = component.os_biometric

local biometrics = {}

function biometrics.readId()
    local _, _, playerId = event.pull(10, "bioReader")
    return playerId
end

function biometrics.contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function biometrics.addPlayer(list, id)
    if not biometrics.contains(list, id) then
        table.insert(list, id)
    end
end

function biometrics.removePlayer(list, id)
    for i, v in ipairs(list) do
        if v == id then
            table.remove(list, i)
        end
    end
end

return biometrics