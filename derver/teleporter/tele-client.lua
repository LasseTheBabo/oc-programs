local component = require("component")
local sides = require("sides")
local os = require("os")
local minitel = require("minitel")
local event = require("event")
local tele = require("tele")
local red = require("red") -- redstone
local cfg = require("config")


-- component config

local rsReceive = sides.east
local rsSend = sides.top
local rsSpatialIO = sides.north
local rsSpatialIO_read = sides.west

local configPath = "/etc/tele.cfg"
local config = {
    clientName = "earth",
    server = "tele-server",
    port = 7000
}

local function log(message)
    print(message)
end

do
    local s, r = cfg.loadConfig(configPath, config)
    if not s then
        log(r)
        log("using default config")
    end
end
cfg.saveConfig(configPath, config)


local busy = false
local running = true
local queryBackLog = {}
local stations = {}
local remoteStation
local inbound = false


-- connecting to server

red.setRedstone(rsReceive, 0)
red.setRedstone(rsSend, 0)
red.setRedstone(rsSpatialIO, 0)

log("connecting to server...")
log(config.server .. ":" .. config.port)
local connection, r = minitel.open(config.server, config.port)

if not connection then
    log("unable to open connection: " .. r)
    return
end

log("connection established")


-- BackLog handling for query traffic in the background

local function updateBackLog()
    local message = connection:read("\n")

    if message then
        table.insert(queryBackLog, message)
    end
end

local function handleBackLog()
    for i = #queryBackLog, 1, -1 do
        local command, argument = table.unpack(tele.split(queryBackLog[i]))

        if command == "inbound" then
            if remoteStation then
                tele.query(connection, "reject") -- reject inbound because something is still going on
            else
                inbound = true
                remoteStation = argument
            end
        elseif command == "cancel" then
            remoteStation = nil
        elseif command == "busy" then
            log(argument)
            busy = argument ~= "clear"
        elseif command == "bye" then
            running = false
            log("server shut down!")
            log("reason: " .. argument)
        end

        table.remove(queryBackLog, i)
    end
end

local function getStationList()
    log("\navailable teleporter")
    tele.query(connection, "get_list")
    stations = { tele.queryWait(connection, "list") }
    for i, station in ipairs(stations) do
        log(i .. " " .. station)
    end
end

local function phase(i, begin)
    local message = "phase" .. tostring(i) .. "-"

    if begin then
        tele.queryWait(connection, message .. "begin")
    else
        tele.query(connection, message .. "end")
    end
end

local function handleSend()
    log("teleporting...")
    tele.query(connection, "request", remoteStation)

    -- phase 1
    red.pulseRedstone(rsSpatialIO)
    red.setRedstone(rsSend, 15)
    phase(1, false)

    -- phase 3
    phase(3, true)
    while red.readRedstone(rsSpatialIO_read) ~= 0 do
        os.sleep(0.1)
    end
    red.setRedstone(rsSend, 0)
    phase(3, false)

    -- phase 5
    phase(5, true)
    red.setRedstone(rsReceive, 15)
    while red.readRedstone(rsSpatialIO_read) == 0 do
        os.sleep(0.1)
    end
    red.setRedstone(rsReceive, 0)
    phase(5, false)

    inbound = false
    remoteStation = nil
    log("finished sending")
end

local function handleReceive()
    log("incoming teleport...")

    -- phase 2
    phase(2, true)
    red.pulseRedstone(rsSpatialIO)
    red.setRedstone(rsReceive, 15)
    phase(2, false)

    -- phase 4
    phase(4, true)
    red.setRedstone(rsReceive, 0)
    red.setRedstone(rsSend, 15)
    phase(4, false)

    -- phase 6
    phase(6, true)
    red.setRedstone(rsSend, 0)
    red.pulseRedstone(rsSpatialIO)
    red.setRedstone(rsSend, 15)
    red.setRedstone(rsReceive, 15)
    os.sleep(1)
    red.setRedstone(rsSend, 0)
    red.setRedstone(rsReceive, 0)
    phase(6, false)

    inbound = false
    remoteStation = nil
    log("finished receiving")
end

tele.query(connection, "register", config.clientName)
getStationList()
while running do
    updateBackLog()
    handleBackLog()

    local e, _, ch, co = event.pull(0.5, "key_down")

    if e == "key_down" then
        if not busy then
            local key = string.char(ch)
            local choice = tonumber(key)
            local station = stations[choice]

            if station then
                remoteStation = station
                handleSend()
                getStationList()
            elseif key == "q" then
                running = false
            end
        else
            log("server is still processing")
        end
    end

    if inbound and remoteStation then
        handleReceive()
        getStationList()
    end
end

log("disconnecting")
connection:close()
