-- unencrypted Command and Control... what did you expect

-- tmux new-session -d -s oc -x 160 -y 50 'cd ~/ocvm && while true; do ./ocvm; sleep 5; done'
-- fuck my life

local event = require("event")

local stemConn = require("stem-conn")
local totp = require("totp")
local util = require("util")

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

    self.commands = {}
    self.authorizedCommands = {}

    self:register("help", function()
        self:send("commands:")
        for name, _ in pairs(self.commands) do
            self:send(string.format(" - %s", name))
        end

        if next(self.authorizedCommands) ~= nil then
            self:send("")
            self:send("commands (requires TOTP):")
            for name, _ in pairs(self.authorizedCommands) do
                self:send(string.format(" - %s", name))
            end
        end
    end)

    local connection, r = stemConn.new({
        name = string.format("stem-c2 [%s]", name),
        domain = domain,
        channel_id = channel_id,
        on_message = function(message) self:_handleMessage(message) end
    })

    if not connection then
        return nil, "failed: " .. tostring(r)
    end

    self._connection = connection

    return self
end

function M:register(name, fn)
    self.commands[name] = fn
end

function M:registerAuthorized(name, fn)
    self.authorizedCommands[name] = fn
end

function M:send(message)
    self._connection:send(string.format("[%s] %s", self.name, message))
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

function M:_handleMessage(message)
    if message:match("^%[.-%] ") then return end -- preventing "[...] " to be handled e.g. "[STEM] hello"

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


function M:start()
    if self._connection:isStarted() then return end
    self._connection:start()
    self:send("hello")
end

function M:stop()
    self._connection:stop()
end

function M:run()
    self:start()
    event.pull("interrupted")
    self:stop()
end

return M
