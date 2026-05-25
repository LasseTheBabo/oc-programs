local component = require("component")
local event = require("event")

local logger = require("logger")
local minitel = require("minitel")

local connected = true

local function setStatus(message)
    logger.header = string.format("Status: %s", message)
    logger.render()
end

local function split(msg)
    local ret = {}
    for x in msg:gmatch("[^\t]+") do
        table.insert(ret, x)
    end
    return ret
end

while true do
    setStatus("waiting for connection")
    local connection = minitel.listen(7000)
    if connection then
        setStatus("connected")
        connected = true
    end

    while connected do
        local response = connection:read("\n")
        local _, _, _, _, direction = event.pull(0.1, "scroll")
        if direction then
        logger.handleScroll(-direction)
    end

        if response then
            local parts = split(response)
            local message

            if parts[1] == "log" then
                message = table.unpack(parts, 2)
            end

            if message then
                logger.add(message)
            end
        end
    end
end
