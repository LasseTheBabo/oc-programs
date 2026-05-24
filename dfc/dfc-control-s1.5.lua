local component = require("component")
local computer = require("computer")
local filesystem = require("filesystem")
local sides = require("sides")

local chatCmd = require("chat-cmd")
local minitel = require("minitel")
local tele = require("tele")
local time = require("time")

local redstone = component.redstone
local emitter = component.dfc_emitter
local chat = chatCmd.chat


-- some variables

chat.setName("DFC")
local angrySide = sides.top
local locked = false
local angry = false
local commandPrefix = "#dfc"
local angryRequest = false
local log_path = "/etc/dfc.log"
local lastAngryCheck = 0

print("connecting to screen")
local screen, r = minitel.open("dfc-screen", 7000)

if not screen then
    print("unable to open connection: " .. r)
else
    print("connection established")
end

if not filesystem.exists(log_path) then
    local handle = filesystem.open(log_path, "w")
    handle:close()
end
local log_file = filesystem.open(log_path, "a")


function chatCmd.log(message)
    local year, month, day = time.getDate(chatCmd.utcTime)
    local hour, min, sec = time.getTime(chatCmd.utcTime)
    local log_info = string.format(
        "%02d:%02d:%02d %02d.%02d.%04d > %s",
        hour + 2, min, sec, day, month, year, message -- (UCT+2) fuck everyone who doesn't use european summer time
    )
    log_file:write(log_info .. "\n")
    print(log_info)
    if screen then
        tele.query(screen, "log", log_info)
    end
end

chatCmd.allowedUsers = {
    ["Alexmaster75"] = true,
    ["LasseTheBabo"] = true,
    ["RedstoneParkour"] = true,
    ["Val_MuMu"] = true,
}

local angryUsers = {
    ["LasseTheBabo"] = true,
    ["Val_MuMu"] = true,
}

chatCmd.deniedUsers = {
    ["Mrtoaster_12"] = true,
    ["Zaknafarin"] = true,
}

chatCmd.denyMessage = "fuck nah you won't turn on this shitbox"


local function emergency(message)
    if not locked then
        chat.say(message)
        chatCmd.log(message)
        chatCmd.log("emergency shutdown!")
        locked = true
        angry = false
        emitter.setActive(false)
        emitter.setInput(1) -- set power to 1 because idk dont set the power to high
    end
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


chatCmd.commands = {
    [commandPrefix] = {
        ["on"] = function()
            if locked then
                chat.say("DFC is still locked")
                chat.say("use " .. commandPrefix .. " unlock to unlock it")
            else
                chat.say("DFC on")
                emitter.setActive(true)
            end
        end,

        ["off"] = function()
            chat.say("DFC off")
            emitter.setActive(false)
        end,

        ["power"] = function(args)
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
        end,

        ["unlock"] = function()
            if locked then
                locked = false
                chat.say("DFC is now unlocked")
            else
                chat.say("DFC is already unlocked")
            end
        end,

        ["angry"] = function(args)
            local state = toBool(args[1])

            if state == nil then
                chat.say(string.format("use \"%s angry [true or false]\" to set angry", commandPrefix))
                return
            end

            if state then
                if angry then
                    chat.say("DFC is already angry")
                else
                    chat.say(string.format("confirm the angry request with \"%s confirm\"", commandPrefix))
                    angryRequest = true
                end
            else
                if not angry then
                    chat.say("DFC is already friendly")
                else
                    chat.say("DFC is now friendly")
                    angry = false
                end
            end
        end,

        ["confirm"] = function()
            if angryRequest and angryUsers[chatCmd.lastUser] then
                local msg = "WARNING: DFC is now angry!"
                chatCmd.log(msg)
                chat.say(msg)
                angry = true
            else
                chatCmd.log("not enough permissions")
                chat.say("you don't have enough permissions to do that")
            end

            angryRequest = false
        end,

        ["info"] = function()
            chat.say("Active: " .. tostring(emitter.isActive()))
            chat.say("Angry:  " .. tostring(angry))
            chat.say("Locked: " .. tostring(locked))
            chat.say("Power:  " .. tostring(emitter.getInput()))
        end,

        ["panic"] = function()
            emergency("DFC AZ-5 was triggered")
        end
    }
}

function chatCmd.loopCheck()
    -- set angry state
    if angry then
        redstone.setOutput(angrySide, 15)
    else
        redstone.setOutput(angrySide, 0)
    end

    -- check cryogel
    if emitter.getCryogel() < 60000 then
        emergency("WARNING: cryogel low! check cryogel production")
    end

    -- check angry time

    if angry then
        if (lastAngryCheck or 0) + 300 < computer.uptime() then
            lastAngryCheck = computer.uptime()
            local warning = "WARNING: angry mode was active for 5 minutes!"
            chatCmd.log(warning)
            chatCmd.chat.say(warning)
            angry = false
        end
    else
        lastAngryCheck = computer.uptime()
    end
end

chatCmd.runLoop()
