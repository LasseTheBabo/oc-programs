local os = require("os")

local mcstatus = require("mcstatus")

local online = {}
local lastOnline = {}

local function formatTable(t1)
    local t2

    for _, value in ipairs(t1) do
        t2[name] = true
    end
end

while true do
    local status = mcstatus.getServerStatus("penis.nvrsrv.com:50000")


    online = formatTable(status.players.list)

    

    lastOnline = online
    os.sleep(0.1)
end