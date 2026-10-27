local component = require("component")

local dipoles = {}

local function init()
  local addresses = component.list("ntm_pa_dipole")
  
  for address in addresses do
    local dipole = component.proxy(address)
    for i=1,5 do
      if dipole.getThreshold() == i then
        dipoles[i] = dipole.address
      end
    end
  end
end

init()
print(dipoles)
