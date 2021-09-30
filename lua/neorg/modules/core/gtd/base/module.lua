--[[
    Base module for Getting Things Done methodology
    It's here where the keybinds and commands are created in order to interact with GTD stuff

USAGE:
    - Quick actions for gtd stuff:
        - Call the command :Neorg gtd quick_actions
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
    - Neorg gtd quick_actions   to show the quick actions popup
    - Neorg edit                to edit the task under the cursor

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
    module.required["core.keybinds"].register_keybind(module.name, "add_to_inbox")

    -- Add neorgcmd capabilities
    -- All gtd commands start with :Neorg gtd ...
    module.required["core.neorgcmd"].add_commands_from_table({
        definitions = {
            gtd = {
                quick_actions = {},
                edit = {},
            },
        },
        data = {
            gtd = {
                args = 1,
                subcommands = {
                    quick_actions = { args = 0, name = "gtd.quick_actions" },
                    edit = { args = 0, name = "gtd.edit" },
                },
            },
        },
    })
end

module.on_event = function(event)
    if event.split_type[1] == "core.neorgcmd" then
        if event.split_type[2] == "gtd.quick_actions" then
            module.required["core.gtd.ui"].show_quick_actions(module.config.public)
        elseif event.split_type[2] == "gtd.edit" then
            module.public.edit_task()
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.gtd.base.add_to_inbox"] = true,
    },
    ["core.neorgcmd"] = {
        ["gtd.quick_actions"] = true,
        ["gtd.edit"] = true,
    },
}

module.public = {
    edit_task = function()
        local task_node = module.required["core.gtd.queries"].get_at_cursor("task")

        if #task_node == 0 then
            log.warn("No task at cursor position")
            return
        end
        module.required["core.gtd.ui"].edit_task(task_node)
    end,
}
return module
