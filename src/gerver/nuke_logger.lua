local component = require("component")
local event = require("event")
local filesystem = require("filesystem")

local logger = require("logger")
local time = require("time")

local terminal = component.rbmk_terminal


local last_event_times = {}
local last_cleanup = time.getUnformattedTime()
local log_path = "/etc/nukelogger.log"
local utcTime = ""

if not filesystem.exists(log_path) then
    local handle = filesystem.open(log_path, "w")
    handle:close()
end
local log_file = filesystem.open(log_path, "a")



local function split(input)
    local result = {}
    for word in input:gmatch("%S+") do
        table.insert(result, word)
    end
    return result
end

local function log(message)
    local log_info = string.format("%s > %s", time.getFormattedTime(utcTime), message)
    log_file:write(log_info .. "\n")
    logger.add(log_info)
end

local function flush()
    for id, last_time in pairs(last_event_times) do
        if (utcTime - last_time) >= 120 then
            last_event_times[id] = nil
        end
    end
    terminal.clearScreen()
    last_cleanup = utcTime
end

if not terminal then
    print("This program requires a Redstone-over-Radio Terminal to run!")
    return
end

terminal.enableOCMode(true)
terminal.clearScreen()


while true do
    local event_id = terminal.readInput()
    local latest_event = split(event_id)
    local _, _, _, _, direction = event.pull(0.1, "scroll")
    utcTime = time.getUnformattedTime()

    logger.header = string.format("Time: %s", time.getFormattedTime(utcTime))
    logger.render()

    if direction then
        logger.handleScroll(-direction)
    end

    local intensity, x, z = table.unpack(latest_event)
    if intensity and tonumber(x) and tonumber(z) then
        -- dont spam shit
        if not last_event_times[event_id] then
            log(string.format("Explosion of %s intensity around x=%d z=%d", intensity, x, z))
            last_event_times[event_id] = utcTime
        end
    end

    -- RAM is expensive, don't clog the table
    -- delete old events after 5 minutes
    if (utcTime - last_cleanup) >= 300 then
        pcall(flush())
    end
end
