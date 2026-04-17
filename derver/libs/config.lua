local serialization = require("serialization")

local config = {}

function config.saveConfig(configPath, config)
    local h, r = io.open(configPath, "wb")
    if not h then return false, "unable to open config: "..r end
    h:write(serialization.serialize(config, true))
    h:close()
    return true
end

function config.mergeRecursive(t, from)
    for k, v in pairs(from) do
        if type(v) == "table" and type(t[k]) == "table" then
            config.mergeRecursive(t[k], v)
        else
            t[k] = v
        end
    end
end

function config.loadConfig(configPath)
    local h, r = io.open(configPath, "rb")
    if not h then return nil, "unable to open config: "..r end
    local data = h:read("*a")
    h:close()
    local cfg, r = serialization.unserialize(data)
    if not cfg then return nil, "unable to unserialize config: "..r end
    return config.mergeRecursive(config, cfg)
end

function config.resetConfig(configPath)
    local h, r = io.open(configPath, "wb")
    if not h then
      error("failed to open file: " .. r)
    end

    h:write("{}")
    h:close()
end

function config.load(configPath, config)
    do local s, r = config.loadConfig(configPath)
        if not s then
            print(r)
            print("using default config")
        end
    end
    config.saveConfig(configPath, config)
end

return config