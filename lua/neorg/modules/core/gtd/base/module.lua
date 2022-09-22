--[[
    File: Getting-Things-Done
    Title: Base module for GTD workflow
    Summary: Manages your tasks with Neorg using the Getting Things Done methodology.
    ---
GTD ("Getting Things Done") is a system designed to make collecting and executing ideas simple.
You can read more about the GTD workflow [here](https://hamberg.no/gtd)!

> Want to use a tutorial project to know the basics of GTD in Neorg ?
> Follow the steps in [this](https://github.com/nvim-neorg/example_workspaces#neorg-gtd-tutorial) repository !

It's here where the keybinds and commands are created in order to interact with GTD stuff

- Call the command `:Neorg gtd views` to nicely show your tasks and projects
- Create a new task with `:Neorg gtd capture`
- Edit the task under the cursor with `:Neorg gtd edit`

Note: If you want to open your GTD views without changing your `pwd`, you can open Neorg in silent mode beforehand:

- `:NeorgStart silent=true`
- `:Neorg gtd views`
--]]

require("neorg.modules.base")
require("neorg.events")

local module = neorg.modules.create("core.gtd.base")
local log = require("neorg.external.log")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.norg.dirman",
            "core.keybinds",
            "core.gtd.ui",
            "core.gtd.helpers",
            "core.neorgcmd",
            "core.gtd.queries",
        },
    }
end

---@class core.gtd.base.config
module.config.public = {
    -- *Required*: Workspace name to use for gtd related lists
    workspace = nil,

    -- You can exclude files or directories from gtd parsing by passing them here (relative file path from workspace root)
    exclude = {},

    -- Default lists used for GTD
    default_lists = {
        inbox = "inbox.norg",
    },

    -- The syntax to use for gtd.
    syntax = {
        context = "#contexts",
        start = "#time.start",
        due = "#time.due",
        waiting = "#waiting.for",
    },
    -- User configurations for GTD views
    displayers = {
        projects = {
            show_completed_projects = true,
            show_projects_without_tasks = true,
        },
    },
    -- Generates custom completion for tags: #contexts,#waiting.for
    -- Generates it only once, when booting Neorg.
    -- It gets all tasks and projects, and retrieve all user-created tag values
    custom_tag_completion = false,
}

---@class core.gtd.base
module.public = {
    version = "0.0.8",
    callbacks = {},
}

module.private = {
    workspace_full_path = nil,

    --- Shows error messages when trying to run any gtd command, if GTD failed to start
    error_loading_message = function()
        log.error("Error in loading GTD. Please check your messages")
    end,
}

module.load = function()
    local error_loading = false

    ---@type core.norg.dirman
    local dirman = module.required["core.norg.dirman"]
    ---@type core.keybinds
    local keybinds = module.required["core.keybinds"]

    local workspace = module.config.public.workspace

    if not workspace then
        log.error([[
        Workspace not defined. Please update your gtd config
        For more information, check see the wiki:
        https://github.com/nvim-neorg/neorg/wiki/Getting-Things-Done#configuration
        ]])
        error_loading = true
    else
        module.private.workspace_full_path = dirman.get_workspace(workspace)

        -- Check if workspace is here
        if not module.private.workspace_full_path then
            log.error("Workspace " .. workspace .. " not created. Please create it with dirman module before")
            error_loading = true
        end
    end

    if not error_loading then
        ---@type core.gtd.helpers
        local helpers = module.required["core.gtd.helpers"]

        local files = helpers.get_gtd_files() or {}
        if not files then
            log.warn("No files found in " .. workspace .. " workspace")
        end

        if not vim.tbl_contains(files, module.config.public.default_lists.inbox) then
            dirman.create_file(module.config.public.default_lists.inbox, workspace, { no_open = true })
            log.warn("Inbox file not found in " .. workspace .. " workspace, creating it...")
        end
        local index = neorg.modules.get_module_config("core.norg.dirman").index
        if not vim.tbl_contains(files, index) then
            dirman.create_file(index, workspace, { no_open = true })
            log.warn("Index file not found in " .. workspace .. " workspace, creating it...")
        end
    end

    -- Register keybinds
    keybinds.register_keybinds(module.name, { "views", "edit", "capture" })

    -- Add neorgcmd capabilities
    -- All gtd commands start with :Neorg gtd ...
    module.required["core.neorgcmd"].add_commands_from_table({
        gtd = {
            args = 1,
            subcommands = {
                views = { args = 0, name = "gtd.views" },
                edit = { args = 0, name = "gtd.edit" },
                capture = { args = 0, name = "gtd.capture" },
            },
        },
    })

    -- Set up callbacks
    module.public.callbacks["get_data"] = module.required["core.gtd.ui"].get_data_for_views
    module.public.callbacks["gtd.edit"] = error_loading and module.private.error_loading_message
        or module.required["core.gtd.ui"].edit_task_at_cursor
    module.public.callbacks["gtd.capture"] = error_loading and module.private.error_loading_message
        or module.required["core.gtd.ui"].show_capture_popup
    module.public.callbacks["gtd.views"] = error_loading and module.private.error_loading_message
        or module.required["core.gtd.ui"].show_views_popup

    -- Stops load if there is any error. All code below will not be run
    if error_loading then
        return
    end

    -- Generates completion for gtd
    if not neorg.modules.is_module_loaded("core.norg.completion") then
        return
    end

    neorg.modules.await("core.norg.completion", function(completion_module)
        vim.schedule(function()
            for _, completion in pairs(completion_module.completions) do
                if vim.tbl_contains(completion.complete, "contexts") then
                    local contexts
                    local waiting_for
                    if module.config.public.custom_tag_completion then
                        local tasks = module.required["core.gtd.queries"].get("tasks")
                        local projects = module.required["core.gtd.queries"].get("projects")

                        if not (tasks and projects) then
                            return
                        end

                        tasks = module.required["core.gtd.queries"].add_metadata(
                            tasks,
                            "task",
                            { keys = { "contexts", "waiting.for" } }
                        )
                        projects = module.required["core.gtd.queries"].add_metadata(
                            projects,
                            "project",
                            { keys = { "contexts", "waiting.for" } }
                        )

                        contexts = module.private.find_by_key("contexts", tasks, projects, { "today", "someday" })
                        waiting_for = module.private.find_by_key("waiting.for", tasks, projects)
                    else
                        contexts = { "today", "someday" }
                        waiting_for = {}
                    end

                    local _completions = {
                        {
                            descend = {},
                            options = {
                                type = "GTDWaitingFor",
                            },
                            regex = "waiting.for%s+%w*",
                            complete = waiting_for,
                        },
                        {
                            descend = {},
                            options = {
                                type = "GTDContext",
                            },
                            regex = "contexts%s+%w*",
                            complete = contexts,
                        },
                    }
                    vim.list_extend(completion.descend, _completions)
                end
            end
        end)
    end)
end

module.private = {
    find_by_key = function(key, tasks, projects, default)
        local key_tbl = default or {}

        local function generate_if_present(tbl_src)
            for _, el in pairs(tbl_src) do
                if el[key] then
                    for _, _el in pairs(el[key]) do
                        if not vim.tbl_contains(key_tbl, _el) then
                            table.insert(key_tbl, _el)
                        end
                    end
                end
            end
        end

        generate_if_present(tasks)
        generate_if_present(projects)

        return key_tbl
    end,
}

module.on_event = function(event)
    if vim.tbl_contains({ "core.keybinds", "core.neorgcmd" }, event.split_type[1]) then
        if vim.tbl_contains({ "gtd.views", "core.gtd.base.views" }, event.split_type[2]) then
            local tasks, projects = module.public.callbacks["get_data"]()
            module.public.callbacks["gtd.views"](tasks, projects)
        elseif vim.tbl_contains({ "gtd.edit", "core.gtd.base.edit" }, event.split_type[2]) then
            module.public.callbacks["gtd.edit"]()
        elseif vim.tbl_contains({ "gtd.capture", "core.gtd.base.capture" }, event.split_type[2]) then
            module.public.callbacks["gtd.capture"]()
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

---@class core.gtd.base
module.public = {}

return module
