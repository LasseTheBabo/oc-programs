local biometrics = {}

function biometrics.contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

function biometrics.addPlayer(config, id)
    if not biometrics.contains(config.userBiometrics, id) then
        table.insert(config.userBiometrics, id)
    end
end

function biometrics.removePlayer(config, id)
    for i, v in ipairs(config) do
        if v == id then
            table.remove(config, i)
        end
    end
end

return biometrics