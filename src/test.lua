local component = require("component")

stabilizers = {}
for c, _ in pairs(component.list("dfc_stabilizer")) do table.insert(stabilizers, component.proxy(c)) end
return stabilizers