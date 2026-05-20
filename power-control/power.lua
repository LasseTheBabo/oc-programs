local chat = require("chat-cmd")

chat.chat.setName("Power Grid Management")

chat.allowedUsers = {
    ["LasseTheBabo"] = true,
    ["RedstoneParkour"] = true
}

chat.commands = {
    ["#backup-power"] = {
        ["ccgt"] = function()
            chat.chat.say("hallo")
        end
    }}
chat.runLoop()
