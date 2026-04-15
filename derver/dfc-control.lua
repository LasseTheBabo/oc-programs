local component = require("component")
local filesystem = require("filesystem")
local event = require("event")
local internet = require("internet")
local json = require("json")
local sides = require("sides")

local redstone = component.redstone
local tank = component.ntm_fluid_tank
local emitter = component.dfc_emitter
local chat = component.chat_box


-- some variables

local allowedUsers = {
    ["highPetya"] = true,
    ["Kirby73"] = true,
    ["Mantoshka"] = true,
    ["LasseTheBabo"] = true, -- maintenance and testing
    ["Val_MuMu"] = true,
    ["Zaknafarin"] = true
}

chat.setName("DFC")
local sirenSide = sides.top -- independent of direction
local cryoShutdownThreshold = 0.9 -- cryogel level should even be under 90%
local aliveTime = computer.uptime()
local aliveThreshold = 60 -- time after dfc shuts down in seconds
local locked = false
local active = false
local last_active = false
local commands = {}

local time

local log_path = "/dfc_log.txt"


-- log file stuff

if not filesystem.exists(log_path) then
    local handle = filesystem.open(log_path, "w")
    handle:close()
end

local log_file = filesystem.open(log_path, "a")


-- commands after "#dfc"

commands["on"] = function()
    if locked then
        chat.say("DFC is still locked after server restart")
        chat.say("use #dfc auth to unlock it")
    else
        chat.say("DFC on")
        active = true
    end
end

commands["off"] = function()
    chat.say("DFC off")
    active = false
end

commands["power"] = function(args)
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
end

commands["auth"] = function()
    if locked then
        locked = false
        chat.say("DFC is now unlocked")
    else
        chat.say("DFC is already unlocked")
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


-- some real time shit

local function getUnformattedTime()
    local handle = internet.request("https://time.now/developer/api/timezone/Europe/Berlin")
    local result = ""
    for chunk in handle do
        result = result..chunk
    end

    local data = json.decode(result)
    return data.utc_datetime
end

local function getDate()
    local year, month, day = string.match(time, "(%d%d%d%d)%-(%d%d)%-(%d%d)")
    
    return tonumber(year), tonumber(month), tonumber(day)
end

local function getTime()
    local hour, min, sec = string.match(time, "T(%d%d):(%d%d):(%d%d)")
    
    return tonumber(hour), tonumber(min), tonumber(sec)
end


-- palantir

local function log(log_info)
    log_file:write(log_info .. "\n")
    print(log_info)
end


function doAuthorizedShit(username, message)
    local parts = split(message)

    if parts[1] == "#dfc" then

        local command = parts[2]
        local args = {}

        for i = 3, #parts do
            table.insert(args, parts[i])
        end

        if commands[command] then
            commands[command](args)
            emitter.setActive(active)
        else
            chat.say("Unknown command :(")
            chat.say("Here are some commands:")
            chat.say("#dfc on")
            chat.say("#dfc off")
            chat.say("#dfc power")
            chat.say("#dfc power 100  <- only goes 1-100")
            chat.say("#dfc auth")
            emitter.setActive(last_active)
        end

        last_active = active

        local year, month, day = getDate()
        local hour, min, sec = getTime()
        local log_info = string.format(
            "%02d:%02d:%02d %02d.%02d.%04d > %s: %s",
            hour, min, sec, day, month, year, username, message
        )
        
        log(log_info)
    end
end


-- security checks

local function siren(state)
    if state then
        redstone.setOutput(sirenSide, 15)
    else
        redstone.setOutput(sirenSide, 0)
    end
end

local function emergency()
    if not locked then
        log("emergency shutdown!")
        locked = true
        active = false
        emitter.setActive(false)
        emitter.setInput(1) -- set power to 1 because idk dont set the power to high
    end
end

local function checkTime()
    local hour, min = getTime()

    if hour % 4 == 0 and min < 10 then
        log("WARNING: server restart")
        emergency()
    end
end

local function checkCryogel()
    local max, stored = tank.getMaxStored(), tank.getFluidStored()
    local fillPercent = stored / max
    local toLow = fillPercent < cryoShutdownThreshold

    siren(toLow)

    if toLow then
        chat.say("WARNING: check cryogel production")
        emergency()
    end
end

local function checkAliveTime()
    if (aliveTime) + aliveThreshold < computer.uptime() then
	    aliveTime = computer.uptime()
        log("WARNING: DFC is already on for "..aliveTime.."! Shutting down...")
	end
end


-- loop loop loop loop

while true do
    time = getUnformattedTime()
    local _, _, username, message = event.pull(100, "chat_message") -- 100 or 10 seconds timeout? -> time check is only every 30 seconds

    if allowedUsers[username] then
        doAuthorizedShit(username, message)
    end

    checkTime()
    checkCryogel()
    checkAliveTime()
end
