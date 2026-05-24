

local function arraysEqual(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local known = {
    "morning_glory",
    "null",
    "ingot_mercury",
    "powder_fire",
    "syringe_metal_empty",
    "powder_iodine",
    "null",
    "null",
    "dust"
}