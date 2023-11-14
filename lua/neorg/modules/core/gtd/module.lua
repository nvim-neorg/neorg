local modules, _ = require("neorg.core.modules"), require("neorg.core.log")

local module = modules.create("core.gtd")

module.setup = function()
    return {
        requires = { "core.gtd.ui" },
    }
end

module.load = function()
    modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            ["capture"] = {
                args = 0,
                name = "gtd.capture",
            },
        })
    end)
end

module.on_event = function(ev)
    if ev.split_type[2] == "gtd.capture" then
        assert(modules.get_module("core.gtd.ui.capture")).capture()
    end
end

module.events = {
    subscribed = {
        ["core.neorgcmd"] = {
            ["gtd.capture"] = true,
        },
    },
}

return module
