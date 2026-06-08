local os = require("os")

local mcstatus = require("mcstatus")

local online = {}
local lastOnline = {}

local function formatTable(t1)
    local t2

    for _, value in ipairs(t1) do
        t2[value] = true
    end

    return t2
end

while true do
    local status = mcstatus.getServerStatus("penis.nvrsrv.com:50000")


    online = formatTable(status.players.list)

    if online then
        for player in pairs(online) do
            if not lastOnline[player] then
                print(string.format("%s joined the game", player))
            end
        end

        for player in pairs(lastOnline) do
            if not online[player] then
                print(string.format("%s left the game", player))
            end
        end

        lastOnline = online
    end
    
    os.sleep(0.1)
end
