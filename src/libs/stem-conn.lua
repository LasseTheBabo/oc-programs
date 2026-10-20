local computer = require("computer")
local event = require("event")
local os = require("os")
local thread = require("thread")

local syslog = require("syslog")
local util = require("util")
local stem = util.getStem()

local M = {}
M.__index = M

function M.new(options)
    if not options.domain then
        return nil, "domain required"
    end

    if not options.channel_id then
        return nil, "channel id required"
    end

    local self = setmetatable({}, M)
    self.name = options.name
    self.domain = options.domain
    self.channel_id = options.channel_id
    self.timeout = options.timeout or 60
    self.heartbeat = options.heartbeat
    self.heartbeat_msg = options.heartbeat_msg or "hb"
    self.on_message = options.on_message or function() end
    self.on_connect = options.on_connect or function() end
    self.on_disconnect = options.on_disconnect or function() end
    self._server = nil
    self._worker = nil
    self._listener = nil
    self._running = false
    self._lastSeen = 0
    self._lastHb = 0

    return self
end

function M:send(message)
    if not self._server then return false, "not connected" end
    return pcall(self._server.send, self._server, self.channel_id, message)
end

function M:isConnected()
    return self._server ~= nil
end

function M:isStarted()
    return self._running
end

function M:_disconnect()
    if not self._server then return end
    pcall(self._server.unsubscribe, self._server, self.channel_id)
    pcall(self._server.disconnect, self._server)
    self._server = nil
    self.on_disconnect()
end

function M:_log(level, msg)
    local name = self.name and string.format("(%s): ", self.name) or ""
    syslog.log(level, name .. msg)
end

function M:_connect()
    local ok, s = pcall(stem.connect, self.domain)
    if not ok then return false, tostring(s) end
    if not s then return false, "connection returned nil" end

    local ok, e = pcall(s.subscribe, s, self.channel_id)
    if not ok then
        pcall(s.diconnect, s)
        return false, e
    end

    self._server = s
    self._lastSeen = computer.uptime()
    self._lastHb = computer.uptime()
    self.on_connect()
    return true
end

function M:start()
    if self._running then return end
    self._running = true
    self:_log("INFO", "starting")

    self._listener = function(_, ch, message)
        if ch ~= self.channel_id then return end
        self._lastSeen = computer.uptime()
        self.on_message(message)
    end
    event.listen("stem_message", self._listener)

    self._worker = thread.create(function()
        local ok, r = pcall(function()
            local failures = 0

            while self._running do
                if not self._server then
                    self:_log("INFO", string.format("connecting stem to %s with channel %s", self.domain, self.channel_id))
                    local ok, r = self:_connect()
                    if ok then
                        self:_log("INFO", "stem connected")
                        failures = 0
                    else
                        self:_log("ERROR", "connection failed: " .. tostring(r))
                        self:_disconnect()

                        failures = failures + 1
                        if failures > 2 then -- number so low because fuckass oc only allowes 4 open sockets
                            self:_log("INFO", "too many errors, rebooting")
                            os.execute("reboot") -- stfu "too many connections" bitch
                        end
                    end
                else
                    if self.heartbeat and computer.uptime() - self._lastHb >= self.heartbeat then
                        self._lastHb = computer.uptime()
                        if not pcall(self._server.send, self._server, self.channel_id, self.heartbeat_msg) then
                            self:_log("ERROR", "heartbeat failed")
                            self:_disconnect()
                        end
                    end

                    if computer.uptime() - self._lastSeen > self.timeout then
                        self:_log("ERROR", "no message since " .. self.timeout .. "s, roconnecting")
                        self:_disconnect()
                    end

                    os.sleep(1)
                end
            end
        end)

        if not ok then
            self:_log("ERROR", "stem connection worker crashed: " .. tostring(r))
        end
    end)
end

function M:stop()
    self._running = false
    if self._listener then
        event.ignore("stem_message", self._listener)
        self._listener = nil
    end

    if self._worker then
        self._worker:kill()
        self._worker = nil
    end

    self:_disconnect()
    self:_log("INFO", "stopped")
end

return M
