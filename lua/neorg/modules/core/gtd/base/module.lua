--[[
    File: Getting-Things-Done
    Title: Base module for GTD workflow
    Summary: Manages your tasks with Neorg using the Getting Things Done methodology.
    ---
GTD ("Getting Things Done") is a system designed to make collecting and executing ideas simple.
You can read more about the GTD implementation [here](https://www.ionos.com/startupguide/productivity/getting-things-done-gtd)!

It's here where the keybinds and commands are created in order to interact with GTD stuff

- Call the command `:Neorg gtd views` to nicely show your tasks and projects
- Create a new task with `:Neorg gtd capture`
- Edit the task under the cursor with `:Neorg gtd edit`
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
            "core.neorgcmd",
            "core.norg.completion",
            "core.gtd.queries",
        },
    }
end

---@class core.gtd.base.config
module.config.public = {
    -- Workspace name to use for gtd related lists
    workspace = "default",
    -- Filenames to use for default lists
    default_lists = {
        inbox = "inbox.norg",
    },
    -- You can exclude files or directories from gtd parsing by passing them here (relative file path from workspace root)
    exclude = {},

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
}

module.private = {
    workspace_full_path = "",
}

module.load = function()
    ---@type core.norg.dirman
    local dirman = module.required["core.norg.dirman"]
    ---@type core.keybinds
    local keybinds = module.required["core.keybinds"]

    -- Get workspace for gtd files and save full path in private
    local workspace = module.config.public.workspace
    module.private.workspace_full_path = dirman.get_workspace(workspace)

    -- Register keybinds
    keybinds.register_keybinds(module.name, { "views", "edit", "capture" })

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

    -- Generates completion for gtd

    vim.schedule(function()
        for _, completion in pairs(module.required["core.norg.completion"].completions) do
            if vim.tbl_contains(completion.complete, "contexts") then
                local contexts
                local waiting_for
                if module.config.public.custom_tag_completion then
                    local exclude_files = module.config.public.exclude
                    table.insert(exclude_files, module.config.public.default_lists.inbox)
                    local tasks = module.required["core.gtd.queries"].get("tasks", { exclude_files = exclude_files })
                    local projects = module.required["core.gtd.queries"].get(
                        "projects",
                        { exclude_files = exclude_files }
                    )

                    if not tasks or not projects then
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
            module.required["core.gtd.ui"].show_views_popup()
        elseif vim.tbl_contains({ "gtd.edit", "core.gtd.base.edit" }, event.split_type[2]) then
            module.required["core.gtd.ui"].edit_task_at_cursor()
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

---@class core.gtd.base
module.public = {}

return module
