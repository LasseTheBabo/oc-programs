local computer = require("computer")
local event = require("event")
local os = require("os")
local thread = require("thread")

local util = require("util")
local stem = util.getStem()

local channel_id = "ping_service"
local domain
local server
local computers = {}
local lastComputers = {}
local online = {}
local running = true

local function setup()
    local var1, r = util.load("/etc/stem-domain.env")
    if not var1 then return var1, r end
    domain = var1

    return true
end

local function wentOnline(name)
    computer.pushSignal("stem_uptime", name, "1")
end

local function wentOffline(name)
    computer.pushSignal("stem_uptime", name, "0")
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


function start()
    local success, r = setup()
    if not success then
        print(r); return
    end
    server = stem.connect(domain)
    server:subscribe(channel_id)

    thread.create(function()
        while running do
            local _, _, message = event.pull(1, "stem_message")

            if message then
                local name = message:match("^ping/(.+)$")
                if name then
                    computers[name] = computer.uptime()
                    online[name] = true
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
                uptime_file:write(string.format("\n%s\t| %s", (online and "online  " or "offline "), name))
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
    server:unsubscribe(channel_id)
    server:disconnect()
end
