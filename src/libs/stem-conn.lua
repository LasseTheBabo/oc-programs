local computer = require("computer")
local event = require("event")
local os = require("os")
local thread = require("thread")

local syslog = require("syslog")
local util = require("util")
local stem = util.getStem()

local Hub = {
    domain = nil,
    server = nil,
    handles = {},
    channels = {},
    worker = nil
}

local function log(level, msg)
    syslog.log(level, string.format("(stem-conn): %s", msg))
end

local function disconnect()
    local s = Hub.server

    if not s then return end
    Hub.server = nil
    for channel in pairs(Hub.channels) do
        pcall(s.unsubscribe, s, channel)
    end

    pcall(s.disconnect())

    for h in pairs(Hub.handles) do
        h.on_disconnect()
    end
end

local function connect()
    local ok, s = pcall(stem.connect, Hub.domain)
    if not ok then return false, tostring(s) end
    if not s then return false, "connection returned nil" end

    for channel in pairs(Hub.channels) do
        local ok, e = pcall(s.subscribe, s, channel)

        if not ok then
            pcall(s.diconnect, s)
            return false, tostring(e)
        end
    end

    Hub.server = s
    local now = computer.uptime()
    for h in pairs(Hub.handles) do
        h._lastSeen = now
        h._lastHb = now
        h.on_connect()
    end

    return true
end

local function startWorker()
    if Hub.worker then return end

    Hub.worker = thread.create(function()
        local function onMessage(_, ch, message)
            for h in pairs(Hub.handles) do
                if h.channel_id == ch then
                    h._lastSeen = computer.uptime()
                    h.on_message(message)
                end
            end
        end
        event.listen("stem_message", onMessage)

        local ok, r = pcall(function()
            local failures = 0

            while next(Hub.handles) do
                if not Hub.server then
                    local ok, r = connect()
                    if ok then
                        log("INFO", "connected")
                        failures = 0
                    else
                        log("ERROR", "connection failed: " .. tostring(r))
                        disconnect()

                        failures = failures + 1
                        if failures > 2 then     -- number so low because fuckass oc only allowes 4 open sockets
                            log("INFO", "too many errors, rebooting")
                            os.execute("reboot") -- stfu "too many connections" bitch
                        end
                    end
                else
                    local now = computer.uptime()

                    for h in pairs(Hub.handles) do
                        if h.heartbeat and now - h._lastHb >= h.heartbeat then
                            h._lastHb = now
                            if not pcall(Hub.server.send, Hub.server, h.channel_id, h.heartbeat_msg) then
                                log("ERROR", "heartbeat failed")
                                disconnect()
                                break
                            end

                            if h.check_dead and now - h._lastSeen > h.timeout then
                                log("ERROR", "no message since " .. h.timeout .. "s, roconnecting")
                                disconnect()
                                break
                            end
                        end
                    end
                end

                os.sleep(1)
            end
        end)

        if not ok then
            log("ERROR", "worker crashed: " .. tostring(r))
        end

        event.ignore("stem_message", onMessage)
        disconnect()
        Hub.worker = nil
    end)

    Hub.worker:detach()
end

local M = {}
M.__index = M

function M.new(options)
    if not options.domain then return nil, "domain required" end
    if not options.channel_id then return nil, "channel id required" end
    if Hub.domain and Hub.domain ~= options.domain then
        return nil, "hub already uses domain " .. Hub.domain
    end

    local self = setmetatable({}, M)
    self.domain = options.domain
    self.channel_id = options.channel_id
    self.timeout = options.timeout or 60
    self.heartbeat = options.heartbeat
    self.check_dead = options.check_dead_channel and true or false
    self.heartbeat_msg = options.heartbeat_msg or "hb"
    self.on_message = options.on_message or function() end
    self.on_connect = options.on_connect or function() end
    self.on_disconnect = options.on_disconnect or function() end
    self._lastSeen = 0
    self._lastHb = 0
    self._started = false

    return self
end

function M:start()
    if self._started then return end
    self._started = true
    Hub.domain = self.domain
    Hub.handles[self] = true

    local first = (Hub.channels[self.channel_id] or 0) == 0
    Hub.channels[self.channel_id] = (Hub.channels[self.channel_id] or 0) + 1

    if Hub.server then
        if first then pcall(Hub.server.subscribe, Hub.server, self.channel_id) end
        self._lastSeen, self._lastHb = computer.uptime(), computer.uptime()
        self.on_connect()
    else
        startWorker()
    end
end

function M:stop()
    if not self._started then return end
    self._started = false
    Hub.handles[self] = nil

    local n = (Hub.channels[self.channel_id] or 1 ) - 1

    if n <= 0 then
        Hub.channels[self.channel_id] = nil
        if Hub.server then
            pcall(Hub.server.unsubscribe, Hub.server, self.channel_id)
        end
    else
        Hub.channels[self.channel_id] = n
    end
end

function M:send(message)
    if not Hub.server then return false, "not connected" end
    return pcall(Hub.server.send, Hub.server, self.channel_id, message)
end

function M:isConnected()
    return self._server ~= nil
end

function M:isStarted()
    return self._started
end

return M
