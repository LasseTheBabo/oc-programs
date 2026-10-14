package.loaded.totp = nil
local totp = require("totp")
local secret = totp.b32dec("JBSWY3DPEHPK3PXP")
print(totp.verify(secret, (...), totp.now()))