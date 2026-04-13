local event = require("event")
local minitel = require("minitel")
local thread = require("thread")
local computer = require("computer")

local port = 7000

local connections = {}

local currentRequest
local connectionThread
local connectionListener

local function split(msg)
   local ret = {}
   for x in msg:gmatch("[^\t]+") do
      table.insert(ret, x)
   end
   return ret
end

local function query(connection, ...)
   connection:write(table.concat({...}, "\t").."\n")
end

function doTeleShit()
    local sender, receiver = table.unpack(currentRequest)
    query(receiver, "inbound", sender.name)

    currentRequest = nil
end

function handleMessage(connection, command, ...)
    print("command: "..command)

    if command == "request" then
        local target, targetConnection = ...

        for i, c in ipairs(connections) do
            if target == c.name then
                targetConnection = c
            end
        end

        if currentRequest then query(connection, "cancel", "a request is in progress") return end
        if not targetConnection then query(connection, "cancel", "no station "..target) return end

        currentRequest = {connection, targetConnection}

        doTeleShit()
    elseif command == "register" then
        connection.name = (...)
    elseif command == "get_list" then
        local stationNames = {}

        for i, c in ipairs(connections) do
            table.insert(stationNames, c.name)
        end

        query(connection, "list", table.unpack(stationNames))
    else
        query(connection, "unknown command")
    end
end

function runConnectionThread()
    while true do
        local i = 1

        while i <= #connections do
            local connection = connections[i]
            local message = connection:read("\n")

            if message then
                print("received message: "..message)
                handleMessage(connection, table.unpack(split(message)))
            end

            -- keep index to not skip after remove
            if connection.state == "closed" then
	            table.remove(connections, i)
	        else
	            i = i + 1
	        end

            -- send ping if uptime is larger than last ping
            if (connection.lastPing or 0) + 10 < computer.uptime() then
	            query(connection, "ping")
	            connection.lastPing = computer.uptime()
	        end
        end

        os.sleep(0.2)
    end
end

function start(deamon)
    if deamon then
        connectionThread = thread.create(runConnectionThread)
        connectionThread:detach()

        connectionListener = minitel.flisten(port, function(s)
            table.insert(connections, s)
        end)
    else
        local handle = minitel.listen(7000)
        table.insert(connections, handle)
        runConnectionThread()
    end
end

start(false)