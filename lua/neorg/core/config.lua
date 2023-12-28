-- Grab OS info on startup
local function get_os_info()
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

local os_info = get_os_info()

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
    version = "7.0.0",

    os_info = os_info,
    pathsep = os_info == "windows" and "\\" or "/",
}

return config
