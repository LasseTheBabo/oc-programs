local component = require("component")
local filesystem = require("filesystem")
local event = require("event")
local internet = require("internet")
local json = require("json")

local emitter = component.dfc_emitter
local chat = component.chat_box
chat.setName("DFC")


-- some variables

local allowedUsers = {
    ["highPetya"] = true,
    ["Kirby73"] = true,
    ["Mantoshka"] = true,
    ["LasseTheBabo"] = true, -- maintenance and testing
    ["Val_MuMu"] = true,
    ["Zaknafarin"] = true
}

local locked = false
local active = false
local last_active = false
local commands = {}

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

local function getTime()
    local handle = internet.request("https://time.now/developer/api/timezone/Europe/Berlin")
    local result = ""
    for chunk in handle do
        result = result..chunk
    end

    local data = json.decode(result)
    return data.utc_datetime
end


-- palantir

local function log(log_info)
    log_file:write(log_info .. "\n")
    print(log_info)
end


function doAuthorizedShit(username , message)
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

        local log_info = getTime() .. " > " .. username .. ": " .. message
        log(log_info)
    end
end


-- loop loop loop loop

while true do
    local _, _, username, message = event.pull(300, "chat_message") -- 30 seconds timeout -> time check is only every 30 seconds

    if allowedUsers[username] then
        doAuthorizedShit(username, message)
    end

    local time = getTime()
    local hour, min = string.match(time, "T(%d%d):(%d%d)")
    hour, min = tonumber(hour), tonumber(min)

    if hour % 4 == 0 and min < 10 then
        print("DFC shutdown because of server restart")
        if not locked then
            locked = true
            emitter.setActive(false)
            emitter.setInput(1) -- set power to 1 because idk dont set the power to high
        end
    end
end
