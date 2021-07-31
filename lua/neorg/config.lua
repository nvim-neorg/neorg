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
    if vim.fn.has("win32") == 1 then
        return "windows"
    elseif vim.fn.has("unix") == 1 then
        return "linux"
    elseif vim.fn.has("mac") == 1 then
        return "mac"
    end
end)()

return neorg.configuration
