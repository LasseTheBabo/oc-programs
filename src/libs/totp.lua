-- i know this is vibe coded and idgaf because totp is brainfuck

local fs = require("filesystem")

local totp = {}

function totp.now()
  local path = "/tmp/.timestamp"
  local f = assert(io.open(path, "w"))
  f:write("x"); f:close()
  return math.floor(fs.lastModified(path) / 1000)
end

-- SHA1 + HMAC
function totp.sha1(msg)
    local h0, h1, h2, h3, h4 = 0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0
    msg = msg .. "\128" .. string.rep("\0", (55 - #msg) % 64) .. string.pack(">I8", #msg * 8)
    for p = 1, #msg, 64 do
        local w = { string.unpack(">I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4", msg, p) }
        for i = 17, 80 do
            local x = w[i - 3] ~ w[i - 8] ~ w[i - 14] ~ w[i - 16]
            w[i] = ((x << 1)|(x >> 31)) & 0xffffffff
        end
        local a, b, c, d, e = h0, h1, h2, h3, h4
        for i = 1, 80 do
            local f, k
            if i <= 20 then
                f = (b & c)|((~b) & d); k = 0x5A827999
            elseif i <= 40 then
                f = b ~ c ~ d; k = 0x6ED9EBA1
            elseif i <= 60 then
                f = (b & c)|(b & d)|(c & d); k = 0x8F1BBCDC
            else
                f = b ~ c ~ d; k = 0xCA62C1D6
            end
            local t = ((((a << 5)|(a >> 27)) + f + e + k + w[i])) & 0xffffffff
            e = d; d = c; c = ((b << 30)|(b >> 2)) & 0xffffffff; b = a; a = t
        end
        h0 = (h0 + a) & 0xffffffff; h1 = (h1 + b) & 0xffffffff; h2 = (h2 + c) & 0xffffffff
        h3 = (h3 + d) & 0xffffffff; h4 = (h4 + e) & 0xffffffff
    end
    return string.pack(">I4I4I4I4I4", h0, h1, h2, h3, h4)
end

function totp.hmac_sha1(key, msg)
    if #key > 64 then key = totp.sha1(key) end
    key = key .. string.rep("\0", 64 - #key)
    local ip, op = {}, {}
    for i = 1, 64 do
        local b = key:byte(i); ip[i] = string.char(b ~ 0x36); op[i] = string.char(b ~ 0x5c)
    end
    return totp.sha1(table.concat(op) .. totp.sha1(table.concat(ip) .. msg))
end

local A = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
function totp.b32enc(s)
    local out, buf, bits = {}, 0, 0
    for i = 1, #s do
        buf = (buf << 8)|s:byte(i); bits = bits + 8
        while bits >= 5 do
            bits = bits - 5; local v = (buf >> bits) & 31; out[#out + 1] = A:sub(v + 1, v + 1)
        end
        buf = buf & ((1 << bits) - 1)
    end
    if bits > 0 then
        local v = (buf << (5 - bits)) & 31; out[#out + 1] = A:sub(v + 1, v + 1)
    end
    return table.concat(out)
end

function totp.b32dec(s)
    local out, buf, bits = {}, 0, 0
    for c in s:upper():gsub("[^A-Z2-7]", ""):gmatch(".") do
        buf = (buf << 5)|(A:find(c, 1, true) - 1); bits = bits + 5
        if bits >= 8 then
            bits = bits - 8; out[#out + 1] = string.char((buf >> bits) & 255); buf = buf & ((1 << bits) - 1)
        end
    end
    return table.concat(out)
end

-- TOTP
function totp.totp(secret, t, digits, step)
    digits, step = digits or 6, step or 30
    local h = totp.hmac_sha1(secret, string.pack(">I8", t // step))
    local o = h:byte(20) & 0xf
    local n = string.unpack(">I4", h, o + 1) & 0x7fffffff
    local m = 1; for _ = 1, digits do m = m * 10 end
    return string.format("%0" .. digits .. "d", n % m)
end

local lastStep = 0

function totp.verify(secret, code, now)
    local step = now // 30
    for s = step - 1, step + 1 do
        if s > lastStep and totp.totp(secret, s * 30) == code then
            lastStep = s; return true
        end
    end
    return false
end

return totp
