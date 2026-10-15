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
            ["dfc/dfc-screen.lua"] = autorun
        }
    },

    ["backup-pwr"] = {
        files = {
            ["gerver6/backup_pwr.lua"] = rc
        },
        post_install = {
            "rc backup_pwr enable"
        }
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

local function download(url, path)
    if not url then return url, "invalid url" end
    if not path then return path, "invalid path" end

    local success, result = pcall(function()
        local chunks = {}
        for chunk in internet.request(url) do chunks[#chunks + 1] = chunk end
        return table.concat(chunks)
    end)
    if not success then return false, result end

    local dir = filesystem.path(path)
    if dir and not filesystem.exists(dir) then
        local ok, r = filesystem.makeDirectory(dir)
        if not ok then return false, r end
    end

    local file, r = io.open(path, "wb")
    if not file then return file, r end

    file:write(result)
    file:close()

    return true
end

local function install(name, force)
    local pkg = packages[name]

    if not pkg then
        return false, string.format("pkg %s not found", name)
    end

    print("installing " .. name)

    local dependencies = pkg.deps
    if dependencies then
        for _, dependency in ipairs(dependencies) do
            local success, r = install(dependency)
            if not success then
                return false, string.format("failed to install %s: %s", dependency, r)
            end
        end
    end

    for url_path, local_path in pairs(pkg.files) do
        local url = repo .. url_path
        local path = local_path .. url_path:match("[^/]+$")
        if local_path == autorun then path = "/autorun.lua" end

        if force or not filesystem.exists(path) then
            local success, r = download(url, path)
            if not success then
                return false, string.format("failed to download %s: %s", path, r)
            end
        end
    end

    if pkg.post_install then
        for _, cmd in ipairs(pkg.post_install) do
            os.execute(cmd)
        end
    end

    return true
end

local commands = {
    ["install"] = function(pkg)
        return install(pkg)
    end,

    ["update"] = function(pkg)
        return install(pkg, true)
    end
}

local function help()
    local list = {}
    for cmd in pairs(commands) do table.insert(list, cmd) end
    table.sort(list)

    print(string.format("usage: lpm [%s] <pkg-name>", table.concat(list, "|")))
end

local command, pkg = ...

if not commands[command] then
    help()
else
    if not pkg then
        print("pkg needed")
        help()
        return
    end

    local success, r = commands[command](pkg)
    if not success then
        print("error: " .. tostring(r))
        os.exit(1)
    end
end
