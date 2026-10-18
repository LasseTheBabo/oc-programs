local event = require("event")

local logger = require("logger")
local stem = require("stem")
local time = require("time")
local util = require("util")


local channel_id
local domain
local loggerPath = "/etc/stem.log"
local messageListener
local running = true
local server
local utcTime = ""

local log_file, r = io.open(loggerPath, "a")
if not log_file then
    print(r)
    return
end

log_file:setvbuf("no")

local function log(message)
    local log_info = string.format("%s > %s", time.getFormattedTime(utcTime), message)
    log_file:write(log_info .. "\n")
    logger.add(log_info)
end

local function setup()
    domain, r = util.load("stem-domain.env")
    if not domain then return domain, r end

    channel_id, r = util.load("stem-channel.env")
    if not channel_id then return channel_id, r end

    return true
end

if not setup() then print(r) end
server = stem.connect(domain)
server:subscribe(channel_id)
messageListener = function(_, _, msg) log(msg) end
event.listen("stem_message", messageListener)
event.listen("interrupted", function() running = false end)

while running do
    local _, _, _, _, direction = event.pull(0.1, "scroll")
    utcTime = time.getUnformattedTime()

    logger.header = string.format("Time: %s", time.getFormattedTime(utcTime))
    logger.render()

    if direction then
        logger.handleScroll(-direction)
    end
end

event.ignore("stem_message", messageListener)
server:unsubscribe(channel_id)
server:disconnect()
log_file:close()
