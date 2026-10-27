local stem_c2 = require("stem-c2")
local groups = require("groups")

local bridge, r = stem_c2.new({
    domain_path = "/etc/stem-domain.env",
    channel_path = "/etc/node-channel.env",
    secret_path = "/etc/totp-secret.env",
    name_path = "/etc/stem-name.env",
    silent = true
})

if not bridge then
    print("stem connection failed: " .. r)
    os.exit()
end

local function update(pkg)
    bridge:send(string.format("updating %s", pkg[1]))
    os.execute(string.format("lpm update %s", pkg[1]))
    bridge:send("rebooting...")
    os.execute("reboot")
end

bridge:registerAuthorized(bridge.name, update)

for _, group in ipairs(groups) do
    bridge:registerAuthorized(group, update)
end

function start()
    bridge:start()
end

function stop()
    bridge:stop()
end

function debug()
    bridge:run()
end