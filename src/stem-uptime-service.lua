local event = require("event")

local util = require("util")
local stem
local ocvm, lib = pcall(require, "stem-ocvm")
if ocvm then stem = lib else stem = require("stem") end

local channel_id = "ping_service"
local domain
local messageListener
local server

local function messageHandler(message)
    print("Message: " .. tostring(message))
    local result = message:match("^ping/(.+)$")
    if result then
        print("Matched: " .. result)
    end
end

local function setup()
    local var1, r = util.load("stem-domain.env")
    if not domain then return domain, r end
    domain = var1

    return true
end

local success, r = setup()
if not success then
    print(r); return
end
server = stem.connect(domain)
server:subscribe(channel_id)
messageListener = function(_, _, msg) messageHandler(msg) end
event.listen("stem_message", messageListener)

event.pull("interrupted")

event.ignore("stem_message", messageListener)
server:unsubscribe(channel_id)
server:disconnect()
