local component = require("component")
local os = require("os")
local redstone = component.redstone

local red = {}

function red.setRedstone(side, value)
    redstone.setOutput(side, value)
end

function red.readRedstone(side)
    return redstone.getInput(side)
end

function red.pulseRedstone(side)
    red.setRedstone(side, 15)
    os.sleep(0.1)
    red.setRedstone(side, 0)
end

return red