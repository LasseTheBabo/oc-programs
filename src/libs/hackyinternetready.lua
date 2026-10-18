-- this is not my work. its from RedstoneParkour

local event = require("event")
local computer = require("computer")
return function(c, addr)
   local id = ""
   for i = 1, 16 do
      id = id .. string.char(math.random(0x41,0x5a))
   end
   local rbc = ""
   local t = setmetatable({}, {__index = c})
   function t.read(n)
      if #rbc > 0 then
	 local ret
	 if n then
	    ret = rbc:sub(1,n)..c.read(n-#rbc)
	    rbc = rbc:sub(n+1)
	 else
	    ret = rbc..c.read()
	    rbc = ""
	    end
	 return ret
      else
	 return c.read(n)
      end
   end

   function t.id()
      return id
   end

   local et = event.timer(0.05, function()
		  if #rbc == 0 then
		     local read = c.read()
		     if not read then return end
		     rbc = rbc..read
		     if #read > 0 then
			computer.pushSignal("internet_ready", addr, id)
		     end
		  end
   end, math.huge)
  function t.close()
    event.cancel(et)
    return c.close()
  end   

   return t
end