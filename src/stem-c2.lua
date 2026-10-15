-- tmux new-session -d -s oc -x 160 -y 50 'cd ~/ocvm && while true; do ./ocvm; sleep 5; done'
-- fuck my life

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
local secret = totp.b32dec(load("totp-secret.env"))
local blockedUntil = 0
local failures = 0
server:subscribe(channel_id)


local function close()
    server:unsubscribe(channel_id)
    server:disconnect()
end

local function authorized(code)
    if not code then
        return false
    end

    if code:match("^%d%d%d%d%d%d$") == nil then
        return false
    end

    local now = totp.now()
    if now < blockedUntil then return false end
    if totp.verify(secret, code, now) then
        failures = 0
        return true
    end

    failures = failures + 1
    if failures >= 5 then
        blockedUntil = now + 60; failures = 0
    end
    return false
end

local function run(command, args)
    local success, r = command(args)
    if not success then
        server:send(channel_id, string.format("failed: %s", r))
    end
end


local commands = {
    ["ping"] = function()
        server:send(channel_id, "pong")

        return true
    end
}

local authorizedCommands = {
    ["exit"] = function()
        server:send(channel_id, "bye")
        close()
        os.execute("shutdown")

        return true
    end
}

local function handleStemMessage(_, _, message)
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
            run(authorizedCommands[cmd], args)
        else
            server:send(channel_id, "denied")
        end
    elseif commands[cmd] then
        run(commands[cmd], args)
    else
        server:send(channel_id, "unknown command")
    end
end

event.listen("stem_message", handleStemMessage)

event.pull("interrupted")
event.ignore("stem_message", handleStemMessage)
close()
os.exit()
