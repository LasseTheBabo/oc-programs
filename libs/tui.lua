local component = require("component")
local event = require("event")

local gpu = component.gpu

local tui = {}

local elements = {}
tui.colors = {
    BLACK =     0x000000,
    RED =       0xFF0000,
    GREEN =     0x00FF00,
    BLUE =      0x0000FF,
    YELLOW =    0xFFFF00,
    WHITE =     0xFFFFFF
}

function tui.addButton(x, y, w, h, defaultColor, pressColor, callback)
    local button = {
        x = x,
        y = y,
        w = w,
        h = h,
        color = {
            default = defaultColor,
            pressed = pressColor
        },
        callback = callback,
        state = false,
        draw = function(btn)
            gpu.setBackground(btn.state and btn.color.pressed or btn.color.default)
            gpu.fill(btn.x, btn.y, btn.w, btn.h, " ")
            gpu.setBackground(0x000000)
        end
    }

    table.insert(elements, button)
end

function tui.runLoop(events)
    event.pullFiltered(0.1, function (id) return events[id] ~= nil end)
end

return tui