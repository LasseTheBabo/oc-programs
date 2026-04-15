local component = require("component")
local sides = require("sides")
local os = require("os")
local minitel = require("minitel")
local event = require("event")
local tele = require("tele-lib")


-- component config

local redstone = component.redstone

local rsReceive = sides.east
local rsSend = sides.top
local rsSpatialIO = sides.north


local running = true
local queryBackLog = {}
local stations = {}
local remoteStation
local inbound = false

local clientName = "earth"
local server = "tele-server"
local port = 7000


-- some helping shit

local function setRedstone(side, value)
    redstone.setOutput(side, 15)
end

local function readRedstone(side)
    return redstone.getInput(side)
end

local function pulseRedstone(side)
    setRedstone(side, 15)
    os.sleep(0.1)
    setRedstone(side, 0)
end

local function log(message)
    print(message)
end


-- connecting to server

log("connecting to server...")
log(server..":"..port)
local connection, r = minitel.open(server, port)

if not connection then
    log("unable to open connection: "..r)
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
            log("incoming teleport...")
            if remoteStation then
                tele.query(connection, "reject") -- reject inbound because something is still going on
            else
                inbound = true
                remoteStation = argument
            end
        elseif command == "cancel" then
            remoteStation = nil
        end

        table.remove(queryBackLog, i)
    end
end

local function getStationList()
    log("\navailable teleporter")
    tele.query(connection, "get_list")
    stations = {tele.queryWait(connection, "list")}
    for i, station in ipairs(stations) do
        log(i.." "..station)
    end
end

local function handleSend()
    log("teleporting...")
    tele.query(connection, "request", remoteStation)

    -- phase 1
    pulseRedstone(rsSpatialIO)
    setRedstone(rsInport, 15)
    tele.query(connection, "phase1-end")

    -- phase 3
    tele.queryWait(connection, "phase3-begin")
    while readRedstone(rsSpatialIO_read) do
        os.sleep(0.1)
    end
    setRedstone(rsImport, 0)
    tele.query(connection, "phase3-end")

    -- phase 5
    tele.queryWait(connection, "phase5-begin")
    setRedstone(rsStorage, 15)
    while not readRedstone(rsSpatialIO_read) do
    os.sleep(0.1)
        setRedstone(rsStorage, 0)
    tele.query(connection, "phase5-end")
    
    log("finished sending")
end

local function handleReceive()
    log("incoming teleport...")

    -- phase 2
    tele.queryWait(connection, "phase2-begin")
    pulseRedstone(rsSpatialIO)
    setRedstone(rsStorage, 15)
    tele.query(connection, "phase2-end")
    
    -- phase 4
    tele.queryWait(connection, "phase4-begin")
    setRedstone(rsStorage, 0)
    setRedstone(rsImport, 15)
    tele.query(connection, "phase5-end")

    -- phase 6
    tele.queryWait(connection, "phase6-begin")
    setRedstone(rsImport, 0)
    pulseRedstone(rsSpatialIO)
    setRedstone(rsImport, 15)
    setRedstone(rsStorage, 15)
    os.sleep(1)
    setRedstone(rsImport, 0)
    setRedstone(rsStorage, 0)
    tele.query(connection, "phase6-end")

    inbound = false
    remoteStation = false
    log("finished receiving")
end

tele.query(connection, "register", clientName)
getStationList()
while running do
    updateBackLog()
    handleBackLog()

    local e, _, ch, co = event.pull(0.5, "key_down")

    if e == "key_down" then
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
    end

    if inbound and remoteStation then
        handleReceive()
        getStationList()
    end
end

log("disconnecting")
connection:close()