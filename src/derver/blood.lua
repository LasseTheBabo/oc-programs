local r = component.proxy(component.list("robot")())
while true do
    r.use(0, false, 0.1)
    r.drop(0)
end