local fs = require("filesystem")

local time = {}

function time.getUnformattedTime()
    local handler, r = io.open("/tmp/realtime", "wb")
    if not handler then return handler, r end
    handler:close()
    return fs.lastModified("/tmp/realtime")/1000
end

function time.parseTime(t)
    return os.date("*t", t)
end

function time.getDate(t)
    local parsed = time.parseTime(t)
    return parsed.year, parsed.month, parsed.day
end

function time.getTime(t)
    local parsed = time.parseTime(t)
    return parsed.hour, parsed.min, parsed.sec
end

function time.getFormattedTime(t)
    local year, month, day = time.getDate(t)
    local hour, min, sec = time.getTime(t)
    local formattedTime = string.format(
        "%02d:%02d:%02d %02d.%02d.%04d",
        hour + 2, min, sec, day, month, year -- (UCT+2) fuck everyone who doesn't use european summer time
    )
    return formattedTime
end

return time