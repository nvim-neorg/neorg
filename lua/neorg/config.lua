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

    version = "0.1",
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

return neorg.configuration
