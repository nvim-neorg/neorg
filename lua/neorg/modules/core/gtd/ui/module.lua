--[[
    File: GTD-UI
    Title: GTD UI module
    Summary: Nicely displays GTD related information.
    Show: false.
    ---

This module is like a sub-module for `core.gtd.base`, exposing public functions to display nicely aggregated stuff like tasks and projects.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.gtd.ui")

module.load = function()
    module.required["core.keybinds"].register_keybinds(module.name, { "goto_task", "close", "edit_task", "details" })
    module.required["core.autocommands"].enable_autocommand("BufLeave")

    -- Set up callbacks
    module.public.callbacks.goto_task_function = module.private.goto_node_internal
    module.public.callbacks.edit_task = module.private.edit_task
end

module.setup = function()
    return {
        success = true,
        requires = {
            "core.ui",
            "core.keybinds",
            "core.norg.dirman",
            "core.gtd.queries",
            "core.gtd.helpers",
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

---@class core.gtd.ui
module.public = {
    callbacks = {},
}

module.private = {

    goto_node = function()
        local data = module.private.get_by_var()

        if not data or vim.tbl_isempty(data) then
            return
        end

        module.private.close_buffer()

        -- Go to the node
        module.public.callbacks.goto_task_function(data)

        -- Reset the data
        module.private.data = {}
        module.private.extras = {}
    end,

    goto_node_internal = function(data)
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()
        vim.api.nvim_win_set_buf(0, data.internal.bufnr)
        ts_utils.goto_node(data.internal.node)
    end,

    edit_task = function(task)
        task = module.private.refetch_data_not_extracted({ task.node, task.bufnr }, "task")
        module.public.edit_task(task)
    end,
}

module.on_event = function(event)
    if event.split_type[1] == "core.keybinds" then
        if event.split_type[2] == "core.gtd.ui.goto_task" then
            module.private.goto_node()
        elseif event.split_type[2] == "core.gtd.ui.close" then
            module.private.close_buffer()
        elseif event.split_type[2] == "core.gtd.ui.edit_task" then
            local task = module.private.get_by_var()
            module.private.close_buffer()
            module.public.callbacks.edit_task(task)
        elseif event.split_type[2] == "core.gtd.ui.details" then
            module.private.toggle_details()
        end
    elseif event.split_type[1] == "core.autocommands" then
        if event.split_type[2] == "bufleave" and event.buffer == module.private.current_bufnr then
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

return module
