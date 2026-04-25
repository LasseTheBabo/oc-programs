local component = require("component")
local event = require("event")
local os = require("os")
local term = require("term")

local gpu = component.gpu
local width, height = gpu.getResolution()

gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
term.clear()

local tabs = {}
local selectedTab = "Zirnox"
local tabDefault = 0x000000
local tabSelected = 0x505050

tabs["Test 1 or something"] = function()
    gpu.set(5, 12, "idk")
end

tabs["Zirnox"] = function()
    gpu.fill(3, 6, 10, 10, "X")
end

while true do
    local id, _, x, y = event.pull(0.2, "touch")
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    term.clear()

    gpu.setBackground(tabSelected)
    gpu.fill(1, 2, width, 1, " ")

    local changeTab = false
    if id then
        if id == "touch" and y == 1 then
            changeTab = true
        end
    end

    local tabX = 1
    for name, func in pairs(tabs) do
        if name == selectedTab then
            func()
            gpu.setBackground(tabSelected)
        else
            gpu.setBackground(tabDefault)
        end
        local tabName = " " .. name .. " "
        gpu.set(tabX, 1, tabName)

        if changeTab then
            if x >= tabX and x < tabX + #tabName then
                selectedTab = name
            end
        end

        tabX = tabX + #tabName
    end

    os.sleep(0.1)
end
