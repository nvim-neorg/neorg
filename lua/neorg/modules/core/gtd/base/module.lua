--[[
    Base module for Getting Things Done methodology
    It's here where the keybinds and commands are created in order to interact with GTD stuff

USAGE:
    - Quick actions for gtd stuff:
        - Call the command :Neorg gtd views
    - Edit the task under the cursor:
        - Call the command :Neorg gtd edit

REQUIRES:
    This module requires:
        - core.norg.dirman      in order to get full path to the workspace
        - core.keybinds         (check KEYBINDS for usage)
        - core.gtd.ui           for gtd UI components
        - core.neorgcmd         to add commands capabilities
        - core.gtd.queries      to use custom gtd queries

KEYBINDS:
    - core.gtd.base.add_to_inbox: Will call the function add_task_to_inbox()

COMMANDS:
    - Neorg gtd views           to show the views popup
    - Neorg gtd edit            to edit the task under the cursor
    - Neorg gtd capture         to create tasks and projects in the gtd workspace

--]]

require("neorg.modules.base")
require("neorg.events")

local module = neorg.modules.create("core.gtd.base")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.norg.dirman",
            "core.keybinds",
            "core.gtd.ui",
            "core.gtd.queries",
            "core.neorgcmd",
        },
    }
end

module.config.public = {
    -- Workspace name to use for gtd related lists
    workspace = "default",
    default_lists = {
        inbox = "inbox.norg",
    },
    exclude = {},
}

module.public = {
    version = "0.1",
}

module.private = {
    workspace_full_path = "",
}

module.load = function()
    -- Get workspace for gtd files and save full path in private
    local workspace = module.config.public.workspace
    module.private.workspace_full_path = module.required["core.norg.dirman"].get_workspace(workspace)

    -- Register keybinds
    module.required["core.keybinds"].register_keybind(module.name, "views")
    module.required["core.keybinds"].register_keybind(module.name, "edit")
    module.required["core.keybinds"].register_keybind(module.name, "capture")

    -- Add neorgcmd capabilities
    -- All gtd commands start with :Neorg gtd ...
    module.required["core.neorgcmd"].add_commands_from_table({
        definitions = {
            gtd = {
                views = {},
                edit = {},
                capture = {},
            },
        },
        data = {
            gtd = {
                args = 1,
                subcommands = {
                    views = { args = 0, name = "gtd.views" },
                    edit = { args = 0, name = "gtd.edit" },
                    capture = { args = 0, name = "gtd.capture" },
                },
            },
        },
    })
end

module.on_event = function(event)
    if vim.tbl_contains({ "core.keybinds", "core.neorgcmd" }, event.split_type[1]) then
        if vim.tbl_contains({ "gtd.views", "core.gtd.base.views" }, event.split_type[2]) then
            module.required["core.gtd.ui"].show_views_popup(module.config.public)
        elseif vim.tbl_contains({ "gtd.edit", "core.gtd.base.edit" }, event.split_type[2]) then
            module.public.edit_task()
        elseif vim.tbl_contains({ "gtd.capture", "core.gtd.base.capture" }, event.split_type[2]) then
            module.required["core.gtd.ui"].show_capture_popup()
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.gtd.base.capture"] = true,
        ["core.gtd.base.views"] = true,
        ["core.gtd.base.edit"] = true,
    },
    ["core.neorgcmd"] = {
        ["gtd.views"] = true,
        ["gtd.edit"] = true,
        ["gtd.capture"] = true,
    },
}

module.public = {
    edit_task = function()
        local task_node = module.required["core.gtd.queries"].get_at_cursor("task")

        if not task_node then
            log.warn("No task at cursor position")
            return
        end

        local task = module.required["core.gtd.ui"].refetch_task_not_extracted(task_node)
        module.required["core.gtd.ui"].edit_task(task)
    end,
}
return module
