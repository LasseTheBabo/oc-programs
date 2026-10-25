local stem_c2 = require("stem-c2")

local bridge, r = stem_c2.new({
    domain_path = "/etc/stem-domain.env",
    channel_path = "/etc/c2-channel.env",
    secret_path = "/etc/totp-secret.env",
    name_path = "/etc/stem-name.env"
})

if not bridge then
    print("stem connection failed: " .. r)
    os.exit()
end

bridge:register("online", function()
    local file, r = io.open("/etc/uptime.txt")
    if not file then return false, r end

    for line in file:lines() do
        bridge:send(line)
    end

    file:close()
end)

bridge:registerAuthorized("reboot", function()
    bridge:send("bye")
    os.execute("reboot")
end)

function start()
    bridge:start()
end

function stop()
    bridge:stop()
end