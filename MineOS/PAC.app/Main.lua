local GUI = require("GUI")
local system = require("System")
local component = require("component")
local fs = require("Filesystem")

-------------------------------------------------------------------------------
local gold = component.proxy("d06bdf77-3aa2-4549-9143-67c540a98065")
local nbti = component.proxy("707aadeb-87dd-479c-b308-79c86ea863b4")
local bscco = component.proxy("a9065e44-5d88-4dfd-a441-74a81a681920")

local limit = {
    gold = {
        lower = 0,
      upper = 2200,
    },
    nbti = {
        lower = 1500,
        upper = 8400,
    },
    bscco = {
        lower = 7500,
        upper = 15000,
    }
}

local targets = {
    -- { name = 'nugget', momentum = 100 },
    { name = 'Antimatter', momentum = 300 },
    { name = 'Antischrabidium', momentum = 400 },
    { name = 'Muon', momentum = 2500 },
    { name = 'Tachyon', momentum = 5000 },
    { name = 'Higgs Boson', momentum = 6500 },
    { name = 'Dark Matter', momentum = 10000 },
    { name = 'Strange Quark', momentum = 12500 },
    { name = 'Sparkticle', momentum = 12500 },
    { name = 'The Digamma Particle', momentum = 70000},
}

local COLORS = {
    bg = 0x444444,
    button = 0x3C3C3C,
    buttonText = 0xA5A5A5,
    buttonPressed = 0xE1E1E1,
    disabledText = 0x5A5A5A,
    text = 0xA5A5A5,
}

local function setDipoles()
    local addresses = component.list("ntm_pa_dipole")
    local dipoles = {}

    for address in addresses do
        local dipole = component.proxy(address)
        for i=1,3 do
            if dipole.getThreshold() == i then
                dipoles[i] = dipole.address
            end
        end
    end

    fs.write("dipoles.json", "")
    for i, dipole in ipairs(dipoles) do
        fs.append("dipoles.json", dipole .. "\n")
    end
end

local function setTarget(momentum)
    momentum = tonumber(momentum)
    if momentum == nil or type(momentum) ~= "number" or momentum <= 0 then
        print('please enter a valid momentum')
        return
    end

    gold.setThreshold(math.min(momentum, limit.gold.upper))
    nbti.setThreshold(math.min(momentum, limit.nbti.upper))
    bscco.setThreshold(math.min(momentum, limit.bscco.upper))
end

local function newButton(width, height, text)
    local button = GUI.button(
        1, 1, width, height,
        COLORS.button, COLORS.buttonText,
        COLORS.buttonPressed, COLORS.button,
        text
    )

    button.colors.disabled.background = COLORS.button
    button.colors.disabled.text = COLORS.disabledText

    return button
end

local workspace, window, menu = system.addWindow(GUI.filledWindow(1, 1, 40, 39, COLORS.bg))
local layout = window:addChild(GUI.layout(1, 1, window.width, window.height, 1, 1))
layout:setAlignment(1, 1, GUI.ALIGNMENT_HORIZONTAL_CENTER, GUI.ALIGNMENT_VERTICAL_BOTTOM)
layout:setMargin(1, 1, 0, 1)

local function init()
    --setDipoles()

    for _, particle in ipairs(targets) do
        local button = newButton(layout.width - 4, 3, particle.name)
        button.onTouch = function()
            setTarget(particle.momentum)
        end

        layout:addChild(button)
    end
end

init()

workspace:draw()
