local component = require("component")
local term = require("term")
local os = require("os")

local gpu = component.gpu


local small = {
    { -- 1
        "  -####-  ",
        " --####-- ",
        "----##----",
        "##--##--##",
        "####  ####",
        "####  ####",
        "##--##--##",
        "----##----",
        " --####-- ",
        "  -####-  "
    },
    { -- 2
        "  --####  ",
        " ---###-- ",
        "#---###---",
        "###-##----",
        "####  ####",
        "####  ####",
        "----##-###",
        "---###---#",
        " --###--- ",
        "  ####--  "
    },
    { -- 3
        "  ----##  ",
        " #----### ",
        "###--###--",
        "####-##---",
        "--##  ----",
        "----  ##--",
        "---##-####",
        "--###--###",
        " ###----# ",
        "  ##----  "
    }
}

local big = {
    {
        "      ######      ",
        "    --######--    ",
        "   ---######---   ",
        "  -----####-----  ",
        " ------####------ ",
        " ------####------ ",
        "###-----##-----###",
        "######--##--######",
        "########  ########",
        "########  ########",
        "######--##--######",
        "###-----##-----###",
        " ------####------ ",
        " ------####------ ",
        "  -----####-----  ",
        "   ---######---   ",
        "    --######--    ",
        "      ######      "
    },
    {
        "      ---###      ",
        "    -----#####    ",
        "   ------######   ",
        "  ##-----######-  ",
        " ####----#####--- ",
        " #####---####---- ",
        "#######--###------",
        "########-##-------",
        "########  --------",
        "--------  ########",
        "-------##-########",
        "------###--#######",
        " ----####---##### ",
        " ---#####----#### ",
        "  -######-----##  ",
        "   ######------   ",
        "    #####-----    ",
        "      ###---      "
    }
}

local x = 5
local y = 5
local frames = 6

local function drawAnimation(f)
    local frame = small[(f % (frames/2)) + 1]

    local colors = {
        [" "] = 0x000000, -- black
        ["-"] = 0xFFFFFF, -- white
        ["#"] = 0xFF0000  -- red
    }

    if f >= (frames/2) then -- inefficient swap for less manual frames
        local tmp = colors["-"]
        colors["-"] = colors["#"]
        colors["#"] = tmp
    end

    for i, line in ipairs(frame) do
        for j = 1, #line do
            local color = colors[line:sub(j, j)]
            gpu.setBackground(color)
            gpu.set(x + (j * 2), y + i, "  ")
        end
    end

    --gpu.setBackground(colors[" "]) -- fuck off performance
end

local i = 0
while true do
    term.clear()
    drawAnimation(i % frames)
    i = i + 1
    os.sleep(0.1)
end
