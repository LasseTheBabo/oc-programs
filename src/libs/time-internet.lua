local internet = require("internet")
local json = require("json")

local time = {}

function time.getUnformattedTime()
    local handle = internet.request("https://time.now/developer/api/timezone/Europe/Berlin")
    local result = ""
    for chunk in handle do
        result = result..chunk
    end

    local data = json.decode(result)
    return data.utc_datetime
end

function time.getDate(time)
    local year, month, day = string.match(time, "(%d%d%d%d)%-(%d%d)%-(%d%d)")

    return tonumber(year), tonumber(month), tonumber(day)
end

function time.getTime(time)
    local hour, min, sec = string.match(time, "T(%d%d):(%d%d):(%d%d)")

    return tonumber(hour), tonumber(min), tonumber(sec)
end

return time