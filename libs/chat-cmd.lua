local component = require("component")
local event = require("event")
local filesystem = require("filesystem")

local time = require("time")

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

local function split(input)
    local result = {}
    for word in input:gmatch("%S+") do
        table.insert(result, word)
    end
    return result
end

local function doAuthorizedShit(username, message)
    local parts = split(message)

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

function chatCmd.runLoop()
    while true do
        chatCmd.utcTime = time.getUnformattedTime()
        local _, _, username, message = event.pull(10, "chat_message")
        chatCmd.lastUser = username

        if chatCmd.allowedUsers[username] then
            doAuthorizedShit(username, message)
        elseif chatCmd.deniedUsers[username] then
            chatCmd.chat.say(chatCmd.denyMessage)
        end

        chatCmd.loopCheck()
    end
end

return chatCmd
