local component = require("component")
local event = require("event")
local os = require("os")

-- Address DataBase
-- not Android Debug Bridge

local adb = {}

function adb.waitForNewAddress(filter)
    while true do
        local _, address, componentType = event.pull(0.1, "component_added")

        if not filter or componentType == filter then
            return address
        end
    end
end

function adb.getAddresses(path)
    if not path then return nil, "invalid path" end

    local file, r = io.open(path)
    if not file then return file, r end

    local ret = {}
    for line in file:lines() do
        if line ~= "" then
            local name, address = line:match("^([^\t]+)\t([^\t]+)$")

            if not name then
                file:close()
                return name, "invalid line: " .. line
            end
            ret[name] = address
        end
    end

    file:close()
    return ret
end

function adb.getAddress(path, name)
    if not name then return name, "invalid name" end

    local db, r = adb.getAddresses(path)
    if not db then return db, r end

    local address = db[name]

    return address
end

function adb.addAddress(path, name, address)
    -- i hate exceptions
    local db = adb.getAddresses(path)
    if db and db[name] then
        return db, "name already exists"
    end

    local file, r = io.open(path, "a")
    if not file then return file, r end

    if name:find("[\t\n]") then
        return name, "invalid name"
    end

    if address:find("[\t\n]") then
        return address, "invalid address"
    end

    file:write(name .. "\t" .. address .. "\n")
    file:close()

    return true
end

function adb.delAddress(path, name)
    local db, r = adb.getAddresses(path)
    if not db then return db, r end
    if not db[name] then return nil, "name not found" end

    db[name] = nil

    local file, r = io.open(path, "w")
    if not file then return file, r end

    for n, a in pairs(db) do
        file:write(n .. "\t" .. a .. "\n")
    end

    file:close()
    return true
end

return adb
