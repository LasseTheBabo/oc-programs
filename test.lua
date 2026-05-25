local component = require("component")
local event = require("event")
local logger = require("logger")

logger.log = {}

while true do
    local _, _, _, _, direction = event.pull(0.1, "scroll")

    if direction then
        logger.handleScroll(-direction)
    end

    logger.add("hallo")
end
