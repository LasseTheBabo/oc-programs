local computer = require("computer")
local fs = require("filesystem")

local M = {}
M.path = "/var/log/syslog.log"
M.maxSize = 64 * 1024

local function rotate()
    if fs.size(M.path) > M.maxSize then
        fs.remove(M.path .. ".1")
        fs.rename(M.path, M.path .. ".1")
    end
end

function M.log(level, msg)
    msg = tostring(msg)
    pcall(function()
        fs.makeDirectory(fs.path(M.path))
        rotate()
        local f = io.open(M.path, "a")
        if f then
            f:write(string.format("%s [%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), level, msg))
            f:close()
        end
    end)
    computer.pushSignal("syslog", level, msg)
end

function M.run(name, f, ...)
    local ok, err = xpcall(f, debug.traceback, ...)
    if not ok then M.log("ERROR", name .. ": " .. tostring(err)) end
    return ok
end

return M
