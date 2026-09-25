local component = require("component")

local adb = require("adb")

local path = "db.txt"
local name = "test"

adb.addAddress(path, "adr1", "123456")
adb.addAddress(path, "adr2", "1234")
adb.addAddress(path, "adr3", "12345678")

local test, r = adb.delAddress(path, "adr2")
