local event = require("event")
local os = require("os")

local stem = require("stem")
local totp = require("totp")


local function split(input)
    local result = {}
    for word in input:gmatch("%S+") do
        table.insert(result, word)
    end
    return result
end

local function read(path)
    if not path then return path, "invalid path" end

    local file, r = io.open(path, "r")
    if not file then return file, r end
    local data = file:read()

    file:close()
    return data
end

local function load(path)
    local data, r = read(path)
    if not data then
        print(string.format("%s: %s", r, path))
        os.exit()
    end

    return data
end


local server = stem.connect(load("stem-domain.env"))
local channel_id = load("stem-channel.env")
local running = true
local secret = totp.b32dec(load("totp-secret.env"))
local blockedUntil = 0
local failures = 0
server:subscribe(channel_id)


local function authorized(code)
    local now = totp.now()
    if now < blockedUntil then return false end
    if code and totp.verify(secret, code, now) then
        failures = 0
        return true
    end

    failures = failures + 1
    if failures >= 5 then
        blockedUntil = now + 60; failures = 0
    end
    return false
end


local commands = {
    ["debug"] = function(ch, args)
        server:send(ch, "Hello World!")
    end,

    ["auth"] = function(ch, args)
        server:send(ch, authorized(code) and "ok" or "denied")
    end
}

local authorizedCommands = {
    ["exit"] = function(ch)
        running = false
    end
}


while running do
    local name, ch, message = event.pull("stem_message")

    if name then
        local parts = split(message)
        local cmd, code = parts[1], parts[#parts]

        -- TODO: FUCK EVERYTHING
        if cmd == "exit" then
            if authorized(code) then
                running = false
            else
                server:send(ch, "denied")
            end
        elseif cmd == "auth" then
        end
    end
end

server:send(channel_id, "bye")
server:unsubscribe(channel_id)
server:disconnect()
