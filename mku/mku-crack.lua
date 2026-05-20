-- Beispiel-Array (Lua nutzt 1-basierte Indizes)
local items = {
    "powder_iodine",
    "powder_fire",
    "dust",
    "ingot_mercury",
    "syringe_metal_empty",
    "nil", "nil", "nil"
}

-- Vergleichsarray (musst du selbst definieren)
local known = {
    "morning_glory",
    "nil",
    "ingot_mercury",
    "powder_fire",
    "syringe_metal_empty",
    "powder_iodine",
    "nil",
    "nil",
    "dust"
}

local count = 1

local function arraysEqual(a, b) if #a ~= #b then return false end for i = 1, #a do if a[i] ~= b[i] then return false end end return true end

local function out(arr)
    print(table.concat(arr, ", "))
end

local function swap(arr, i, j)
    local tmp = arr[i]
    arr[i] = arr[j]
    arr[j] = tmp
end

local function permuteUnique(arr, index)
    if index > #arr then
        if arraysEqual(arr, known) then
            out(arr)
        end
        count = count + 1
        print(count)
        return
    end

    local used = {}

    for i = index, #arr do
        if used[i] then goto continue end
        used[i] = true

        swap(arr, index, i)
        permuteUnique(arr, index + 1)
        swap(arr, index, i)

        ::continue::
    end
end

permuteUnique(items, 1)