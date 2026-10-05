local component = require("component")

local logger = {}

local gpu = component.gpu
local w, h = gpu.getResolution()
local scrollOffset = 0
local firstRow = 4
local lastRow = h

logger.scrollSensitivity = 1
logger.log = {}
logger.header = ""

local function clamp(value, lowest, highest)
    return math.max(lowest, math.min(highest, value))
end

local function drawHeader()
    gpu.set(2, 1, logger.header)
    gpu.fill(1, 2, w, 1, "-")
end

local function drawScrollBar(x, y, h, p, l)
    local height = h ^ 2 / l
    local position = p * h / l

    gpu.fill(x, y, 1, h, "░")
    gpu.fill(x, y + math.floor(position), 1, math.floor(height), "█")
end

local function visibleRange()
    local total = #logger.log
    local maxVisible = lastRow - firstRow

    scrollOffset = clamp(scrollOffset, -(total - 1), -(maxVisible - 1))

    local firstIndex = math.max(1, total + scrollOffset)
    local lastIndex = math.min(total, firstIndex + maxVisible - 1)
    return firstIndex, lastIndex
end

function logger.clearScreen()
    gpu.fill(1, 1, w, lastRow, " ")
end

function logger.render()
    logger.clearScreen()
    drawHeader()
    if #logger.log > lastRow - firstRow then
        drawScrollBar(w, firstRow, lastRow - firstRow, #logger.log + scrollOffset - 1, #logger.log)
    end

    local first, last = visibleRange()
    for i = first, last do
        local y = firstRow - first
        local line = logger.log[i]
        gpu.set(2, y + i, line)
    end
end

function logger.add(message)
    table.insert(logger.log, message)
    if scrollOffset < -(lastRow - firstRow - 1) then
        scrollOffset = scrollOffset - 1
    end
    logger.render()
end

function logger.handleScroll(delta)
    scrollOffset = scrollOffset + delta * logger.scrollSensitivity
    logger.render()
end

return logger