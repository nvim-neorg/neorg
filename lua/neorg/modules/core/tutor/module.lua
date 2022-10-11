--[[
    File: Tutor
    Title: Tutor module for Neorg
    Summary: Learn to use neorg
    ---
How to use this module:
This module creates three commands.
- `:Neorg tutor`
- `:Neorg tutor notes`
- `:Neorg tutor gtd`
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.tutor")
local log = require("neorg.external.log")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.norg.dirman",
            "core.keybinds",
            "core.neorgcmd",
            "core.integrations.treesitter",
        },
    }
end

module.private = {
    tutor_complete = function() end,
    tutor_notes = function() end,
    tutor_gtd = function() end,
}

module.config.public = {}

module.config.private = {}

module.public = {}

module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        tutor = {
            min_args = 0,
            max_args = 1,
            name = { "core.tutor" },
            subcommands = {
                gtd = { args = 0, name = "tutor.gtd" },
                notes = { args = 0, name = "tutor.notes" },
            },
        },
    })
end

module.on_event = function(event)
    if vim.tbl_contains({ "core.keybinds", "core.neorgcmd" }, event.split_type[1]) then
        if event.split_type[2] == "core.tutor" then
            module.private.tutor_complete()
        elseif event.split_type[2] == "tutor.gtd" then
            module.private.tutor_gtd()
        elseif event.split_type[2] == "tutor.notes" then
            module.private.tutor_notes()
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["core.tutor"] = true,
        ["tutor.notes"] = true,
        ["tutor.gtd"] = true,
    },
}

return module
