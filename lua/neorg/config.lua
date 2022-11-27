-- Configuration template
neorg.configuration = {

    user_configuration = {
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

    version = "0.0.18",
    neovim_version = (function()
        require("neorg.external.helpers")

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

                value = neorg.lib.match(key)({
                    compilation = function()
                        local split = vim.split(value, "%s+")

                        split.compiler = table.remove(split, 1)
                        return split
                    end,
                    features = neorg.lib.wrap(vim.split, value, "%s*%+", {
                        trimempty = true,
                    }),
                    nvim = tonumber(value),
                    _ = value:gsub('^"?', ""):gsub('"?$', ""),
                })

                data[key] = value
            end
        end

        return data
    end)(),
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
