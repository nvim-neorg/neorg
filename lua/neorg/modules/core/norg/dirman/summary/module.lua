--[[
    DIRMAN SUMMARY
    module to generate a summary of a workspace inside a note 
--]]

require("neorg.modules.base")
require("neorg.modules")
require("neorg.external.helpers")

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

    module.config.public.strategy = neorg.lib.match(module.config.public.strategy) {
        metadata = neorg.lib.wrap(function(files)
            -- local metadata = 
        end),
        headings = neorg.lib.wrap(function()
        end),
    } or module.config.public.strategy
end

module.config.public = {
    -- The strategy to use to generate a summary.
    --
    -- Possible options are:
    -- - "metadata" - read the metadata to categorize and annotate files. Files
    --   without metadata will be ignored.
    -- - "headings" - read the top level heading and use that as the title.
    --   files in subdirectories are treated as subheadings.
    strategy = "metadata",
}

module.public = {}

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["dirman.summary"] = true,
    },
}

module.on_event = function(event)

end

return module
