local function setRedstone(side, value)
    redstone.setOutput(side, 15)
end

local function readRedstone(side)
    return redstone.getInput(side)
end

local function pulseRedstone(side)
    setRedstone(side, 15)
    os.sleep(0.1)
    setRedstone(side, 0)
end

pulseRedstone(rsSpatialIO)
setRedstone(rsInport, 15)
query("phase1-end")

queryWait("phase2-begin")
pulseRedstone(rsSpatialIO)
setRedstone(rsStorage, 15)
query("phase2-end")

queryWait("phase3-begin")
while readRedstone(rsSpatialIO_read) do
    os.sleep(0.1)
end
setRedstone(rsImport, 0)
query("phase3-end")

queryWait("phase4-begin")
setRedstone(rsStorage, 0)
setRedstone(rsImport, 15)
query("phase5-end")

queryWait("phase5-begin")
setRedstone(rsStorage, 15)
while not readRedstone(rsSpatialIO_read) do
    os.sleep(0.1)
setRedstone(rsStorage, 0)
query("phase5-end")

queryWait("phase6-begin")
setRedstone(rsImport, 0)
pulseRedstone(rsSpatialIO)
setRedstone(rsImport, 15)
setRedstone(rsStorage, 15)
os.sleep(1)
setRedstone(rsImport, 0)
setRedstone(rsStorage, 0)
queryWait("phase6-begin")