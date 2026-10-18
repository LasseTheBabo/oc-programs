-- unencrypted Command and Control... what did you expect

-- tmux new-session -d -s oc -x 160 -y 50 'cd ~/ocvm && while true; do ./ocvm; sleep 5; done'
-- fuck my life

local event = require("event")
local thread = require("thread")

local totp = require("totp")
local util = require("util")
local stem
local ocvm, lib = pcall(require, "stem-ocvm")
if ocvm then stem = lib else stem = require("stem") end


local M = {}
M.__index = M

function M.new(options)
    options = options or {}

    local domain, r = util.load(options.domain_path)
    if not domain then return domain, r end

    local channel_id, r = util.load(options.channel_path)
    if not channel_id then return channel_id, r end

    local secret, r = util.load(options.secret_path)
    if not secret then return secret, r end

    local name = options.name

    local self = setmetatable({}, M)
    self.channel_id = channel_id
    self.secret = totp.b32dec(secret)
    self.name = name
    self.blockedUntil = 0
    self.failures = 0
    self.connected = false
    self.pinging = false
    self.pingChannel = "ping_service"
    self._listener = nil

    self.commands = {}
    self.authorizedCommands = {}

    self:register("help", function()
        self:send("commands:")
        for name, _ in pairs(self.commands) do
            self:send(string.format(" - %s", name))
        end

        self:send("")
        self:send("commands (requires TOTP):")
        for name, _ in pairs(self.authorizedCommands) do
            self:send(string.format(" - %s", name))
        end
    end)

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

function M:send(message)
    self.server:send(self.channel_id, string.format("[%s] %s", self.name, message))
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
    if success == false then
        self:send(string.format("failed: %s", r))
    end
end

function M:_handleMessage(_, ch, message)
    if ch ~= self.channel_id then return end

    if message:match("^%[.-%] ") ~= nil then return end -- preventing "[...] " to be handled e.g. "[STEM] hello"

    local parts = util.split(message)
    local cmd = parts[1]
    local isAuth = self.authorizedCommands[cmd] and true or false

    local args = {}
    for i = 2, #parts - (isAuth and 1 or 0) do
        table.insert(args, parts[i])
    end

    if isAuth then
        local code = parts[#parts]

        if code and self:_authorized(code) then
            self:_run(self.authorizedCommands[cmd], args)
        else
            self:send("denied")
        end
    elseif self.commands[cmd] then
        self:_run(self.commands[cmd], args)
    else
        self:send("unknown command")
    end
end

function M:startPingService()
    if not self.connected then return end

    self.server:subscribe(self.pingChannel)
    self.pinging = true

    thread.create(function()
        while self.pinging do
            self.server:send(self.pingChannel, string.format("ping/%s", self.name))
        end
    end)
end

function M:stopPinging()
    if self.pinging then
        self.pinging = false
        self.server:unsubscribe(self.pingChannel)
    end
end

function M:start()
    if self.connected then return end
    self.server:subscribe(self.channel_id)
    self._listener = function(...) self:_handleMessage(...) end
    event.listen("stem_message", self._listener)
    self:send("hello")
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
