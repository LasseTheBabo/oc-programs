local event = require("event")
local component = require("component")
local term = require("term")

local magnet = 1

print("Please connect the first magnet")

while magnet < 4 do
    local _, address, type = event.pull("component_added")
    if type == "ntm_pa_dipole" then
        if magnet == 1 then
            Gold = component.proxy(address)
            print("Please connect the second magnet")
        elseif magnet == 2 then
            NbTi = component.proxy(address)
            print("Please connect the third magnet")
        else
            BSCCO = component.proxy(address)
        end
        magnet = magnet + 1
    end
end

local recipes = {
    nugget = 100,
    antimatter = 300,
    antischrabidium = 400,
    muon = 2500,
    tachyon = 5000,
    higgs = 6500,
    dark = 10000,
    strange = 12500,
    sparkticle = 12500,
    digamma = 70000
}
local particle = "None"

while true do
    term.clear()
    print("1) Is the correct particle selected?")
    print("2) Are there enough capsules in all detectors?")
    print("3) Are there any outputs stuck in the detectors?\n")
    print("Available Particles:\nChicken Nugget (nugget)\nAntimatter (antimatter)\nAntischrabidium (antischrabidium)\nMuon (muon)\nTachyon (tachyon)\nHiggs Boson (higgs)\nDark Matter (dark)\nStrange Quark (strange)\nSparkticle (sparkticle)\nThe Digamma Particle (digamma)\n\nSelected Particle: " .. particle)
    
    io.write("\n> ")
    local input = io.read()
    if recipes[input] then
        local momentum = recipes[input]
        particle = input
        Gold.setThreshold(100000)
        NbTi.setThreshold(100000)
        BSCCO.setThreshold(100000)
        if momentum <= 2200 then
            Gold.setThreshold(momentum)
        elseif momentum <= 8400 then
            NbTi.setThreshold(momentum)
        elseif momentum <= 15000 then
            BSCCO.setThreshold(momentum)
        end
    end
end