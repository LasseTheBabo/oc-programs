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

local function queryWait(connection, ...)
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

function doTeleShit()
    local sender, receiver = table.unpack(currentRequest)

    for i, c in ipairs(connections) do
        if c~=sender and c~=receiver then
            query(c, "busy", "server is processing a teleport")
        end
    end

    query(receiver, "inbound", sender.name)
    queryWait(sender, "phase1-end")

    query(receiver, "phase2-begin")
    queryWait(receiver, "phase2-end")

    query(sender, "phase3-begin")
    queryWait(sender, "phase3-end")

    query(receiver, "phase4-begin")
    queryWait(receiver, "phase4-end")

    query(sender, "phase5-begin")
    queryWait(sender, "phase5-end")

    query(receiver, "phase6-begin")
    queryWait(receiver, "phase6-end")

    -- TODO: free other deles because of locking shit

    currentRequest = nil
end

function handleMessage(connection, command, ...)
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

start(true)