local component = require("component")
local event = require("event")

local time = require("time")
local util = require("util")

local chatCmd = {}

chatCmd.chat = component.chat_box
chatCmd.utcTime = ""
chatCmd.commands = {}
chatCmd.loopCheck = nil
chatCmd.allowedUsers = {}
chatCmd.deniedUsers = {}
chatCmd.denyMessage = "access denied"
chatCmd.lastUser = ""
chatCmd.log = nil
chatCmd.running = true


local function doAuthorizedShit(username, message)
    local parts = util.split(message)

    for prefix, func in pairs(chatCmd.commands) do
        if parts[1] == prefix then
            local command = parts[2]
            local args = {}

            for i = 3, #parts do
                table.insert(args, parts[i])
            end

            chatCmd.log(username .. ": " .. message)

            if func[command] then
                func[command](args)
            else
                chatCmd.chat.say("Unknown command")
            end
        end
    end
end

function chatCmd.stop()
    chatCmd.running = false
end

function chatCmd.runLoop()
    while chatCmd.running do
        chatCmd.utcTime = time.getUnformattedTime()
        local _, _, username, message = event.pull(10, "chat_message")
        chatCmd.lastUser = username

        if chatCmd.deniedUsers[username] then
            chatCmd.chat.say(chatCmd.denyMessage)
        else
            if chatCmd.allowedUsers[username] then
                doAuthorizedShit(username, message)
            end
        end

        chatCmd.loopCheck()
    end
end

return chatCmd
