-- unencrypted Command and Control... what did you expect

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
        return nil, string.format("%s: %s", r, path)
    end

    return data
end

local M = {}
M.__index = M

function M.new(options)
    options = options or {}

    local domain, r = load(options.domain_path)
    if not domain then return domain, r end

    local channel_id, r = load(options.channel_path)
    if not channel_id then return channel_id, r end

    local secret, r = load(options.secret_path)
    if not secret then return secret, r end

    local self = setmetatable({}, M)
    self.channel_id = channel_id
    self.secret = totp.b32dec(secret)
    self.blockedUntil = 0
    self.failures = 0
    self.connected = false
    self._listener = nil

    self.commands = {}
    self.authorizedCommands = {}

    local ok, server = pcall(stem.connect, domain)
    if not ok then
        return nil, tostring(server)
    end
    self.server = server

    return self
end

function M:register(name, fn)
    self.commands[name] = fn
end

function M:registerAuthorized(name, fn)
    self.authorizedCommands[name] = fn
end

function M:_authorized(code)
    if not code then
        return false
    end

    if code:match("^%d%d%d%d%d%d$") == nil then
        return false
    end

    local now = totp.now()
    if now < self.blockedUntil then return false end
    if totp.verify(self.secret, code, now) then
        self.failures = 0
        return true
    end

    self.failures = self.failures + 1
    if self.failures >= 5 then
        self.blockedUntil = now + 60
        self.failures = 0
    end
    return false
end

function M:_run(command, args)
    local success, r = command(args)
    if not success then
        self.server:send(self.channel_id, string.format("failed: %s", r))
    end
end

function M:_handleMessage(_, ch, message)
    if ch ~= self.channel_id then return end

    local parts = split(message)
    local cmd = parts[1]
    local isAuth = self.authorizedCommands and true or false

    local args = {}
    for i = 2, #parts - (isAuth and 1 or 0) do
        table.insert(args, parts[i])
    end

    if isAuth then
        local code = parts[#parts]

        if code and self:authorized(code) then
            self:_run(self.authorizedCommands[cmd], args)
        else
            self.server:send(self.channel_id, "denied")
        end
    elseif self.commands[cmd] then
        self:_run(self.commands[cmd], args)
    else
        self.server:send(self.channel_id, "unknown command")
    end
end

function M:start()
    if self.connected then return end
    self.server:subscribe(self.channel_id)
    self._listener = function(...) self:_handleMessage(...) end
    event.listen("stem_message", self._listener)
    self.connected = true
end

function M:stop()
    if self._listener then
        event.ignore("stem_message", self._listener)
        self._listener = nil
    end

    if self.connected then
        self.server:unsubscribe(self.channel_id)
        self.server:disconnect()
        self.connected = false
    end
end

function M:run()
    self:start()
    event.pull("interrupted")
    self:stop()
end

return M
