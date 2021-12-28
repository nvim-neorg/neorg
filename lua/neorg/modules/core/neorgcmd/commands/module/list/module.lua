--[[
    File: Neorgcmd-List
    Title: Provides `:Neorg list` command
    Summary: List loaded modules.
    Show: false.
    ---
After module is loaded execute `:Neorg module list` to see a primitive list of currently loaded modules.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.neorgcmd.commands.module.list")

module.setup = function()
    return { success = true, requires = { "core.neorgcmd" } }
end

module.public = {

    neorg_commands = {
        definitions = {
            module = {
                list = {},
            },
        },
        data = {
            module = {
                args = 1,

                subcommands = {

                    list = {
                        args = 0,
                        name = "module.list",
                    },
                },
            },
        },
    },
}

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.module.list" then
        vim.cmd('echom "--- PRINTING ALL LOADED MODULES ---"')

        for _, mod in pairs(neorg.modules.loaded_modules) do
            vim.cmd('echom "' .. mod.name .. '"')
        end

        vim.cmd(
            'echom "Execute :messages to see output. BETA PRINTER FOR LOADED MODULES. This is obviously not final :P. Soon modules will be shown in a floating window."'
        )
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["module.list"] = true,
    },
}

return module
