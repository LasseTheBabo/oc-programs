local minitel = require("minitel")
local tele = require("tele")

print("waiting for connection")
local connection = minitel.listen(7000)
print("connected")

while true do
    local message = tele.queryWait(connection, "log")
    if message then
        print(message)
    end
end