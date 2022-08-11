-- Configuration template
neorg.configuration = {

    user_configuration = {
        load = {
            --[[
				["name"] = { config = { ... } }
			--]]
        },
    },

    modules = {},
    manual = nil,
    arguments = {},

    version = "0.0.12",
}

-- Grab OS info on startup
neorg.configuration.os_info = (function()
    local os = vim.loop.os_uname().sysname:lower()

    if os:find("windows_nt") then
        return "windows"
    elseif os == "darwin" then
        return "mac"
    elseif os == "linux" then
        return "linux"
    end
end)()

neorg.configuration.pathsep = neorg.configuration.os_info == "windows" and "\\" or "/"

return neorg.configuration
