--[[
    Base module for Getting Things Done methodology

USAGE:
    - Quick actions for gtd stuff:
        - Call the command :Neorg gtd quick_actions
    - To add a task to the inbox:
        - Use the public function add_task_to_inbox()
        - Call the command :Neorg gtd capture

REQUIRES:
    This module requires:
        - core.norg.dirman in order to get full path to the workspace
        - core.keybinds (check KEYBINDS for usage)
        - core.gtd.ui for gtd UI components
        - core.neorgcmd to add commands capabilities
        - core.queries.native to fetch content from norg files
        - core.integrations.treesitter to use ts_utils

KEYBINDS:
    - core.gtd.base.add_to_inbox: Will call the function add_task_to_inbox()

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
                capture = {},
                list = { inbox = {} },
                quick_actions = {},
            },
        },
        data = {
            gtd = {
                args = 1,
                subcommands = {
                    capture = { args = 0, name = "gtd.capture" },
                    list = {
                        args = 1,
                        name = "gtd.list",
                        subcommands = {
                            inbox = { args = 0, name = "gtd.list.inbox" },
                        },
                    },
                    quick_actions = { args = 0, name = "gtd.quick_actions" },
                },
            },
        },
    })
end

module.on_event = function(event)
    if event.split_type[2] == "core.gtd.base.add_to_inbox" then
        module.required["core.gtd.ui"].add_task_to_inbox()
    end
    if event.split_type[1] == "core.neorgcmd" then
        if event.split_type[2] == "gtd.capture" then
            module.required["core.gtd.ui"].add_task_to_inbox()
        elseif event.split_type[2] == "gtd.list.inbox" then
            module.required["core.norg.dirman"].open_file(
                module.config.public.workspace,
                module.config.public.default_lists.inbox
            )
        elseif event.split_type[2] == "gtd.quick_actions" then
            module.required["core.gtd.ui"].show_quick_actions(module.config.public)
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.gtd.base.add_to_inbox"] = true,
    },
    ["core.neorgcmd"] = {
        ["gtd.capture"] = true,
        ["gtd.list.inbox"] = true,
        ["gtd.quick_actions"] = true,
    },
}

return module
