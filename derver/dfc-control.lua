local component = require("component")
local filesystem = require("filesystem")
local event = require("event")
local internet = require("internet")
local json = require("json")
local sides = require("sides")
local computer = require("computer")

local redstone = component.redstone
local emitter = component.dfc_emitter
local chat = component.chat_box


-- some variables

local 

chat.setName("DFC")
local locked = false
local angry = false
local active = false
local commands = {}

local angrySide = sides.top

local time

local log_path = "/dfc_log.txt"
local configPath = "/etc/dfc.cfg"

local config = {
    userBiometrics = {}
    allowedUsers = {
        ["highPetya"] = true,
        ["Kirby73"] = true,
        ["LasseTheBabo"] = true, -- maintenance and testing
        ["Val_MuMu"] = true,
        ["Zaknafarin"] = true
    }
}


-- file stuff

if not filesystem.exists(log_path) then
    local handle = filesystem.open(log_path, "w")
    handle:close()
end

local log_file = filesystem.open(log_path, "a")


local function saveConfig()
    local h, r = io.open(configPath, "wb")
    if not h then return false, "unable to open config: "..r end
    h:write(serialization.serialize(config, true))
    h:close()
    return true
end

local function mergeRecursive(t, from)
    for k, v in pairs(from) do
        if type(v) == "table" and type(t[k]) == "table" then
            mergeRecursive(t[k], v)
        else
            t[k] = v
        end
    end
end

local function loadConfig()
    local h, r = io.open(configPath, "rb")
    if not h then return false, "unable to open config: "..r end
    local data = h:read("*a")
    h:close()
    local cfg, r = serialization.unserialize(data)
    if not cfg then return false, "unable to unserialize config: "..r end
    mergeRecursive(config, cfg)
    return true
end

do local s, r = loadConfig()
    if not s then
        print(r)
        print("using default config")
    end
end
saveConfig()

-- daingerus




-- commands after "#dfc"

commands["on"] = function()
    if locked then
        chat.say("DFC is still locked")
        chat.say("use #dfc unlock to unlock it")
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

commands["unlock"] = function()
    if locked then
        locked = false
        chat.say("DFC is now unlocked")
    else
        chat.say("DFC is already unlocked")
    end
end

commands["angry"] = function()
    if angry then
        chat.say("DFC is already angry")
    else
        chat.say("verify yourself at the biometric scanner")
        
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
        else
            chat.say("Unknown command :(")
            chat.say("Here are some commands:")
            chat.say("#dfc on")
            chat.say("#dfc off")
            chat.say("#dfc power")
            chat.say("#dfc power 100  <- only goes 1-100")
            chat.say("#dfc unlock")
            chat.say("#dfc angry")
        end

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

local function emergency(message)
    if not locked then
        log(message)
        log("emergency shutdown!")
        locked = true
        emitter.setActive(false)
        emitter.setInput(1) -- set power to 1 because idk dont set the power to high
    end
end

local function checkTime()
    local hour, min = getTime()

    if hour % 4 == 0 and min < 10 then
        if not locked then
            emergency("WARNING: server restart")
        end
    end
end


-- loop loop loop loop

while true do
    local _, _, username, message = event.pull(10, "chat_message") -- 100 or 10 seconds timeout? -> time check is only every 30 seconds

    time = getUnformattedTime()
    active = emitter.isActive()

    if config.allowedUsers[username] then
        doAuthorizedShit(username, message)
    end

    checkTime()
end
