--- @brief [[
--- Defines the configuration table for use throughout Neorg.
--- @brief ]]

-- TODO(vhyrro): Make `norg_version` and `version` a `Version` class.

--- @alias OperatingSystem
--- | "windows"
--- | "wsl"
--- | "wsl2"
--- | "mac"
--- | "linux"
--- | "bsd"

--- @alias neorg.configuration.module { config?: table }

--- @class (exact) neorg.configuration.user
--- @field hook? fun(manual: boolean, arguments?: string)    A user-defined function that is invoked whenever Neorg starts up. May be used to e.g. set custom keybindings.
--- @field lazy_loading? boolean                             Whether to defer loading the Neorg core until after the user has entered a `.norg` file.
--- @field load table<string, neorg.configuration.module>    A list of modules to load, alongside their configurations.
--- @field logger? neorg.log.configuration                   A configuration table for the logger.

--- @class (exact) neorg.configuration
--- @field arguments table<string, string>                   A list of arguments provided to the `:NeorgStart` function in the form of `key=value` pairs. Only applicable when `user_config.lazy_loading` is `true`.
--- @field manual boolean?                                   Used if Neorg was manually loaded via `:NeorgStart`. Only applicable when `user_config.lazy_loading` is `true`.
--- @field modules table<string, neorg.configuration.module> Acts as a copy of the user's configuration that may be modified at runtime.
--- @field norg_version string                               The version of the file format to be used throughout Neorg. Used internally.
--- @field os_info OperatingSystem                           The operating system that Neorg is currently running under.
--- @field pathsep "\\"|"/"                                  The operating system that Neorg is currently running under.
--- @field started boolean                                   Set to `true` when Neorg is fully initialized.
--- @field user_config neorg.configuration.user              Stores the configuration provided by the user.
--- @field version string                                    The version of Neorg that is currently active. Automatically updated by CI on every release.

--- Gets the current operating system.
--- @return OperatingSystem
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
    elseif os:find("bsd") then
        return "bsd"
    end

    error("[neorg]: Unable to determine the currently active operating system!")
end

local os_info = get_os_info()

--- Stores the configuration for the entirety of Neorg.
--- This includes not only the user configuration (passed to `setup()`), but also internal
--- variables that describe something specific about the user's hardware.
--- @see neorg.setup
---
--- @type neorg.configuration
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
    version = "8.2.0",

    os_info = os_info,
    pathsep = os_info == "windows" and "\\" or "/",

    hook = nil,
    started = false,
}

return config
