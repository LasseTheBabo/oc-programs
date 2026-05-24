local component = require("component")
local term = require("term")

local minitel = require("minitel")
local tele = require("tele")

local gpu = component.gpu
local connected = true
local status = "disconnected"
local w, h = gpu.getResolution()
local log = {}

local function render()
    w, h = gpu.getResolution()
    term.clear()
    gpu.fill(1, 2, w, 1, "-")
    gpu.set(2, 1, string.format("Status: %s", status))

    for i, line in ipairs(log) do
        gpu.set(2, i + 3, line)
    end
end

local function setStatus(message)
    status = message
    render()
end

while true do
    setStatus("waiting for connection")
    local connection = minitel.listen(7000)
    if connection then
        setStatus("connected")
        connected = true
    end

    while connected do
        local message, r = tele.queryWait(connection, "log")
        if message then
            table.insert(log, message)
            if #log > h - 4 then
                table.remove(log, 1)
            end
            render()
        elseif message == false then
            connection.close()
            connected = false
            print(r)
        end
    end
end
