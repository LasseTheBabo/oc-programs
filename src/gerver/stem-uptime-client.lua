local os = require("os")
local thread = require("thread")

local stemConn = require("stem-conn")
local syslog = require("syslog")
local util = require("util")

local channel_id = "ping_service"
local connection
local worker
local running = false

local function setup()
    local name, r = util.load("/etc/stem-name.env")
    if not name then return nil, r end

    local domain, r = util.load("/etc/stem-domain.env")
    if not domain then return nil, r end

    return name, domain
end

function start()
    local name, domain = setup()
    if not name then
        syslog.log("ERROR", "setup failed: " .. tostring(domain)) -- what the fuck it works...
        return
    end
    
    connection = stemConn.new({
        domain = domain,
        channel_id = channel_id,
        timeout = 30
    })
    connection:start()
    running = true

    worker = thread.create(function()
        while running do
            connection:send(string.format("ping/%s", name))
            os.sleep(10)
        end
    end)
end

function stop()
    running = false

    if worker then
        worker:kill()
        worker = nil
    end

    if connection then
        connection:stop()
        connection = nil
    end
end
