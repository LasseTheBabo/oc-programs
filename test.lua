local component = require("component")
local os = require("os")

local gpu = component.gpu

local enclave = {
    {
        "                              ",
        "              ##              ",
        "        ##           ##       ",
        "                              ",
        "    ##                  ##    ",
        "                              ",
        "                              ",
        "  ##                      ##  ",
        "                              ",
        "                              ",
        "    ##                  ##    ",
        "                              ",
        "        ##          ##        ",
        "              ##              ",
        "                              "
    },
    {
        "          ..........          ",
        "      ........##.........     ",
        "    ....##...........##....   ",
        "  ..........................  ",
        "  ..##..................##..  ",
        "...........########...........",
        "...........##.................",
        "..##.......########.......##..",
        "...........##.................",
        "...........########...........",
        "  ..##..................##..  ",
        "  ..........................  ",
        "    ....##..........##....    ",
        "      ........##........      ",
        "          ..........          "
    }
}

local function drawImage(x, y, image)

    local colors = {
        [" "] = 0x000000, -- black
        ["#"] = 0xFFFFFF, -- white
        ["."] = 0x000000, -- white
    }

    local charMap = image[1]
    local colorMap = image[2]

    for row = 1, #charMap do
        local line1 = charMap[row]
        local line2 = colorMap[row]
        for col = 1, #line1 do
            local ch = line1:sub(col, col)
            local color = colors[line2:sub(col, col)]
            gpu.setBackground(color)
            gpu.set(x + col - 1, y + row - 1, ch)
        end
    end
end

while true do
    drawImage(10, 10, enclave)
    os.sleep(0.1)
end