local component = require("component")
local os = require("os")
local gpu = component.gpu
local w, h = gpu.getResolution()

local function clear()
    gpu.fill(1, 1, w, h, " ")
end

local logList = {}
local logX = 3
local logY = 3
local logLength = h - 4


local function render()
    clear()
    gpu.set(2, 1, "q: quit")
    gpu.fill(1, 2, w, 1, "-")

    for i, line in ipairs(logList) do
        gpu.set(logX, logY + i, line)
    end
end

local function log(message)
    table.insert(logList, message)
    if #logList > logLength then
        table.remove(logList, 1)
    end
    render()
end

render()

local i = 0

while true do
    log(tostring(i))
    render()
    os.sleep(0.05)
    i = i + 1
end