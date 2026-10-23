local filesystem = require("filesystem")
local internet = require("internet")
local os = require("os")

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
            "time",
            "util"
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
            ["gerver/backup_pwr.lua"] = rc
        }
    },
    ["nuke-logger"] = {
        deps = {
            "logger",
            "time",
            "util"
        },
        files = {
            ["gerver/nuke_logger.lua"] = autorun
        }
    },
    ["os-door"] = {
        deps = {
            "biometrics",
            "config"
        },
        files = {
            ["gerver/door.lua"] = autorun
        }
    },
    ["stem-logger"] = {
        deps = {
            "logger",
            "stem",
            "time",
            "util"
        },
        files = {
            ["stem-logger.lua"] = bin
        }
    },
    ["stem-uptime-server"] = {
        deps = {
            "stem-conn",
            "syslog",
            "util"
        },
        files = {
            ["gerver/stem-uptime-server.lua"] = rc
        },
        post = {
            "rc stem-uptime-server enable"
        }
    },
    ["stem-uptime-client"] = {
        deps = {
            "stem-conn",
            "syslog",
            "util"
        },
        files = {
            ["gerver/stem-uptime-client.lua"] = rc
        },
        post = {
            "rc stem-uptime-client enable"
        }
    },
    ["stem-info-api"] = {
        deps = {
            "stem-c2"
        },
        files = {
            ["gerver/stem-info-api.lua"] = rc
        },
        post = {
            "rc stem-info-api enable"
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
    ["stem"] = {
        repo = "https://gitlab.com/UnicornFreedom/stem/-/raw/master/",
        files = {
            ["stem.lua"] = lib
        }
    },
    ["stem-ocvm"] = { -- version for ocvm because ocvm's internet_ready is broken
        files = {
            ["libs/stem-ocvm.lua"] = lib,
            ["libs/internetready.lua"] = lib
        }
    },
    ["stem-c2"] = {
        deps = {
            "stem-conn",
            "totp",
            "util"
        },
        files = {
            ["libs/stem-c2.lua"] = lib
        }
    },
    ["stem-conn"] = {
        deps = {
            "syslog",
            "util"
        },
        files = {
            ["libs/stem-conn.lua"] = lib
        }
    },
    ["syslog"] = {
        files = {
            ["libs/syslog.lua"] = lib
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
    ["totp"] = {
        files = {
            ["libs/totp.lua"] = lib
        }
    },
    ["tui"] = {
        files = {
            ["libs/tui.lua"] = lib
        }
    },
    ["util"] = {
        files = {
            ["libs/util.lua"] = lib
        }
    },

    ["lpm"] = { -- this = this
        files = {
            ["lpm.lua"] = "./"
        }
    },
    ["test"] = {
        files = {
            ["test.lua"] = "/home/"
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

local function install(name, force, originalName)
    local pkg = packages[name]

    if not pkg then
        return false, string.format("package \"%s\" not found", name)
    end


    local dependencies = pkg.deps
    if dependencies then
        for _, dependency in ipairs(dependencies) do
            local success, r = install(dependency, force)
            if not success then
                return false, string.format("failed to install %s: %s", dependency, r)
            end
        end
    end

    for url_path, local_path in pairs(pkg.files) do
        local url = (pkg.repo and pkg.repo or repo) .. url_path
        local path = local_path .. url_path:match("[^/]+$")
        if local_path == autorun then path = "/autorun.lua" end

        if force or not filesystem.exists(path) then
            print(string.format("downloading %s -> %s", name, path))
            local success, r = download(url, path)
            if not success then
                return false, string.format("failed to download %s: %s", path, r)
            end
        end
    end

    if name == originalName and pkg.post then
        for _, cmd in ipairs(pkg.post) do
            os.execute(cmd)
            print(cmd)
        end
    end

    return true
end

local commands = {
    ["install"] = function(pkg)
        return install(pkg, false, pkg)
    end,

    ["update"] = function(pkg)
        return install(pkg, true, pkg)
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
