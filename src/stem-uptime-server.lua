local computer = require("computer")
local event = require("event")
local term = require("term")

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

local function wentOnline(name) end
local function wentOffline(name) end

local success, r = setup()
if not success then
    print(r); return
end
server = stem.connect(domain)
server:subscribe(channel_id)
event.listen("interrupted", function() running = false end)

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

    term.clear()
    print("Online  | Name")
    print("--------|--------------------")
    for name, online in pairs(online) do
        print(string.format("%s\t| %s", (online and "online" or "offline"), name))
    end

    lastComputers = {}
    for name, time in pairs(computers) do
        lastComputers[name] = time
    end
end

server:unsubscribe(channel_id)
server:disconnect()
