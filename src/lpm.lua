local filesystem = require("filesystem")
local internet = require("internet")

local bin = "/usr/bin/"
local lib = "/usr/lib/"
local rc = "/etc/rc.d/"
local autorun = "autorun"
local repo = "https://raw.githubusercontent.com/LasseTheBabo/oc-programs/refs/heads/master/src/"

local packages = {
    ["dfc-calculator"] = {
        deps = {
            "tui"
        },
        files = {
            ["dfc/dfc-calculator.lua"] = bin
        }
    },
    -- no older dfc control here because s1 and s1.5 are too unsecure...
    ["dfc-control-g6"] = {
        deps = {
            "chat-cmd",
            "tele",
            "time"
        },
        files = {
            ["dfc/dfc-control-g6.lua"] = autorun
        }
    },
    ["dfc-screen"] = {
        deps = {
            "logger"
        },
        files = {
            ["dfc/dfc-screen-lua"] = autorun
        }
    },

    ["backup-pwr"] = {
        files = {
            ["gerver6/backup_pwr.lua"] = rc
        },
        post_install = "rc backup_pwr enable"
    },
    ["os-door"] = {
        deps = {
            "biometrics",
            "config"
        },
        files = {
            ["gerver6/door.lua"] = autorun
        }
    },
    ["nuke-logger"] = {
        deps = {
            "logger",
            "time"
        },
        files = {
            ["gerver6/nuke_logger.lua"] = autorun
        }
    },


    -- libraries
    ["biometrics"] = {
        files = {
            ["libs/biometrics.lua"] = lib
        }
    },
    ["chat-cmd"] = {
        deps = {
            "time"
        },
        files = {
            ["libs/chat-cmd.lua"] = lib
        }
    },
    ["config"] = {
        files = {
            ["libs/config.lua"] = lib
        }
    },
    ["logger"] = {
        files = {
            ["libs/logger.lua"] = lib
        }
    },
    ["tele"] = {
        files = {
            ["libs/tele.lua"] = lib
        }
    },
    ["time"] = {
        files = {
            ["libs/time.lua"] = lib
        }
    },
    ["tui"] = {
        files = {
            ["libs/tui.lua"] = lib
        }
    },

    ["debug"] = {
        files = {
            ["debug.lua"] = bin
        }
    }
}

local function split(str, sep)
    local parts = {}
    for part in string.gmatch(str, "([^" .. sep .. "]+)") do
        parts[#parts + 1] = part
    end
    return parts
end

local function download(url, path)
    if not url then return url, "invalid url" end
    if not path then return path, "invalid path" end

    local handle = internet.request(url)
    local result = ""
    for chunk in handle do result = result .. chunk end

    local file, r = io.open(path, "w")
    if not file then return file, r end

    file:write(result)
    file:close()

    return true
end

local function install(name, force)
    local package = packages[name]

    if not package then
        return false, string.format("package %s not found", name)
    end

    local dependencies = package.deps
    if dependencies then
        for _, dependency in ipairs(dependencies) do
            local success, r = install(dependency)
            if not success then
                return false, string.format("failed to install %s: %s", dependency, r)
            end
        end
    end

    for url_path, local_path in pairs(package.files) do
        local url = repo .. url_path
        local parts = split(url_path, "/")
        local path = local_path .. parts[#parts]
        if local_path == autorun then path = "/autorun.lua" end

        if force ~= true and filesystem.exists(path) then
            goto continue
        end

        local success, r = download(url, path)
        if not success then
            return false, string.format("failed to download %s: %s", path, r)
        end
        ::continue::
    end

    if package.post_install then
        for _, cmd in package.post_install do
            os.execute(cmd)
        end
    end

    return true
end

local commands = {
    ["install"] = function(package)
        install(package)
    end,

    ["update"] = function(package)
        install(package, true)
    end
}

local function help()
    local list = {}
    for cmd in pairs(commands) do table.insert(list, cmd) end
    table.sort(list)

    print(string.format("usage: lpm [%s] <package-name>", table.concat(list, "|")))
end

local command, package = ...

if not commands[command] then
    help()
else
    if not package then
        print("package needed")
        help()
        return
    end
    commands[command](package)
end
