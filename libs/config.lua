local serialization = require("serialization")

local config = {}

function config.saveConfig(path, cfg)
    local h, r = io.open(path, "wb")
    if not h then return false, "unable to open config: "..r end
    h:write(serialization.serialize(cfg, true))
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

function config.loadConfig(path, cfg1)
    local h, r = io.open(path, "rb")
    if not h then return false, "unable to open config: "..r end
    local data = h:read("*a")
    h:close()
    local cfg2, r = serialization.unserialize(data)
    if not cfg2 then return false, "unable to unserialize config: "..r end
    config.mergeRecursive(cfg1, cfg2)
    return true
end

return config