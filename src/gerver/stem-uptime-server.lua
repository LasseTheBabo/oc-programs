local computer = require("computer")
local internet = require("internet")
local os = require("os")
local thread = require("thread")

local stemConn = require("stem-conn")
local syslog = require("syslog")
local util = require("util")

local channel_id = "ping_service"
local computers = {}
local lastComputers = {}
local online = {}
local connection
local worker
local running = false
local ntfy_domain

local function setup()
    local domain, r = util.load("/etc/stem-domain.env")
    if not domain then return nil, r end

    local ntfy, r = util.load("/etc/ntfy-domain.env")
    if not ntfy then return nil, r end

    return domain, ntfy
end

local function log(level, msg)
    syslog.log(level, "(stem-uptime-server): " .. msg)
end

local function notify(topic, title, message)
    local ok, r = pcall(internet.request,
        string.format("https://%s/%s/publish?title=%s&message=%s", ntfy_domain, topic, title:gsub(" ", "+"),
            message:gsub(" ", "+")))

    if not ok then
        log("ERROR", "failed to notify: " .. r)
    end
end

local function sortedPairs(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    local i = 0
    return function()
        i = i + 1
        if keys[i] ~= nil then return keys[i], t[keys[i]] end
    end
end

local function writeUptimeFile()
    local f, r = io.open("/etc/uptime.txt", "w")
    if not f then
        log("ERROR", "failed to open file: " .. r)
        return
    end
    f:setvbuf("no")

    f:write("Online  | Name")
    f:write("\n--------|--------------------")
    for name, online in sortedPairs(online) do
        f:write(string.format("\n%s| %s", (online and "online  " or "offline "), name))
    end

    f:close()
end

function start()
    local domain, ntfy = setup()
    if not domain then
        log("ERROR", "setup failed: " .. tostring(ntfy))
        return
    end
    ntfy_domain = ntfy

    local conn, r = stemConn.new({
        name = "uptime-server",
        domain = domain,
        channel_id = channel_id,
        timeout = 60,
        heartbeat = 10,
        on_message = function(message)
            local name = message:match("^ping/(.+)$")
            if name then
                computers[name] = computer.uptime()
                online[name] = true
            end
        end
    })

    if not conn then
        log("ERROR", r)
        return
    end

    connection = conn
    connection:start()
    running = true

    worker = thread.create(function()
        while running do
            for name, time in pairs(computers) do
                if time + 30 < computer.uptime() then
                    computers[name] = nil
                    online[name] = false
                end
            end

            for name in pairs(computers) do
                if not lastComputers[name] then
                    notify(channel_id, "STEM", name .. " is online")
                end
            end

            for name in pairs(lastComputers) do
                if not computers[name] then
                    notify(channel_id, "STEM", name .. " is offline")
                end
            end

            writeUptimeFile()

            lastComputers = {}
            for name, time in pairs(computers) do
                lastComputers[name] = time
            end

            os.sleep(1)
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
