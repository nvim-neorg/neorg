--[[
    File: GTD-UI
    Title: GTD UI module
    Summary: Nicely display GTD related informations
    ---

This module is like a sub-module for `norg.gtd.base` , exposing public functions to display nicely aggregated stuff, like tasks and projects.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.gtd.ui")

module.load = function()
    module.required["core.keybinds"].register_keybinds(module.name, { "goto_task", "close", "edit_task", "details" })
    module.required["core.autocommands"].enable_autocommand("BufLeave")
end

module.setup = function()
    return {
        success = true,
        requires = {
            "core.ui",
            "core.keybinds",
            "core.norg.dirman",
            "core.gtd.queries",
            "core.integrations.treesitter",
            "core.mode",
            "core.queries.native",
            "core.autocommands",
        },
        imports = {
            "displayers",
            "views_popup_helpers",
            "edit_popup_helpers",
            "selection_popups",
        },
    }
end

module.on_event = function(event)
    if event.split_type[1] == "core.keybinds" then
        if event.split_type[2] == "core.gtd.ui.goto_task" then
            module.private.goto_node()
        elseif event.split_type[2] == "core.gtd.ui.close" then
            module.private.close_buffer()
        elseif event.split_type[2] == "core.gtd.ui.edit_task" then
            local task = module.private.get_by_var()
            module.private.close_buffer()
            task = module.private.refetch_data_not_extracted({ task.node, task.bufnr }, "task")
            module.public.edit_task(task)
        elseif event.split_type[2] == "core.gtd.ui.details" then
            module.private.toggle_details()
        end
    elseif event.split_type[1] == "core.autocommands" then
        if event.split_type[2] == "bufleave" then
            module.private.close_buffer()
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.gtd.ui.goto_task"] = true,
        ["core.gtd.ui.close"] = true,
        ["core.gtd.ui.edit_task"] = true,
        ["core.gtd.ui.details"] = true,
    },
    ["core.autocommands"] = {
        bufleave = true,
    },
}

---@class core.gtd.ui
module.public = {}

return module
