local internet = require("internet")
local serialization = require("serialization")
local os = require("os")

local HOST = "127.0.0.1"
local PORT = 25565

-- Hilfsfunktion: Konvertiert eine Zahl in ein Minecraft-VarInt-Byte-Muster
local function writeVarInt(value)
  local bytes = ""
  while true do
    local b = bit32.band(value, 0x7F)
    value = bit32.rshift(value, 7)
    if value ~= 0 then
      b = bit32.bor(b, 0x80)
      bytes = bytes .. string.char(b)
    else
      bytes = bytes .. string.char(b)
      break
    end
  end
  return bytes
end

-- Hilfsfunktion: Liest einen VarInt aus dem Stream
local function readVarInt(socket)
  local result = 0
  local position = 0
  while true do
    local byteStr = socket:read(1)
    if not byteStr or #byteStr == 0 then return nil end
    local b = string.byte(byteStr)
    result = bit32.bor(result, bit32.lshift(bit32.band(b, 0x7F), position))
    if bit32.band(b, 0x80) == 0 then break end
    position = position + 7
    if position >= 35 then return nil end
  end
  return result
end

-- 1. Verbindung aufbauen
local socket, err = internet.open(HOST, PORT)
if not socket then
  print("Fehler beim Verbinden: " .. tostring(err))
  return
end

-- 2. Handshake-Paket bauen (ID 0x00, Version 765, Host, Port 25565, State 1)
local hostBytes = HOST
local handshakeData = writeVarInt(0x00)
  .. writeVarInt(765)
  .. writeVarInt(#hostBytes) .. hostBytes
  .. string.char(math.floor(PORT / 256), PORT % 256)
  .. writeVarInt(1)

-- Paket mit Längenpräfix senden
socket:write(writeVarInt(#handshakeData) .. handshakeData)

-- 3. Request-Paket senden (ID 0x00, Länge 1)
local requestData = writeVarInt(0x00)
socket:write(writeVarInt(#requestData) .. requestData)
socket:flush()

-- 4. Antwort lesen
local packetLength = readVarInt(socket)
local packetID = readVarInt(socket)
local jsonLength = readVarInt(socket)

if not jsonLength then
  print("Keine gültige Antwort vom Server erhalten.")
  socket:close()
  return
end

-- JSON-String vollständig empfangen
local jsonRaw = ""
while #jsonRaw < jsonLength do
  local chunk = socket:read(jsonLength - #jsonRaw)
  if chunk then
    jsonRaw = jsonRaw .. chunk
  else
    os.sleep(0.05)
  end
end

socket:close()

-- 5. Auswertung der Spielersample-Daten
print("\n--- SERVER STATUS ---")
-- Einfaches Auslesen der Spielerliste aus dem empfangenen JSON-Text
local onlinePlayers = jsonRaw:match('"online":%s*(%d+)')
local maxPlayers = jsonRaw:match('"max":%s*(%d+)')

print("Spieler online: " .. (onlinePlayers or "0") .. "/" .. (maxPlayers or "0"))

print("\nSpielerliste (Sample):")
for name in jsonRaw:gmatch('"name":%s*"([^"]+)"') do
  print("- " .. name)
end