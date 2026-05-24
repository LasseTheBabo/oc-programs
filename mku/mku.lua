local component = require("component")
local robot = require("robot")
local crafting = component.crafting

local items = {
    "powder_iodine",
    "powder_fire",
    "dust",
    "ingot_mercury",
    "morning_glory",
    "syringe_metal_empty",
    "null", "null", "null"
}

local order = {
    powder_iodine = 1,
    powder_fire = 2,
    dust = 3,
    ingot_mercury = 4,
    morning_glory = 5,
    syringe_metal_empty = 6,
    null = 7
}

local grid = {
    1, 2, 3,
    5, 6, 7,
    9, 10, 11
}

local counter = 0

local function out(arr)
    print(table.concat(arr, ", "))
end

local function compare(a, b)
    if order[a] < order[b] then return -1 end
    if order[a] > order[b] then return 1 end
    return 0
end

local function swap(arr, i, j)
    arr[i], arr[j] = arr[j], arr[i]
    robot.select(grid[i])
    robot.transferTo(grid[j])
end

local function reverse(arr, l, r)
    while l < r do
        swap(arr, l, r)
        l = l + 1
        r = r - 1
    end
end

local function nextPermutation(arr)
    local i = #arr - 1

    while i >= 1 and compare(arr[i], arr[i + 1]) >= 0 do
        i = i - 1
    end

    if i < 1 then return false end

    local j = #arr

    while compare(arr[j], arr[i]) <= 0 do
        j = j - 1
    end

    swap(arr, i, j)
    reverse(arr, i + 1, #arr)

    return true
end

while true do
    counter = counter + 1
    print(counter)
    if crafting.craft() then
        print("found!")
        break
    end

    if not nextPermutation(items) then
        print("couldn't find recipe")
        break
    end
end

print("recipe number: " .. counter);
out(items)