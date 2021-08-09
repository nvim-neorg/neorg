--[[
    Base module for Getting Things Done methodology

USAGE:
    - To add a task to the inbox:
        - Use the public function add_task_to_inbox()
        - Call the command :Neorg gtd capture

REQUIRES:
    This module requires:
        - core.norg.dirman in order to get full path to the workspace
        - core.keybinds (check KEYBINDS for usage)
        - core.ui in order to ask for user input
        - core.neorgcmd to add commands capabilities

KEYBINDS:
    - core.gtd.base.add_to_inbox: Will call the function add_task_to_inbox()

--]]

require("neorg.modules.base")
require("neorg.events")

local module = neorg.modules.create("core.gtd.base")
local log = require('neorg.external.log')


module.setup = function ()
    return {
        success = true,
        requires = { 'core.norg.dirman', 'core.keybinds', 'core.ui', 'core.neorgcmd' }
    }
end

module.config.public = {
    -- Workspace name to use for gtd related lists
    workspace = nil
}

module.private = {
    workspace_full_path = nil,
    default_lists = {
        inbox = "INBOX.norg",
        projects = "PROJECTS.norg",
        someday = "SOMEDAY.norg"
    },

-- @Summary Append text to list
-- @Description Append the text to the specified list (defined in private.default_lists)
-- @Param  list (string) the list to use
-- @Param  text (string) the text to append
    add_to_list = function (list, text)
        local fn = io.open(module.private.workspace_full_path .. "/" .. list, "a")
        fn:write(text)
        fn:flush()
        fn:close()
    end
}

module.load = function ()
    -- Get workspace for gtd files and save full path in private
    local workspace = module.config.public.workspace or "default"
    module.private.workspace_full_path = module.required["core.norg.dirman"].get_workspace(workspace)

    -- Register keybinds
    module.required["core.keybinds"].register_keybind(module.name, "add_to_inbox")

    -- Add neorgcmd capabilities
    -- All gtd commands are start with :Neorg gtd ...
    module.required["core.neorgcmd"].add_commands_from_table({
        definitions = {
            gtd = { 
                capture = {},
                list = { inbox = {} }
            }
        },
        data = {
            gtd = {
                args = 1,
                subcommands = {
                    capture = { args = 0, name = "gtd.capture" },
                    list = { args = 1, name = "gtd.list", subcommands = {
                        inbox = { args = 0, name = "gtd.list.inbox" }
                    } }
                }
            }
        }
    })
end

module.on_event = function (event)
    if event.split_type[2] == "core.gtd.base.add_to_inbox" then
        module.public.add_task_to_inbox()
    end
    if event.split_type[1] == "core.neorgcmd" then
        if event.split_type[2] == "gtd.capture" then
            module.public.add_task_to_inbox()
        elseif event.split_type[2] == "gtd.list.inbox" then
            log.info("Opening inbox list")
        end
    end
end

module.public = {
    version = "0.1",

-- @Summary Add user task to inbox
-- @Description Show prompt asking for user input and append the task to the inbox
    add_task_to_inbox = function ()
        -- Define a callback (for prompt) to add the task to the inbox list
        local cb = function (text)
            module.private.add_to_list(module.private.default_lists.inbox, "- [ ] " .. text .. "\n")
        end

        -- Show prompt asking for input
        module.required["core.ui"].create_prompt(
            "INBOX_WINDOW",
            "Add to inbox.norg > ",
            cb,
            {
                center_x = true,
                center_y = true,
            },
            {
                width = 60,
                height = 1,
                row = 1,
                col = 1
            })

    end
}

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.gtd.base.add_to_inbox"] = true
    },
    ["core.neorgcmd"] = {
        ["gtd.capture"] = true,
        ["gtd.list.inbox"] = true
    }
}

return module
