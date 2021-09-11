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
        - core.ui in order to ask for user input
        - core.neorgcmd to add commands capabilities
        - core.queries.native to fetch content from norg files
        - core.integrations.treesitter to use ts_utils

KEYBINDS:
    - core.gtd.base.add_to_inbox: Will call the function add_task_to_inbox()

--]]

require("neorg.modules.base")
require("neorg.events")

local module = neorg.modules.create("core.gtd.base")
local utils = require("neorg.external.helpers")
local log = require("neorg.external.log")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.norg.dirman",
            "core.keybinds",
            "core.gtd.ui",
            "core.ui",
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
            module.required["core.ui"].create_selection("Quick actions", {
                flags = {
                    { "a", "Add a task to inbox" },
                    {
                        "l",
                        {
                            name = "List files",
                            flags = {
                                { "i", "Inbox" },
                            },
                        },
                    },
                    {},
                    { "Test Queries (index.norg) file", "TSComment" },
                    { "x", "testing" },
                    { "p", "Projects" },
                    {
                        "t",
                        {
                            name = "Tasks",
                            flags = {
                                { "t", "Today tasks" },
                                { "c", "contexts" },
                                { "w", "Waiting for" },
                                { "d", "Due tasks", true },
                                { "s", "Start tasks", true },
                            },
                        },
                    },
                },
            }, function(choices)
                local tasks = module.required["core.gtd.queries"].get("tasks", { exclude_files = module.config.public.exclude })
                local projects = module.required["core.gtd.queries"].get("projects", { exclude_files = module.config.public.exclude })
                tasks = module.required["core.gtd.queries"].add_metadata(tasks, "task")
                projects = module.required["core.gtd.queries"].add_metadata(projects, "project")

                if choices[1] == "a" then
                    module.required["core.gtd.ui"].add_task_to_inbox()
                elseif choices[1] == "l" and choices[2] == "i" then
                    module.required["core.norg.dirman"].open_file(
                        module.config.public.workspace,
                        module.config.public.default_lists.inbox
                    )
                elseif choices[1] == "p" then
                    module.required["core.gtd.ui"].display_projects(tasks, projects, { priority = { "_" } })
                elseif choices[1] == "t" then
                    if choices[2] == "t" then
                        module.required["core.gtd.ui"].display_today_tasks(tasks)
                    elseif choices[2] == "w" then
                        module.required["core.gtd.ui"].display_waiting_for(tasks)
                    elseif choices[2] == "s" then
                        log.warn(tasks)
                    elseif choices[2] == "d" then
                        log.warn(tasks)
                    elseif choices[2] == "c" then
                        module.required["core.gtd.ui"].display_contexts(
                            tasks,
                            { exclude = { "someday" }, priority = { "_" } }
                        )
                    end
                elseif choices[1] == "x" then
                    local end_row, bufnr = module.required["core.gtd.queries"].get_end_document_content("index.norg")
                    module.required["core.gtd.queries"].create("project", {
                        content = "This is a test",
                        contexts = { "today", "someday" },
                        start = "2021-12-22",
                        due = "2021-12-23",
                        waiting_for = { "vhyrro" },
                    }, bufnr, end_row)
                end
            end)
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
