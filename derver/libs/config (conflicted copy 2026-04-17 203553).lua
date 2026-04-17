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

function config.loadConfig(configPath, cfg1)
    local h, r = io.open(configPath, "rb")
    if not h then return nil, "unable to open config: "..r end
    local data = h:read("*a")
    h:close()
    local cfg2, r = serialization.unserialize(data)
    if not cfg2 then return nil, "unable to unserialize config: "..r end
    return config.mergeRecursive(cfg1, cfg2)
end

function config.resetConfig(configPath)
    local h, r = io.open(configPath, "wb")
    if not h then
      error("failed to open file: " .. r)
    end

    h:write("{}")
    h:close()
end

function config.load(configPath, cfg)
    do local s, r = config.loadConfig(configPath, cfg)
        if not s then
            print(r)
            print("using default config")
        end
    end
    config.saveConfig(configPath, cfg)
end

return config