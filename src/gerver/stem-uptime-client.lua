local os = require("os")
local thread = require("thread")

local util = require("util")
local stem = util.getStem()

local channel_id = "ping_service"
local server
local connected = false

local function disconnect()
    if server then
        pcall(server.unsubscribe, server, channel_id)
        pcall(server.disconnect, server)
        server = nil
    end
end

local function connect(domain)
    local s, err = stem.connect(domain)
    if not s then return s, err end

    local ok, e = pcall(s.subscribe, s, channel_id)
    if not ok then
        pcall(s.disconnect, s)
        return ok, e
    end

    server = s
    return true
end

function start()
    local name, r = util.load("/etc/stem-name.env")
    if not name then
        print(r)
        return
    end

    local domain, r = util.load("/etc/stem-domain.env")
    if not domain then
        print(r)
        return
    end

    connected = true

    thread.create(function()
        local backoff = 1

        while connected do
            if not server then
                local ok = connect(domain)
                if ok then
                    backoff = 1
                else
                    os.sleep(backoff)
                    backoff = math.min(backoff * 2, 30) -- discord update timeout fail ahh
                end
            else
                local ok = pcall(server.send, server, channel_id, string.format("ping/%s", name))

                if not ok then
                    disconnect()
                else
                    os.sleep(10)
                end
            end
        end
    end)
end

function stop()
    connected = false
    disconnect()
end
