local event = require('event')
local os = require('os')
local term = require("term")

local stem = require('stem')


local channel_id = "g6pwrBackup"
local running = true


local server = stem.connect('stem.fomalhaut.me')
server:subscribe(channel_id)


while running  do
    local event, channel, message = event.pull(0.1)
    term.clear()

    term.setCursor(1, 1)
    term.write("Press 'Ctrl-C' to exit")


    if event == "stem_message" then
        print(string.format("%s: %s", channel, message))
    elseif event == "interrupted" then
        running = false
    end
end

server:unsubscribe(channel_id)
server:disconnect()