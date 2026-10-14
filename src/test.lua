local event = require("event")

local stem = require("stem")
local totp = require("totp")

local server = stem.connect("fritz-server.myds.me")
local channel_id = "test"
local running = true
local secret = totp.b32dec("OVWHI4TBEBZWKY3SMV2CAZTVMNVWC43TEB2G65DQ")
local blockedUntil = 0
local failures = 0

local function split(input)
    local result = {}
    for word in input:gmatch("%S+") do
        table.insert(result, word)
    end
    return result
end

local function authorized(code)
    local now = totp.now()
    if now < blockedUntil then return false end
    if code and totp.verify(secret, code, now) then
        failures = 0
        return true
    end

    failures = failures + 1
    if failures >= 5 then blockedUntil = now + 60; failures = 0 end
    return false
end

server:subscribe(channel_id)

while running do
    local name, ch, message = event.pull(1, "stem_message")

    if name then
        local parts = split(message)
        local cmd, code = parts[1], parts[#parts]

        if cmd == "exit" then
            if authorized(code) then
                running = false
            else
                server:send(ch, "denied")
            end
        elseif cmd == "auth" then
            server:send(ch, authorized(code) and "ok" or "denied")
        end
    end
end

server:send(channel_id, "bye")
server:unsubscribe(channel_id)
server:disconnect()
