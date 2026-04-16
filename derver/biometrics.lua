local event = require("event")
local component = require("component")
local serialization = require("serialization")

local configPath = "/etc/dfc.cfg"

local config = {
    userBiometrics = {}
}

local function saveConfig()
    local h, r = io.open(configPath, "wb")
    if not h then return false, "unable to open config: "..r end
    h:write(serialization.serialize(config, true))
    h:close()
    return true
end

local function mergeRecursive(t, from)
    for k, v in pairs(from) do
        if type(v) == "table" and type(t[k]) == "table" then
            mergeRecursive(t[k], v)
        else
            t[k] = v
        end
    end
end

local function loadConfig()
    local h, r = io.open(configPath, "rb")
    if not h then return false, "unable to open config: "..r end
    local data = h:read("*a")
    h:close()
    local cfg, r = serialization.unserialize(data)
    if not cfg then return false, "unable to unserialize config: "..r end
    mergeRecursive(config, cfg)
    return true
end

local function resetConfig()
    local h, err = io.open(configPath, "wb")
    if not h then
      error("failed to open file: " .. err)
    end

    h:write("{}")
    h:close()
end

do local s, r = loadConfig()
    if not s then
        print(r)
        print("using default config")
    end
end
saveConfig()

local function contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local function addPlayer(id)
    if not contains(config.userBiometrics, id) then
        table.insert(config.userBiometrics, id)
    end
end

local function removePlayer(id)
    for i, v in iparis(tbl) do
        if v == value then
            table.remove(tbl, i)
        end
    end
end


local _, _, playerId = event.pull("bioReader")


--resetConfig()
addPlayer(playerId)
saveConfig()

print(contains(config.userBiometrics, playerId))