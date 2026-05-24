local component = require("component")
local term = require("term")
local os = require("os")

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
    gpu.set(1, 1, string.format("Status: %s", status))

    for i, line in ipairs(log) do
        gpu.set(2, i + 3, line)
    end
end

local function setStatus(message)
    status = message
    render()
end

for i = 1, 100, 1 do
    table.insert(log, i .. " fuck you")
    if #log > h - 4 then
        table.remove(log, 1)
    end
    render()
    os.sleep(0.05)
end