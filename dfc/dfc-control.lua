local component = require("component")
local event = require("event")
local filesystem = require("filesystem")
local sides = require("sides")

local bio = require("biometrics")
local cfg = require("config")
local minitel = require("minitel")
local tele = require("tele")
local time = require("time")

local redstone = component.redstone
local emitter = component.dfc_emitter
local chat = component.chat_box


-- some variables

chat.setName("DFC")
local commandPrefix = "#dfc"
local angrySide = sides.bottom
local locked = false
local angry = false
local utcTime
local commands = {}

local allowedUsers = {
    ["Alexmaster75"] = true,
    ["highPetya"] = true,
    ["Kirby73"] = true,
    ["LasseTheBabo"] = true, -- dfc admin
    ["RedstoneParkour"] = true,
    ["Val_MuMu"] = true,
    ["Zaknafarin"] = true
}

local log_path = "/etc/dfc.log"
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

print("connecting to screen")
local screen, r = minitel.open("dfc-screen", 7000)

if not screen then
    print("unable to open connection: " .. r)
else
    print("connection established")
end


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
    tele.query(screen, "log", log_info)
end


-- security checks

local function emergency(message)
    if not locked then
        chat.say(message)
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

local function checkCryogel()
    if emitter.getCryogel() < 60000 then
        emergency("WARNING: cryogel low! check cryogel production")
    end
end


-- helping shit

local function split(input)
    local result = {}
    for word in input:gmatch("%S+") do
        table.insert(result, word)
    end
    return result
end

local function toBool(state)
    if state == "true" then
        return true
    elseif state == "false" then
        return false
    else
        return nil
    end
end


-- commands

commands["on"] = function()
    if locked then
        chat.say("DFC is still locked")
        chat.say("use " .. commandPrefix .. " unlock to unlock it")
    else
        chat.say("DFC on")
        emitter.setActive(true)
    end
end

commands["off"] = function()
    chat.say("DFC off")
    emitter.setActive(false)
end

commands["power"] = function(args)
    local value = tonumber(args[1])

    if value == nil then
        chat.say(string.format("use \"%s power [number]\" to set the power", commandPrefix))
    else
        if value >= 1 and value <= 100 then
            chat.say("Power set to " .. value)
            emitter.setInput(value)
        else
            chat.say("power must be between 0 and 100")
        end
    end
end

commands["unlock"] = function()
    if locked then
        locked = false
        chat.say("DFC is now unlocked")
    else
        chat.say("DFC is already unlocked")
    end
end

commands["angry"] = function(args)
    local state = toBool(args[1])

    if state == nil then
        chat.say(string.format("use \"%s angry [true or false]\" to set angry", commandPrefix))
        return
    end

    if state then
        if angry then
            chat.say("DFC is already angry")
        else
            chat.say("verify your player id at the biometric scanner")
            local playerId = bio.readId()

            if not playerId then
                log("failed biometric verification")
                chat.say("couldn't scan your id")
                return
            else
                if bio.contains(biometrics, playerId) then
                    local msg = "WARNING: DFC is now angry !"
                    log(msg)
                    chat.say(msg)
                    angry = true
                else
                    log("not enough permissions")
                    chat.say("you don't have enough permissions to do that")
                end
            end
        end
    else
        if not angry then
            chat.say("DFC is already friendly")
        else
            chat.say("DFC is now friendly")
            angry = false
        end
    end
end

commands["info"] = function()
    chat.say("Active: " .. tostring(emitter.isActive()))
    chat.say("Angry:  " .. tostring(angry))
    chat.say("Locked: " .. tostring(locked))
    chat.say("Power:  " .. tostring(emitter.getInput()))
end

commands["panic"] = function()
    emergency("DFC AZ-5 was triggered")
end

local function doAuthorizedShit(username, message)
    local parts = split(message)

    if parts[1] == commandPrefix then
        local command = parts[2]
        local args = {}

        for i = 3, #parts do
            table.insert(args, parts[i])
        end

        log(username .. ": " .. message)

        if commands[command] then
            commands[command](args)
        else
            chat.say("Unknown command :(")
            chat.say("Here are some commands:")

            local keys = {}
            for key in pairs(commands) do
                table.insert(keys, key)
            end
            table.sort(keys)

            for _, key in ipairs(keys) do
                chat.say(commandPrefix .. " " .. key)
            end
        end
    end
end


-- don't try it

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


-- loop loop loop loop

while true do
    utcTime = time.getUnformattedTime()
    local _, _, username, message = event.pull(10, "chat_message")

    if allowedUsers[username] then
        doAuthorizedShit(username, message)
    end

    setAngry(angry)
    checkTime()
    checkCryogel()
end
