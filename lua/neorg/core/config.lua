local lib = require("neorg.core.lib")

local function neovim_version()
    local data = {}
    local parsed_output = vim.api.nvim_exec("version", true)

    for _, line in ipairs(vim.split(parsed_output, "\n")) do
        local key, value = line:match("^%s*(.+[^%s]):%s+(.+)$")

        if not key then
            key, value = line:match("^(NVIM)%s+v%d+%.%d+%.%d+%-%w+%-(%d+).+")
        end

        if not key then
            key, value = line:match("(LUAJIT)%s+(.+)")
        end

        if key then
            key = key:lower():gsub("%p", ""):gsub("%s", "-")

            value = lib.match(key)({
                compilation = function()
                    local split = vim.split(value, "%s+")

                    split.compiler = table.remove(split, 1)
                    return split
                end,
                features = lib.wrap(vim.split, value, "%s*%+", {
                    trimempty = true,
                }),
                nvim = tonumber(value),
                _ = value:gsub('^"?', ""):gsub('"?$', ""),
            })

            data[key] = value
        end
    end

    return data
end

-- Grab OS info on startup
local function os_info()
    local os = vim.loop.os_uname().sysname:lower()

    if os:find("windows_nt") then
        return "windows"
    elseif os == "darwin" then
        return "mac"
    elseif os == "linux" then
        local f = io.open("/proc/version", "r")
        if f ~= nil then
            local version = f:read("*all")
            f:close()
            if version:find("WSL2") then
                return "wsl2"
            elseif version:find("microsoft") then
                return "wsl"
            end
        end
        return "linux"
    end
end

-- Configuration template
local config = {
    user_config = {
        lazy_loading = false,
        load = {
            --[[
                ["name"] = { config = { ... } }
            --]]
        },
    },

    modules = {},
    manual = nil,
    arguments = {},

    norg_version = "1.1.1",
    version = "6.1.0",

    neovim_version = neovim_version(),
    os_info = os_info(),
}

-- TODO: Is there a better way to define this inside the body of `config'?
config.pathsep = config.os_info == "windows" and "\\" or "/"

return config
