local component = require("component")
local filesystem = require("filesystem")
local event = require("event")
local sides = require("sides")
local cfg = require("config")
local biometrics = require("biometrics")
local time = require("time")

local redstone = component.redstone
local emitter = component.dfc_emitter
local chat = component.chat_box


-- some variables

chat.setName("DFC")
local locked = false
local angry = false
local utcTime

local angrySide = sides.top

local log_path = "/dfc_log.txt"
local configPath = "/etc/dfc.cfg"

local config = {
    userBiometrics = {},
    allowedUsers = {
        ["highPetya"] = true,
        ["Kirby73"] = true,
        ["LasseTheBabo"] = true, -- maintenance and testing
        ["Val_MuMu"] = true,
        ["Zaknafarin"] = true
    }
}

cfg.load(configPath, config)


-- daingerus

local function setAngry(state)
    if state then
        redstone.setOutput(angrySide, 15)
    else
        redstone.setOutput(angrySide, 0)
    end
end


-- file stuff

if not filesystem.exists(log_path) then
    local handle = filesystem.open(log_path, "w")
    handle:close()
end

local log_file = filesystem.open(log_path, "a")


-- palantir

local function log(message)
    local year, month, day = time.getDate(utcTime)
    local hour, min, sec = time.getTime(utcTime)
    local log_info = string.format(
        "%02d:%02d:%02d %02d.%02d.%04d > %s",
        hour, min, sec, day, month, year, message
    )
    log_file:write(log_info .. "\n")
    print(log_info)
end


-- security checks

local function emergency(message)
    if not locked then
        log(message)
        log("emergency shutdown!")
        locked = true
        angry = false
        emitter.setActive(false)
        emitter.setInput(1) -- set power to 1 because idk dont set the power to high
    end
end

local function checkTime()
    local hour, min = time.getTime(utcTime)

    if hour % 4 == 0 and min < 10 then
        if not locked then
            emergency("WARNING: server restart")
        end
    end
end


-- split function for args

local function split(input)
    local result = {}
    for word in input:gmatch("%S+") do
        table.insert(result, word)
    end
    return result
end


local function doAuthorizedShit(username, message)
    local parts = split(message)

    if parts[1] == "#dfc" then
        local command = parts[2]
        local args = {}

        for i = 3, #parts do
            table.insert(args, parts[i])
        end

        if command == "on" then
            if locked then
                chat.say("DFC is still locked")
                chat.say("use #dfc unlock to unlock it")
            else
                chat.say("DFC on")
                emitter.setActive(true)
            end
        elseif command == "off" then
            chat.say("DFC off")
            emitter.setActive(false)
        elseif command == "power" then
            local value = tonumber(args[1])

            if args[1] == nil then
                chat.say("DFC emitter power: " .. emitter.getInput())
                return
            end

            if value then
                if value >= 1 and value <= 100 then
                    chat.say("Power set to " .. value)
                    emitter.setInput(value)
                else
                    chat.say("power must be between 0 and 100")
                end
            else
                chat.say("Invalid number")
            end
        elseif command == "unlock" then
            if locked then
                locked = false
                chat.say("DFC is now unlocked")
            else
                chat.say("DFC is already unlocked")
            end
        elseif command == "angry" then
            if angry then
                chat.say("DFC is already angry")
            else
                chat.say("verify your player id at the biometric scanner")
                local playerId = biometrics.readId()

                if not playerId then
                    chat.say("couldn't scan your id")
                    return
                else
                    if biometrics.contains(config.userBiometrics, playerId) then
                        log("WARNING: DFC is now in angry state!")
                        angry = true
                    else
                        chat.say("you don't have enough permissions to do that")
                        log("failed biometric verification")
                    end
                end
            end
        elseif command == "friendly" then
            if not angry then
                chat.say("DFC is already friendly")
            else
                angry = false
            end
        elseif command == "panic" then
            emergency(" DFC AZ-5 was triggered")
        else
            chat.say("Unknown command :(")
            chat.say("Here are some commands:")
            chat.say("#dfc on")
            chat.say("#dfc off")
            chat.say("#dfc power")
            chat.say("#dfc power 100  <- only goes 1-100")
            chat.say("#dfc unlock")
            chat.say("#dfc angry")
            chat.say("#dfc friendly")
            chat.say("#dfc panic")
        end

        log(username .. ": " .. message)
    end
end


-- don't try it

local args = {...}

if args then
    local arg = args[1]

    if arg == "list_players" then
        for i, id in ipairs(config.userBiometrics) do
            print("%d. = %s", i, id)
        end
    elseif arg == "add_player" then
        local id = biometrics.readId()
        biometrics.addPlayer(config.userBiometrics, id);
        cfg.saveConfig(configPath, config)
    elseif arg == "remove_player" then
        local id = biometrics.readId()
        biometrics.removePlayer(config.userBiometrics, id);
        cfg.saveConfig(configPath, config)
    end

    return
end


-- loop loop loop loop

while true do
    local _, _, username, message = event.pull(10, "chat_message")

    utcTime = time.getUnformattedTime()

    if config.allowedUsers[username] then
        doAuthorizedShit(username, message)
    end

    setAngry(angry)
    checkTime()
end
