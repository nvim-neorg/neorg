--[[
    DIRMAN SUMMARY
    module to generate a summary of a workspace inside a note 
--]]
require("neorg.modules.base")
require("neorg.modules")

local module = neorg.modules.create("core.norg.dirman.summary")

module.setup = function()
    return {
        sucess = true,
        requires = { "core.norg.dirman", "core.neorgcmd" },
    }
end

module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        ["generate-workspace-summary"] = {
            args = 0,
            condition = "norg",
            name = "dirman.summary",
        },
    })
end

module.config.public = {
    -- The list of summaries, by default contains one inside the index file of a workspace.
    summaries = {
        {
            -- The file to include the summary in
            file = function()
                return module.required["core.norg.dirman"].get_index()
            end,
            -- The summary location, must be a heading.
            location = "* Index",
            -- File categories to include in the summary, if empty will include all notes
            categories = {},
        },
    },
}

module.public = {}

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["generate-workspace-summary"] = true,
    },
}

return module
