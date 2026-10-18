local thread = require("thread")

local util = require("util")
local stem = util.getStem()

local server
local channel_id = "ping_service"
local connected = false
local pinging = false

function start()
    local name, r = util.load("stem-name.env")
    if not name then
        print(r)
        return
    end

    local domain, r = util.load("stem-domain.env")
    if not domain then
        print(r)
        return
    end

    server = stem.connect(domain)
    server:subscribe(channel_id)
    pinging = true

    thread.create(function()
        while pinging do
            server:send(channel_id, string.format("ping/%s", name))
            os.sleep(10)
        end
    end)
end

function stop()
    if pinging and server then
        pinging = false
        server:unsubscribe(channel_id)
        server:disconnect()
    end
end
