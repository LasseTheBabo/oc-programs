local component = require("component")
local event = require("event")
local os = require("os")

local bio = require("biometrics")
local cfg = require("config")

local biometricsPath = "/etc/biometrics.txt"
local biometrics = {}

do
    local s, r = cfg.loadConfig(biometricsPath, biometrics)
    if not s then
        print(r)
        print("creating empty biometrics file")
    end
end
cfg.saveConfig(biometricsPath, biometrics)

local args = { ... }

if args then
    local arg = args[1]

    if arg == "list_players" then
        for i, id in ipairs(biometrics) do
            print(string.format("%d. = %s", i, id))
        end
        return
    elseif arg == "add_player" then
        local id = bio.readId()
        bio.addPlayer(biometrics, id);
        cfg.saveConfig(biometricsPath, biometrics)
        return
    elseif arg == "remove_player" then
        local id = bio.readId()
        bio.removePlayer(biometrics, id);
        cfg.saveConfig(biometricsPath, biometrics)
        return
    end
end

while true do
    local _, _, playerId = event.pull(0.05, "bioReader")

    if component.redstone.getInput(5) ~= 0 then 
        component.os_door.open()
    elseif playerId then
        if bio.contains(biometrics, playerId) then
            component.os_door.open()
            os.sleep(1)
        end
    else
        component.os_door.close()
    end
end