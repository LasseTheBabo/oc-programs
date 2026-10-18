local computer = require("computer")
local event = require("event")
local os = require("os")

local util = require("util")
local stem
local ocvm, lib = pcall(require, "stem-ocvm")
if ocvm then stem = lib else stem = require("stem") end

local channel_id = "ping_service"
local domain
local server
local computers = {}
local lastComputers = {}
local running = true

local function setup()
    local var1, r = util.load("stem-domain.env")
    if not var1 then return var1, r end
    domain = var1

    return true
end

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
        end
    end

    for name, time in pairs(computers) do
        if time + 5 < computer.uptime() then
            computers[name] = nil
        end

        if computers[name] and not lastComputers[name] then
            print(name .. " is online")
        end
    end

    for name in pairs(lastComputers) do
        if not computers[name] and lastComputers[name] then
            print(name .. " is offline")
        end
    end

    lastComputers = {}
    for name, time in pairs(computers) do
        lastComputers[name] = time
    end
end

server:unsubscribe(channel_id)
server:disconnect()
