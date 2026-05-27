local internet = require("internet")
local json = require("json")

local mcstatus = {}

function mcstatus.getServerStatus(server)
    local handle = internet.request("https://api.mcstatus.io/v2/status/java/" .. server)

    local result = ""
    for chunk in handle do
        result = result .. chunk
    end

    local data = json.decode(result)
    return data
end

return mcstatus