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
    if code:match("^%d%d%d%d%d%d$") == nil then
        return false
    end

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

local function run(command, ch, args)
    local success, r = command(ch, args)
    if not success then
        server:send(ch, string.format("failed: %s", r))
    end
end


local commands = {
    ["debug"] = function(ch)
        server:send(ch, "Hello World!")

        return true
    end,

    ["auth"] = function(ch, args)
        return authorized(args[1])
    end
}

local authorizedCommands = {
    ["exit"] = function(ch)
        running = false

        return true
    end
}


while running do
    local name, ch, message = event.pull("stem_message")

    if name then
        local parts = split(message)
        local cmd = parts[1]
        local args = {}

        for i = 2, #parts - (authorizedCommands[cmd] and 1 or 0) do
            table.insert(args, parts[i])
        end

        print(message)

        if authorizedCommands[cmd] then
            local code = parts[#parts]

            if code and authorized(code) then
                run(authorizedCommands[cmd], ch, args)
            else
                server:send(ch, "denied")
            end
        elseif commands[cmd] then
            run(commands[cmd], ch, args)
        else
            server:send(ch, "unknown command")
        end
    end
end

server:send(channel_id, "bye")
server:unsubscribe(channel_id)
server:disconnect()
