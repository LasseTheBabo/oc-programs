local component = require("component")
local event = require("event")
local os = require("os")
local term = require("term")

local anim = require("animations")

local gpu = component.gpu
local width, height = gpu.getResolution()

local running = true

local selectedField = nil

local errorMessage = ""
local loginBg = 0xA0A0A0
local loginFg = 0x101010
local inputLength = 18
local loginWidth = 30
local loginHeight = 5
local loginX = math.floor(width / 2 - loginWidth / 2)
local loginY = math.floor(height / 2 - loginHeight / 2) + 1

local umbrella = anim.smallUmbrella
local umbrellaX = 10
local umbrellaY = height / 2 - #umbrella[1] / 2

local function drawAnimation(x, y, image, f)
    local frame = image[(f % #image) + 1]

    local colors = {
        [" "] = 0x000000, -- black
        ["-"] = 0xFFFFFF, -- white
        ["#"] = 0xFF0000  -- red
    }

    if f >= #image then
        colors["-"], colors["#"] = colors["#"], colors["-"]
    end

    for row, line in ipairs(frame) do
        for col = 1, #line do
            local color = colors[line:sub(col, col)]
            gpu.setBackground(color)
            gpu.set(x + (col * 2) - 2, y + row, "  ")
        end
    end

    --gpu.setBackground(colors[" "]) -- fuck off performance
end

local function createInput(id, x, y, w)
    local input = {
        id = id,
        x = x,
        y = y,
        w = w,
        value = "",
        password = false,
        color = {
            default = 0xFFFFFF,
            selected = 0xD0D0D0
        },
        draw = function(self)
            gpu.setBackground((selectedField == self) and self.color.selected or self.color.default)
            gpu.setForeground(loginFg)
            gpu.fill(self.x, self.y, self.w, 1, " ")
            gpu.set(self.x + 1, self.y, self.password and string.rep("*", #self.value) or self.value)
        end
    }

    return input
end

local inputX = loginX + loginWidth - inputLength - 1
local usernameField = createInput("username", inputX, loginY + 1, inputLength)
local passwordField = createInput("password", inputX, loginY + 3, inputLength)
passwordField.password = true

local function drawLoginForm(x, y, w, h)
    gpu.setForeground(0xFF0000)
    gpu.set(x + w/2 - #errorMessage/2, y + 6, errorMessage)

    gpu.setBackground(loginBg)
    gpu.setForeground(loginFg)
    gpu.fill(x, y, w, h, " ")

    gpu.set(x + 6, y + 1, "USER")
    gpu.set(x + 2, y + 3, "PASSWORD")


    usernameField:draw()
    passwordField:draw()
end

local function submit()
    errorMessage = ""
    if usernameField.value == "" then
        errorMessage = "username can't be empty"
        return false
    end

    if passwordField.value == "" then
        errorMessage = "password can't be empty"
        return false
    end

    return true
end

local events = {
    key_down = function(ch)
        -- 13 ENTER
        -- 8 BACK

        if selectedField then
            local tmp = selectedField.value -- tmp is shorter than the other shit
            if ch > 31 and ch < 127 then
                tmp = tmp .. string.char(ch)
            elseif ch == 8 then
                if #tmp > 0 then
                    tmp = tmp:sub(1, #tmp - 1)
                end
            elseif ch == 13 then
                if submit() then 
                    running = false
                end
            end
            selectedField.value = tmp
        end
    end,

    touch = function(x, y)
        selectedField = nil
        if x >= usernameField.x and x <= usernameField.x + usernameField.w and y == usernameField.y then
            selectedField = usernameField
        elseif x >= passwordField.x and x <= passwordField.x + passwordField.w and y == passwordField.y then
            selectedField = passwordField
        end
    end
}

local i = 0
while running do
    local id, _, a, b = event.pullFiltered(0.2, function(e) return events[e] ~= nil end)

    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    term.clear()

    drawAnimation(umbrellaX, umbrellaY, umbrella, i % (#umbrella * 2))
    gpu.set(umbrellaX + 3, umbrellaY + #umbrella[1] + 2, "Umbrella corp.")
    gpu.set(umbrellaX - 4, umbrellaY + #umbrella[1] + 4, "\"OUR BUSINESS IS LIFE ITSELF\"")
    i = i + 1

    drawLoginForm(loginX, loginY, loginWidth, loginHeight)
    
    if events[id] then events[id](a, b) end
end

gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
term.clear()
print("username: " .. usernameField.value)
print("password: " .. passwordField.value)