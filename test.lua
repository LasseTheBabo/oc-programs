local component = require("component")
local event = require("event")

local gpu = component.gpu
local width, height = gpu.getResolution()

local fuelFactors = {
    2.7,
    2.5,
    2.2,
    2.0,
    1.7,
    1.5,
    1.4,
    1.2,
    1.0
}

local fuels = {
    "Antischrabidium",
    "BF Rocket Fuel",
    "Antimatter",
    "Schrabidium trisulfide",
    "Tritium",
    "Deuterium",
    "Poisonous mud",
    "Liquid oxygen",
    "Liquid hydrogen"
}

local coreFactors = {
    2500,
    800,
    650,
    500
}

local cores = {
    "Thingy",
    "Eye of Harmony",
    "Tiny Wormhole",
    "Vibrant Singularity"
}

local elements = {}

local function newDropDown(x, y, w, options, values)
    local dropDown = {
        x = x,
        y = y,
        w = w,
        h = 1,
        options = options,
        values = values,
        current = 1,
        callback = function(e, x, y, direction)
            e.current = e.current + direction
            if e.current < 1 then e.current = #e.options end
            if e.current > #e.options then e.current = 1 end
        end,
        draw = function(e)
            gpu.setBackground(0xA0A0A0)
            gpu.fill(e.x, e.y, e.w, e.h, " ")
            gpu.set(e.x + 1, e.y, string.format("(%s) %s", e.values[e.current], e.options[e.current]))
            gpu.setBackground(0x000000)
        end
    }

    return dropDown
end

local function newScrollWheel(x, y, min, max)
    local scroll = {
        x = x,
        y = y,
        w = 5,
        h = 1,
        min = min,
        max = max,
        current = min,
        callback = function(e, x, y, direction)
            e.current = e.current + direction
            if e.current < e.min then e.current = e.min end
            if e.current > e.max then e.current = e.max end
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


local c1 = { x = width / 3 - 16, y = 10, w = 32, h = 8 }
elements.fuel1 = newDropDown(c1.x + 1, c1.y + 2, c1.w - 2, fuels, fuelFactors)
elements.fuel2 = newDropDown(c1.x + 1, c1.y + 6, c1.w - 2, fuels, fuelFactors)
elements.core1 = newDropDown(c1.x + 1, c1.y + 4, c1.w - 2, cores, coreFactors)

local c2 = { x = width / 3 * 2 - 16, y = 10, w = 32, h = 8 }
elements.fuel3 = newDropDown(c2.x + 1, c2.y + 2, c2.w - 2, fuels, fuelFactors)
elements.fuel4 = newDropDown(c2.x + 1, c2.y + 6, c2.w - 2, fuels, fuelFactors)
elements.core2 = newDropDown(c2.x + 1, c2.y + 4, c2.w - 2, cores, coreFactors)

elements.emitter = newScrollWheel(2, 10, 1, 100)

local function scalePower(power)
    local i = 1
    local suffix = {"", "k", "M", "G", "T", "P", "Z"}

    while power >= 1000 do
        power = power / 1000
        i = i + 1
    end

    return power .. suffix[i] .. "HE"
end

while true do
    local _, _, x, y, direction = event.pull(0.1, "scroll")
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, width, height, " ")

    gpu.setBackground(0x808080)
    gpu.fill(c1.x, c1.y, c1.w, c1.h, " ")
    gpu.fill(c2.x, c2.y, c2.w, c2.h, " ")
    gpu.set(c1.x + 13, c1.y, "Core 1")
    gpu.set(c2.x + 13, c2.y, "Core 2")

    for _, e in pairs(elements) do
        if e.draw then e:draw() end
        if e.callback and direction then
            if e.x and e.y and e.w then
                if x >= e.x and x <= e.x + e.w and y >= e.y and y <= e.y + e.h then
                    e:callback(x, y, direction)
                end
            end
        end
    end

    local emitter = elements.emitter.current
    local spk = emitter * 100 * 0.95
    local c1P = spk * coreFactors[elements.core1.current] * fuelFactors[elements.fuel1.current] * fuelFactors[elements.fuel2.current]
    local c2P = c1P * coreFactors[elements.core2.current] * fuelFactors[elements.fuel3.current] * fuelFactors[elements.fuel4.current]

    gpu.set(1, 1, "Core 1")
    gpu.set(3, 2, string.format("Fuel usage: %fmB/t", spk / 1000))
    gpu.set(3, 3, string.format("Power: %s", scalePower(c1P * 5000 * 20)))

    gpu.set(1, 4, "Core 2")
    gpu.set(3, 5, string.format("Core 2 fuel usage: %fmB/t", c1P / 1000))
    gpu.set(3, 6, string.format("Power: %s", scalePower(c2P * 5000 * 20)))

    gpu.set(1, 8, "Emitter Power: " .. emitter)
end
