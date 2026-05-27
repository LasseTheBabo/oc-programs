local internet = require("internet")
local json = require("json")

local function getServerStatus(server)
    local handle = internet.request("https://api.mcstatus.io/v2/status/java/" .. server)

    local result = ""
    for chunk in handle do
        result = result .. chunk
    end

    local data = json.decode(result)
    return data
end

local players = getServerStatus("penis.nvrsrv.com:50000").players.list
for _, player in ipairs(players) do
    print(player)
end
