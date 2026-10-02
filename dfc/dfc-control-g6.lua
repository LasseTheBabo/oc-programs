-- Gerver Season 6
-- DFC control program
-- more secure version of the Derver 1.5 program
--
-- changed whitelist
-- added component existance checking
-- added second core radius check
-- added angry request timeout (30s)
-- added electrolysis machine calculations
-- too many fixes to count...
-- put security checks in another thread for faster response
-- added preset1

local component = require("component")
local computer = require("computer")
local filesystem = require("filesystem")
local os = require("os")
local sides = require("sides")
local thread = require("thread")

local chatCmd = require("chat-cmd")
local minitel = require("minitel")
local tele = require("tele")
local time = require("time")

local function component_error(c)
    print(string.format("This program requires a %s to run!", c))
end

local redstone = component.redstone
local emitter = component.dfc_emitter
local chat = chatCmd.chat
local c2_gauge = component.ntm_fluid_gauge

if not redstone then
    component_error("Redstone I/O")
    return
end

if not emitter then
    component_error("DFC Emitter")
    return
end

if not chat then
    component_error("Computronics Chat Box")
    return
end

if not c2_gauge then
    component_error("Fluid Gauge")
    return
end

-- some variables

chat.setName("DFC")
local angrySide = sides.top
local locked = false
local angry = false
local commandPrefix = "#dfc"
local angryRequest = false
local log_path = "/etc/dfc.log"
local lastAngryCheck = computer.uptime()
local lastRequestCheck = computer.uptime()
local maxPower = 1

-- Core 1 information
local c1 = 2500  -- Core
local c1f1 = 2.5 -- Fuel 1
local c1f2 = 2.7 -- Fuel 2


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
    ["fujhfzt"] = true,
    ["LasseTheBabo"] = true,
    ["RedstoneParkour"] = true,
    ["TheDogOfChaos"] = true
}

local angryUsers = {
    ["Alexmaster75"] = true,
    ["LasseTheBabo"] = true,
    ["RedstoneParkour"] = true
}

chatCmd.deniedUsers = {
    -- maybe admins? :)
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

local function getHeat(watt)
    return watt * 95 -- Spk
        * c1
        * c1f1
        * c1f2
        / 10000                    -- Spk to heat
end

local function isNegativeRadius(heat)
    return (2 ^ 31 - 256000 * (heat * 10) % (2 ^ 32)) < 0
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
            if angryUsers[chatCmd.lastUser] then
                if angryRequest then
                    local msg = "WARNING: DFC is now angry!"
                    chatCmd.log(msg)
                    chat.say(msg)
                    angry = true
                else
                    chat.say("no pending angry request")
                end
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
        end,

        ["preset1"] = function()
            local c = chatCmd.commands["#dfc"]
            c["unlock"]()
            c["power"]({ "11" })
            c["angry"]({ "true" })
            c["confirm"]()
            c["on"]()
        end,

        ["calculate"] = function()
            local perMachine = 200 * 7 / 3
            local factor =
                1000 / (   -- to Spk
                    c1 *   -- core factr
                    c1f1 * -- fuel 1 factor
                    c1f2 * -- fuel 2 factor
                    95)    -- to emitter watt

            local maxWatt = math.floor(128000 * factor)


            local c = chatCmd.commands["#dfc"]
            c["unlock"]()
            c["power"]({ maxWatt })
            c["angry"]({ "true" })
            c["confirm"]()
            c["on"]()

            os.sleep(0.5)
            maxPower = math.floor(math.ceil(c2_gauge.getTransfer() / perMachine) * perMachine * factor)

            while not isNegativeRadius(maxPower) and maxPower > 0 do
                maxPower = maxPower - 1
            end

            chat.say("Highest emitter power for angry mode: " .. maxPower)
        end
    }
}

function chatCmd.loopCheck() end

thread.create(function()
    while true do
        -- check cryogel
        if emitter.getCryogel() < 60000 then
            emergency("WARNING: cryogel low! check cryogel production")
        end

        if angry then
            -- check for too high power setting
            if emitter.getInput() > maxPower then
                emitter.setInput(maxPower)
            end

            -- check for negative radius
            local heat = getHeat(emitter.getInput())
            if not isNegativeRadius(heat) then
                chat.say("WARNING: 2. core heat instable! Negative radius can't be exploited")
                angry = false
            end

            -- check angry ontime
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

        -- check angry request timeout
        if angryRequest then
            if (lastRequestCheck or 0) + 30 < computer.uptime() then
                lastRequestCheck = computer.uptime()
                local warning = "Angry request timed out after 30 seconds"
                chatCmd.log(warning)
                chatCmd.chat.say(warning)
                angryRequest = false
            end
        else
            lastRequestCheck = computer.uptime()
        end

        -- set angry state
        if angry then
            redstone.setOutput(angrySide, 15)
        else
            redstone.setOutput(angrySide, 0)
        end

        os.sleep(0.05)
    end
end)

chatCmd.runLoop()
