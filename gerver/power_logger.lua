local component = require("component")
local event = require("event")
local os = require("os")
local term = require("term")
local thread = require("thread")

local last_time = os.time()

local consumption = 0
local running = true

local function endtick()
    local time = os.time()

    last_time = time
    while last_time == os.time() do
        os.sleep(0)
    end
end

thread.create(function()
    while running do
        endtick()
        local deltaTick = component.ntm_power_gauge.getTransfer()
        consumption = consumption + deltaTick
    end
end)


while running  do
    local event = event.pull(0.1)
    term.clear()

    term.setCursor(1, 1)
    term.write("Press Ctrl+C to exit")

    term.setCursor(1, 3)
    term.write(string.format("Consumption: %s", consumption))

    -- maybe log in a file later?


    if event == "interrupted" then
        running = false
    end
end