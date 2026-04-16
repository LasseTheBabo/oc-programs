local component = require("component")
local sides = require("sides")
local os = require("os")
local minitel = require("minitel")
local event = require("event")


-- component config

local redstone = component.redstone

local rsReceive = sides.east
local rsSend = sides.top
local rsSpatialIO = sides.north
local rsSpatialIO_read = sides.west

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

setRedstone(rsReceive, 0)
setRedstone(rsSend, 0)
setRedstone(rsSpatialIO, 0)

log("connecting to server...")
log(server..":"..port)
local connection, r = minitel.open(server, port)

if not connection then
    log("unable to open connection: "..r)
    return
end

log("connection established")


-- fuck off minitel

local function split(msg)
   local ret = {}
   for x in msg:gmatch("[^\t]+") do
      table.insert(ret, x)
   end
   return ret
end

local function query(...)
   connection:write(table.concat({...}, "\t").."\n")
end

local function queryWait(...)
    while true do
        local response

        repeat
            response = connection:read("\n")
            os.sleep(0.1)
        until response

        local parts = split(response)

        for _, pattern in ipairs({...}) do
            local match = table.pack(response:match(pattern))
            if parts[1] == pattern then
                return table.unpack(parts, 2) -- 2 because only return message -> {command, message}
            end
        end
    end
end

-- BackLog handling for query traffic in the background

local function updateBackLog()
    local message = connection:read("\n")
    
    if message then
        table.insert(queryBackLog, message)
    end
end

local function handleBackLog()
    for i = #queryBackLog, 1, -1 do
        local command, argument = table.unpack(split(queryBackLog[i]))

        if command == "inbound" then
            if remoteStation then
                query("reject") -- reject inbound because something is still going on
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
    query("get_list")
    stations = {queryWait("list")}
    for i, station in ipairs(stations) do
        log(i.." "..station)
    end
end

local function handleSend()
    log("teleporting...")
    query("request", remoteStation)

    -- phase 1
    log("phase 1")
    pulseRedstone(rsSpatialIO)
    setRedstone(rsSend, 15)
    query("phase1-end")

    -- phase 3
    log("phase 3")
    queryWait("phase3-begin")
    while readRedstone(rsSpatialIO_read) do
        os.sleep(0.1)
    end
    setRedstone(rsSend, 0)
    query("phase3-end")

    -- phase 5
    log("phase 5")
    queryWait("phase5-begin")
    setRedstone(rsReceive, 15)
    while not readRedstone(rsSpatialIO_read) do
        os.sleep(0.1)
    end
    setRedstone(rsReceive, 0)
    query("phase5-end")
    
    log("finished sending")
end

local function handleReceive()
    log("incoming teleport...")

    -- phase 2
    log("phase 2")
    queryWait("phase2-begin")
    pulseRedstone(rsSpatialIO)
    setRedstone(rsReceive, 15)
    query("phase2-end")
    
    -- phase 4
    log("phase 4")
    queryWait("phase4-begin")
    setRedstone(rsReceive, 0)
    setRedstone(rsSend, 15)
    query("phase5-end")

    -- phase 6
    log("phase 6")
    queryWait("phase6-begin")
    setRedstone(rsSend, 0)
    pulseRedstone(rsSpatialIO)
    setRedstone(rsSend, 15)
    setRedstone(rsReceive, 15)
    os.sleep(1)
    setRedstone(rsSend, 0)
    setRedstone(rsReceive, 0)
    query("phase6-end")

    inbound = false
    remoteStation = false
    log("finished receiving")
end

query("register", clientName)
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