local computer = require("computer")
local event = require("event")
local os = require("os")
local thread = require("thread")

local syslog = require("syslog")
local util = require("util")

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

function M:_connect()
    local stem = util.getStem()
    local s, r = stem.connect(self.domain)
    if not s then return false, r end

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

    self._listener = function(_, ch, message)
        if ch ~= self.channel_id then return end
        self._lastSeen = computer.uptime()
        self.on_message(message)
    end
    event.listen("stem_message", self._listener)

    self._worker = thread.create(function()
        local backoff = 1

        while self._running do
            if not self._server then
                syslog.log("INFO", "connecting stem to " .. self.domain)
                local ok, r = self:_connect()
                if ok then
                    syslog.log("INFO", "stem connected to " .. self.domain)
                    backoff = 1
                else
                    syslog.log("ERROR", "connection failed: " .. tostring(r))
                    os.sleep(backoff)
                    backoff = math.min(backoff * 2, 30) -- discord update timeout fail ahh
                end
            else
                if self.heartbeat and computer.uptime() - self._lastHb >= self.heartbeat then
                    self._lastHb = computer.uptime()
                    if not pcall(self._server.send, self._server, self.channel_id, self.heartbeat_msg) then
                        syslog.log("ERROR", "heartbeat failed")
                        self:_disconnect()
                    end
                end

                if computer.uptime() - self._lastSeen > self.timeout then
                    syslog.log("ERROR", "no message since " .. self.timeout .. "s, roconnecting")
                    self:_disconnect()
                end

                os.sleep(1)
            end
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
end

return M
