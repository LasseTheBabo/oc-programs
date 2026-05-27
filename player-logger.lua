local os = require("os")

local mcstatus = require("mcstatus")

local online = {}
local lastOnline = {}

while true do
    local status = mcstatus.getServerStatus("penis.nvrsrv.com:50000")

    online = status.players.list

    lastOnline = online
    os.sleep(0.1)
end