local stem_c2 = require("stem-c2")
local groups = require("groups")

local bridge, r = stem_c2.new({
    domain_path = "/etc/stem-domain.env",
    channel_path = "/etc/stem-channel.env",
    secret_path = "/etc/totp-secret.env",
    name = "/etc/stem-name.env"
})

if not bridge then
    print("stem connection failed: " .. r)
    os.exit()
end

bridge:registerAuthorized("update", function(name, package)
    local in_group = false

    for _, n in ipairs(groups) do
        if name == n then in_group = true end
    end

    if not in_group or name ~= bridge.name then return end


    os.execute(string.format("lpm update %s", package))
end)

function start()
    bridge:start()
end

function stop()
    bridge:stop()
end
