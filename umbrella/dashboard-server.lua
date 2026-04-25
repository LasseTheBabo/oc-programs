local event = require("event")
local thread = require("thread")

local minitel = require("minitel")
local tele = require("tele")

local commands = {}
local connections = {}
local connectionThread
local connectionListener
local port = 7000

local status = {
    ok = 200,
    badRequest = 400,
    unauthorized = 401,
    forbidden = 403,
    notFound = 404
}

local db = {
    ["LasseTheBabo"] = "umbrella"
}

local function sendStatus(connection, code)
    tele.query(connection, "status", code)
end

commands["auth"] = function(c, ...)
    local username, password = ...
    if not username or not password then
        sendStatus(c, status.badRequest)
        print("parameter false")
        return
    end

    if db[username] ~= password then
        sendStatus(c, status.unauthorized)
        print("wrong passwd")
        return
    end

    sendStatus(c, status.ok)
    c.auth = true
end

commands["debug"] = function(c)
    if c.auth then
        sendStatus(c, status.ok)
        tele.query(c, "text", "fuck you")
    else
        sendStatus(c, status.forbidden)
    end
end


local function handleMessage(connection, command, ...)
    if commands[command] then
        commands[command](connection, ...)
    else
        sendStatus(connection, status.notFound)
    end
end

local function runConnectionThread()
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
        end

        os.sleep(0.2)
    end
end

function start()
    connectionThread = thread.create(runConnectionThread)
    connectionThread:detach()
    connectionListener = minitel.flisten(port, function(s)
        table.insert(connections, s)
    end)
end

function stop(...)
    local reason = table.concat({ ... }, " ")
    if #reason == 0 then reason = "unspecified" end
    for _, c in ipairs(connections) do
        tele.query(c, "bye", reason)
        c:close()
    end
    event.ignore("net_msg", connectionListener)
    connectionThread:kill()
    connectionThread = nil
end
