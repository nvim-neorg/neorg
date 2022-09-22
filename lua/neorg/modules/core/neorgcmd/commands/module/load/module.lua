--[[
    File: Neorgcmd-List
    Title: Provides `:Neorg load ...` command
    Summary: Load a new module dynamically.
    Internal: true
    ---
After loading the module run `:Neorg module load <module_path>` to dynamically load in a new module.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.neorgcmd.commands.module.load")

module.setup = function()
    return { success = true, requires = { "core.neorgcmd" } }
end

module.public = {

    neorg_commands = {
        module = {
            args = 1,

            subcommands = {
                load = {
                    args = 1,
                    name = "module.load",
                },
            },
        },
    },
}

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.module.load" then
        neorg.modules.load_module(event.content[1])
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["module.load"] = true,
    },
}

return module
