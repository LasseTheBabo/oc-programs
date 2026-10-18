local util = {}

function util.split(input)
    local result = {}
    for word in input:gmatch("%S+") do
        table.insert(result, word)
    end
    return result
end

function util.toBool(state)
    if state == "true" then
        return true
    elseif state == "false" then
        return false
    else
        return nil
    end
end

function util.escape(s)
    return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

function util.read(path)
    if not path then return path, "invalid path" end

    local file, r = io.open(path, "r")
    if not file then return file, r end
    local data = file:read()

    file:close()
    return data
end

function util.load(path)
    local data, r = util.read(path)
    if not data then
        return nil, string.format("%s: %s", r, path)
    end

    return data
end

return util
