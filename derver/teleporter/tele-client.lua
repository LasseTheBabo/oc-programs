local component = require("component")
local sides = require("sides")
local os = require("os")
local minitel = require("minitel")
local event = require("event")


-- component config

local rs = component.redstone

local rsReceive = sides.east
local rsSend = sides.top
local rsSpatialIO = sides.north


-- connecting to server

local running = true
local queryBackLog = {}
local stations = {}
local remoteStation
local inbound = false

local clientName = "earth"
local server = "tele-server"
local port = 7000

print("connecting to server...")
print(server..":"..port)
local connection, r = minitel.open(server, port)

if not connection then
    print("unable to open connection: "..r)
    return
end

print("connection established")


-- some helping shit

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

local function queryWait(pattern)
    while true do
        local response

        repeat
            response = connection:read("\n")
            os.sleep(0.1)
        until response

        local parts = split(response)

        if parts[1] == pattern then
            return table.unpack(parts, 2)
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
            print("incoming teleport...")
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
    print("\navailable teleporter")
    query("get_list")
    stations = {queryWait("list")}
    for i, station in ipairs(stations) do
        print(i.." "..station)
    end
end

local function handleSend()
    print("teleporting...")
    query("request", remoteStation)

    
    print("finished sending")
end

local function handleReceive()
    print("")

    inbound = false
    remoteStation = false
    print("finished receiving")
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

print("disconnecting")
connection:close()