local event = require("event")
local minitel = require("minitel")
local thread = require("thread")
local computer = require("computer")
local tele = require("tele-lib")

local port = 7000

local connections = {}

local currentRequest
local connectionThread
local connectionListener

function doTeleShit()
    local sender, receiver = table.unpack(currentRequest)

    for i, c in ipairs(connections) do
        if c~=sender and c~=receiver then
            tele.query(c, "busy", "server is processing a teleport")
        end
    end

    tele.query(receiver, "inbound", sender.name)
    tele.queryWait(sender, "phase1-end")

    tele.query(receiver, "phase2-begin")
    tele.queryWait(receiver, "phase2-end")

    tele.query(sender, "phase3-begin")
    tele.queryWait(sender, "phase3-end")

    tele.query(receiver, "phase4-begin")
    tele.queryWait(receiver, "phase4-end")

    tele.query(sender, "phase5-begin")
    tele.queryWait(sender, "phase5-end")

    tele.query(receiver, "phase6-begin")
    tele.queryWait(receiver, "phase6-end")

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

        if currentRequest then tele.query(connection, "cancel", "a request is in progress") return end
        if not targetConnection then tele.query(connection, "cancel", "no station "..target) return end

        currentRequest = {connection, targetConnection}

        doTeleShit()
    elseif command == "register" then
        connection.name = (...)
    elseif command == "get_list" then
        local stationNames = {}

        for i, c in ipairs(connections) do
            table.insert(stationNames, c.name)
        end

        tele.query(connection, "list", table.unpack(stationNames))
    else
        tele.query(connection, "unknown command")
    end
end

function runConnectionThread()
    while true do
        local i = 1

        while i <= #connections do
            local connection = connections[i]
            local message = connection:read("\n")

            if message then
                handleMessage(connection, table.unpack(tele.split(message)))
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