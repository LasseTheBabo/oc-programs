local stem_c2 = require("stem-c2")
local totp = require("totp")

local bridge, r = stem_c2.new({
    domain_path = "stem-domain.env",
    channel_path = "stem-channel.env",
    secret_path = "totp-secret.env",
    name = "TEST"
})

if not bridge then
    print("stem connection failed: " .. r)
    os.exit()
end

bridge:register("ping", function()
    bridge:send("pong")
end)

bridge:registerAuthorized("reboot", function()
    bridge:send("rebooting")
    os.execute("reboot")
end)

-- bridge:register("debug", function(args)
-- local tmp = totp.totp(bridge.secret, totp.now()).." "..args[#args].." "..totp.now()
--     bridge:send("debug here: "..tmp)
--     print("debug: "..tmp)
-- end)

bridge:run()

