local os = require("os")
local tele = {}

function tele.split(msg)
   local ret = {}
   for x in msg:gmatch("[^\t]+") do
      table.insert(ret, x)
   end
   return ret
end

function tele.query(connection, ...)
   connection:write(table.concat({...}, "\t").."\n")
end

function tele.queryWait(connection, ...)
    while true do
        local response

        repeat
            response = connection:read("\n")
            os.sleep(0.1)
        until response

        local parts = tele.split(response)

        for _, pattern in ipairs({...}) do
            local match = table.pack(response:match(pattern))
            if parts[1] == pattern then
                return table.unpack(parts, 2) -- 2 because only return message -> {command, message}
            end
        end
    end
end

return tele