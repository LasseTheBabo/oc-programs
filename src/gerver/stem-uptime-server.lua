local computer = require("computer")
local event = require("event")
local internet = require("internet")
local os = require("os")
local thread = require("thread")

local util = require("util")
local stem = util.getStem()
local syslog = require("syslog")

local lastSeen = 0
local lastHb = 0
local backoff = 1
local channel_id = "ping_service"
local domain
local ntfy
local server
local worker
local computers = {}
local lastComputers = {}
local online = {}
local running = true

local function setup()
    local var1, r = util.load("/etc/stem-domain.env")
    if not var1 then return var1, r end
    domain = var1

    local var2, r = util.load("/etc/ntfy-domain.env")
    if not var2 then return var2, r end
    ntfy = var2

    return true
end

local function notify(topic, title, message)
    internet.request(string.format("https://%s/%s/publish?title=%s&message=%s", ntfy, topic, title:gsub(" ", "+"),
        message:gsub(" ", "+")))
end

local function wentOnline(name)
    notify(channel_id, "STEM", string.format("%s is online", name))
end

local function wentOffline(name)
    notify(channel_id, "STEM", string.format("%s is offline", name))
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

local function disconnect()
    if server then
        pcall(server.unsubscribe, server, channel_id)
        pcall(server.disconnect, server)
        server = nil
    end
end

local function connect()
    local s = stem.connect(domain)
    if not s then return false end
    if not pcall(s.subscribe, s, channel_id) then
        pcall(s.disconnect, s)
        return false
    end
    server = s
    lastSeen = computer.uptime()
    return true
end

function start()
    local success, r = setup()
    if not success then
        print(r)
        return
    end
    running = true

    worker = thread.create(function()
        while running do
            if not server then
                syslog.log("INFO", "connecting stem to " .. domain)
                if connect() then
                    syslog.log("INFO", "stem connected to " .. domain)
                    backoff = 1
                else
                    syslog.log("ERROR", "connection failed. retrying after " .. backoff)
                    os.sleep(backoff)
                    backoff = math.min(backoff * 2, 30)
                end
            else
                local _, _, message = event.pull(1, "stem_message")
                if message then
                    lastSeen = computer.uptime()
                    local name = message:match("^ping/(.+)$")
                    if name then
                        computers[name] = computer.uptime()
                        online[name] = true
                    end
                end

                if computer.uptime() - lastHb >= 10 then
                    lastHb = computer.uptime()
                    if not pcall(server.send, server, channel_id, "hb") then
                        syslog.log("ERROR", "couldn't send heartbeat message")
                        disconnect()
                    end
                end

                if server and computer.uptime() - lastSeen > 60 then
                    syslog.log("ERROR", "no message from server since 60 seconds")
                    disconnect()
                end
            end


            for name, time in pairs(computers) do
                if time + 30 < computer.uptime() then
                    computers[name] = nil
                    online[name] = false
                end

                if computers[name] and not lastComputers[name] then
                    wentOnline(name)
                end
            end

            for name in pairs(lastComputers) do
                if not computers[name] and lastComputers[name] then
                    wentOffline(name)
                end
            end


            local uptime_file, r = io.open("/etc/uptime.txt", "w")
            if not uptime_file then
                print(r)
                os.exit()
            end
            uptime_file:setvbuf("no")

            uptime_file:write("Online  | Name")
            uptime_file:write("\n--------|--------------------")
            for name, online in sortedPairs(online) do
                uptime_file:write(string.format("\n%s| %s", (online and "online  " or "offline "), name))
            end

            uptime_file:close()

            lastComputers = {}
            for name, time in pairs(computers) do
                lastComputers[name] = time
            end
        end
    end)
end

function stop()
    running = false
    if worker then
        worker:kill()
        worker = nil
    end
    server:unsubscribe(channel_id)
    server:disconnect()
end
