local thread = require("thread")

local util = require("util")
local stem = util.getStem()

local server
local channel_id = "ping_service"
local connected = false

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
    connected = true

    thread.create(function()
        while connected do
            server:send(channel_id, string.format("ping/%s", name))
            os.sleep(10)
        end
    end)
end

function stop()
    if connected then
        server:unsubscribe(channel_id)
        server:disconnect()
        connected = false
    end
end
