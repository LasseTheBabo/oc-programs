local component = require("component")
local sides = require("sides")
local os = require("os")
local minitel = require("minitel")
local event = require("event")
local tele = require("tele")
local red = require("red") -- redstone
local cfg = require("config")
local gpu = component.gpu


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

local w, h = gpu.getResolution()
local logList = {}
local status = ""

local function clear()
    gpu.fill(1, 1, w, h, " ")
end

local function render()
    clear()
    gpu.set(2, 1, "q: quit")
    gpu.set(2, 2, "Status: " .. status)
    gpu.fill(1, 3, w, 1, "-")

    for i, line in ipairs(logList) do
        gpu.set(2, 4 + i, line)
    end
end

local function setStatus(message)
    status = message
    render()
end

local function log(message)
    table.insert(logList, message)
    if #logList > 10 then
        table.remove(logList, 1)
    end
    render()
end


local s, r = cfg.loadConfig(configPath, config)
if not s then
    log(r)
    log("using default config")
    os.sleep(1)
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

setStatus("connecting to server...")
local connection, r = minitel.open(config.server, config.port)

if not connection then
    logList = {}
    log("unable to open connection: " .. r)
    return
end

setStatus("connection established")


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
            busy = argument ~= "clear"
            if busy then
                setStatus("server is busy")
            else
                render()
            end
        elseif command == "bye" then
            running = false
            logList = {}
            log("server shut down!")
            log("reason: " .. argument)
        end

        table.remove(queryBackLog, i)
    end
end

local counter = 0
local function getStationList()
    if counter % 10 == 0 then -- only do it every 10 cycles to not overload the server
        tele.query(connection, "get_list")
        stations = { tele.queryWait(connection, "list") }
        logList = {}
        log("available teleporter:")
        for i, station in ipairs(stations) do
            log(i .. ". " .. station)
        end
    end

    counter = counter + 1
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
    setStatus("teleporting...")
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
    setStatus("finished sending")
end

local function handleReceive()
    setStatus("incoming teleport...")

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
    setStatus("finished receiving")
end

tele.query(connection, "register", config.clientName)
while running do
    updateBackLog()
    handleBackLog()
    getStationList()

    local e, _, ch, co = event.pull(0.5, "key_down")

    if e == "key_down" then
        if not busy then
            local key = string.char(ch)
            local choice = tonumber(key)
            local station = stations[choice]

            if station then
                remoteStation = station
                handleSend()
            elseif key == "q" then
                running = false
            end
        else
            setStatus("server is still processing")
        end
    end

    if inbound and remoteStation then
        handleReceive()
    end
end

connection:close()
os.sleep(0.1)
clear()
