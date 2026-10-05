-- Text UI

local component = require("component")

local gpu = component.gpu

local tui = {}

tui.colors = {
    BLACK = 0x000000,
    RED = 0xFF0000,
    GREEN = 0x00FF00,
    BLUE = 0x0000FF,
    YELLOW = 0xFFFF00,
    WHITE = 0xFFFFFF,

    GREY = 0x808080,
    LIGHT_GREY = 0xB0B0B0
}

function tui.newButton(x, y, w, h, title, defaultColor, pressColor, callback)
    local button = {
        x = x,
        y = y,
        w = w,
        h = h,
        title = title,
        color = {
            default = defaultColor,
            pressed = pressColor
        },
        callback = callback,
        handleEvent = function(e, ev)
            e.state = false

            if ev.type ~= "touch" then return end
            if not (ev.x >= e.x and ev.x <= e.x + e.w and ev.y >= e.y and ev.y <= e.y + e.h) then return end

            e.state = true
            callback()
        end,
        state = false,
        draw = function(btn)
            gpu.setBackground(btn.state and btn.color.pressed or btn.color.default)
            gpu.fill(btn.x, btn.y, btn.w, btn.h, " ")
            gpu.set(btn.x + (btn.w - #btn.title) / 2, btn.y + (btn.h - 1) / 2, (title or ""))
            gpu.setBackground(0x000000)
        end
    }

    return button
end

function tui.newDropDown(x, y, w, options)
    local dropDown = {
        x = x,
        y = y,
        w = w,
        h = 1,
        options = options,
        current = 1,
        handleEvent = function(e, ev)
            if ev.type ~= "scroll" then return end
            if not (ev.x >= e.x and ev.x <= e.x + e.w and ev.y == e.y) then return end

            e.current = e.current + ev.direction
            if e.current < 1 then e.current = #e.options end
            if e.current > #e.options then e.current = 1 end
        end,
        draw = function(e)
            local item = e.options[e.current]

            gpu.setBackground(0xA0A0A0)
            gpu.fill(e.x, e.y, e.w, e.h, " ")
            gpu.set(e.x + 1, e.y, string.format("(%s) %s", item.factor, item.name))
            gpu.setBackground(0x000000)
        end
    }

    return dropDown
end

function tui.newScrollWheel(x, y, min, max)
    local scroll = {
        x = x,
        y = y,
        w = 5,
        h = 1,
        min = min,
        max = max,
        current = min,
        handleEvent = function(e, ev)
            if ev.type ~= "scroll" then return end
            if not (ev.x >= e.x and ev.x <= e.x + e.w and ev.y == e.y) then return end

            e.current = math.min(e.max, math.max(e.min, e.current + ev.direction))
        end,
        draw = function(e)
            gpu.setBackground(0xA0A0A0)
            gpu.fill(e.x, e.y, e.w, e.h, " ")
            gpu.set(e.x + 1, e.y, tostring(e.current))
            gpu.setBackground(0x000000)
        end
    }

    return scroll
end

function tui.newPanel(x, y, w, h, title)
    local panel = {
        x = x,
        y = y,
        w = w,
        h = h,
        title = title or "",
        children = {},
        handleEvent = function(e, ev)
            for _, c in ipairs(e.children) do c:handleEvent(ev) end
        end,
        draw = function(e)
            gpu.setBackground(0x808080)
            gpu.fill(e.x, e.y, e.w, e.h, " ")
            if e.title ~= "" then
                local middle = (e.w - #e.title) / 2
                gpu.set(e.x + middle, e.y, title)
            end

            for _, c in ipairs(e.children) do c:draw() end
        end,
        add = function(e, c)
            table.insert(e.children, c)
        end
    }

    return panel
end

return tui
