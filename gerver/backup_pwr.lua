local component = require("component")
local os = require("os")
local thread = require("thread")

local pwr = component.ntm_pwr_control
local battery = component.ntm_energy_storage

if not pwr then
    print("This program requires a PWR to run!")
    return
end

if not battery then
    print("This program requires a battery to run!")
    return
end

local running = true

function start()
    thread.create(function()
        while running do
            local power, maximum, delta = battery.getEnergyInfo()
            local percentage = power * 100 / maximum
            pwr.setLevel(percentage > 99 and 100 or 0)

            os.sleep(0.1)
        end
    end)
end

function stop()
    running = false
end
