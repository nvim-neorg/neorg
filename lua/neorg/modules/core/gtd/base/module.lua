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
    module.required["core.keybinds"].register_keybind(module.name, "add_to_inbox")

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
    if event.split_type[1] == "core.neorgcmd" then
        if event.split_type[2] == "gtd.views" then
            module.required["core.gtd.ui"].show_views_popup(module.config.public)
        elseif event.split_type[2] == "gtd.edit" then
            module.public.edit_task()
        elseif event.split_type[2] == "gtd.capture" then
            module.required["core.gtd.ui"].show_capture_popup()
        end
    elseif event.split_type[1] == "core.neorgcmd" then
        log.warn("Keybinds not implemented")
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.gtd.base.add_to_inbox"] = true,
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

        -- Get all nodes from the bufnr and add metadatas to it
        -- This is mandatory because we need to have the correct task position, else the update will not work
        local nodes = module.required["core.gtd.queries"].get("tasks", { bufnr = task_node[2] })
        nodes = module.required["core.gtd.queries"].add_metadata(nodes, "task", { extract = false, same_node = true })

        -- Find the correct task node
        local found_task = vim.tbl_filter(function(n)
            return n.node:id() == task_node[1]:id()
        end, nodes)

        if #found_task == 0 then
            log.error("Error in fetching task")
            return
        end

        module.required["core.gtd.ui"].edit_task(found_task[1])
    end,
}
return module
