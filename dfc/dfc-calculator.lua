local component = require("component")
local event = require("event")

local tui = require("tui")

local gpu = component.gpu
local width, height = gpu.getResolution()

local elements = {}

local fuels = {
    { name = "Antischrabidium",        factor = 2.7 },
    { name = "BF Rocket Fuel",         factor = 2.5 },
    { name = "Antimatter",             factor = 2.2 },
    { name = "Schrabidium trisulfide", factor = 2.0 },
    { name = "Tritium",                factor = 1.7 },
    { name = "Deuterium",              factor = 1.5 },
    { name = "Poisonous mud",          factor = 1.4 },
    { name = "Liquid oxygen",          factor = 1.2 },
    { name = "Liquid hydrogen",        factor = 1.0 }
}

local cores = {
    { name = "Thingy",              factor = 2500 },
    { name = "Eye of Harmony",      factor = 800 },
    { name = "Tiny Wormhole",       factor = 650 },
    { name = "Vibrant Singularity", factor = 500 }
}

local function scalePower(power)
    local i = 1
    local suffix = { "", "k", "M", "G", "T", "P", "Z" }

    while power >= 1000 do
        power = power / 1000
        i = i + 1
    end

    return string.format("%.4f%sHE", power, suffix[i])
end



do
    local p = tui.newPanel(width / 3 - 16, 10, 32, 8, "Core 1")
    p:add(tui.newDropDown(p.x + 1, p.y + 2, p.w - 2, fuels))
    p:add(tui.newDropDown(p.x + 1, p.y + 6, p.w - 2, fuels))
    p:add(tui.newDropDown(p.x + 1, p.y + 4, p.w - 2, cores))
    table.insert(elements, p)
end

do
    local p = tui.newPanel(width / 3 * 2 - 16, 10, 32, 8, "Core 2")
    p:add(tui.newDropDown(p.x + 1, p.y + 2, p.w - 2, fuels))
    p:add(tui.newDropDown(p.x + 1, p.y + 6, p.w - 2, fuels))
    p:add(tui.newDropDown(p.x + 1, p.y + 4, p.w - 2, cores))
    table.insert(elements, p)
end

do
    local p = tui.newPanel(10, 13, 9, 3, "Emitter")
    p:add(tui.newScrollWheel(p.x + 2, p.y + 1, 1, 100))
    table.insert(elements, p)
end

while true do
    local cType, address, x, y, direction = event.pull(0.1)
    local ev = { type = cType, address = address, x = x, y = y, direction = direction }

    for _, p in ipairs(elements) do p:handleEvent(ev) end

    gpu.setBackground(0x000000)
    gpu.fill(1, 1, width, height, " ")

    for _, p in ipairs(elements) do p:draw() end

    local emitterPower = elements[3].children[1].current
    local spk = emitterPower * 100 * 0.95

    local function corePower(core, fuel1, fuel2)
        return core.options[core.current].factor *
            fuel1.options[fuel1.current].factor *
            fuel2.options[fuel2.current].factor
    end


    local c1P = spk * corePower(elements[1].children[3], elements[1].children[1], elements[1].children[2])
    local c2P = c1P * corePower(elements[2].children[3], elements[2].children[1], elements[2].children[2])

    local c1F = math.ceil(spk / 1000)
    local c2F = math.ceil(c1P / 1000)

    gpu.set(1, 1, "Core 1")
    gpu.set(3, 2, string.format("Fuel usage: %dmB/t", c1F))
    gpu.set(3, 3, string.format("Power: %s", scalePower(c1P * 5000 * 20)))

    gpu.set(1, 5, "Core 2")
    gpu.set(3, 6, string.format("Fuel usage: %dmB/t", c2F))
    gpu.set(3, 7, string.format("Power: %s", scalePower(c2P * 5000 * 20)))
    gpu.set(3, 8, string.format("Core works: " .. (c2F <= 128000 and "yes" or "no")))
end
