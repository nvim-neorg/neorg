local module = neorg.modules.extend("core.gtd.ui.views_popup_helpers")

module.private = {
    --- Generate flags for specific mode (date related)
    --- @param selection table
    --- @param task table #Task to add due/start date
    --- @param mode string #Date mode to use: start|due
    --- @param flag string #The flag to use
    --- @return table #`selection`
    generate_date_flags = function(selection, task, mode, flag)
        local title = "Add a " .. mode .. " date"
        return selection:rflag(flag, title, function()
            selection
                :listener("go-back", { "<BS>" }, function(self)
                    self:pop_page()
                end)
                :title(title)
                :blank()
                :text("Static Times:")
                :flag("t", "Tomorrow", {
                    destroy = false,
                    callback = function()
                        task[mode] = module.required["core.gtd.queries"].date_converter("tomorrow")
                        selection:pop_page()
                    end,
                })
                :flag("w", "Next week", {
                    destroy = false,
                    callback = function()
                        task[mode] = module.required["core.gtd.queries"].date_converter("1w")
                        selection:pop_page()
                    end,
                })
                :flag("m", "Next month", {
                    destroy = false,
                    callback = function()
                        task[mode] = module.required["core.gtd.queries"].date_converter("1m")
                        selection:pop_page()
                    end,
                })
                :flag("y", "Next year", {
                    destroy = false,
                    callback = function()
                        task[mode] = module.required["core.gtd.queries"].date_converter("1y")
                        selection:pop_page()
                    end,
                })
                :blank()
                :text("Other:")
                :flag("s", "Someday", {
                    destroy = false,
                    callback = function()
                        log.warn("Unimplemented :(")
                        selection:pop_page()
                    end,
                })
                :rflag("c", "Custom", {
                    destroy = false,
                    callback = function()
                        selection
                            :title("Custom Date")
                            :text("Allowed date: today, tomorrow, Xw, Xd, Xm, Xy (where X is a number)")
                            :blank()
                            :prompt("Due", {
                                callback = function(text)
                                    if #text > 0 then
                                        task[mode] = module.required["core.gtd.queries"].date_converter(text)

                                        if not task[mode] then
                                            log.error("Date format not recognized, please try again...")
                                        else
                                            selection:pop_page()
                                        end
                                    end
                                end,
                                pop = true,
                            })
                    end,
                })
        end)
    end,

    --- Generate flags for specific mode
    --- @param selection table
    --- @param task table #Task to add contexts or waiting fors
    --- @param mode string #Date mode to use: waiting_for|contexts
    --- @param flag string #The flag to use
    --- @return table #`selection`
    generate_default_flags = function(selection, task, mode, flag)
        local title = (function()
            if mode == "contexts" then
                return "Add Contexts"
            elseif mode == "waiting.for" then
                return "Add Waiting Fors"
            end
        end)()

        return selection:rflag(flag, title, {
            destroy = false,
            callback = function()
                selection
                    :listener("go-back", { "<BS>" }, function(self)
                        self:pop_page()
                    end)
                    :title(title)
                    :text("Separate multiple values with space")
                    :blank()
                    :prompt(title, {
                        callback = function(text)
                            if #text > 0 then
                                task[mode] = task[mode] or {}
                                task[mode] = vim.list_extend(task[mode], vim.split(text, " ", false))
                            end
                        end,
                        pop = true,
                    })
            end,
        })
    end,

    generate_project_flags = function(selection, task, flag)
        return selection:flag("p", "Add to project", {
            callback = function()
                --[[ selection
                    :listener("go-back", { "<BS>" }, selection.pop_page)
                    :text("Helo") ]]
                log.warn("Unimplemented :(")
            end,
            destroy = false,
        })
    end,

    add_to_inbox = function(selection)
        return selection:rflag("a", "Add a task to the inbox", {
            callback = function()
                selection:title("Add a task to the inbox"):blank():prompt("Task", {
                    callback = function(text)
                        local task = {}
                        task.content = text

                        selection:push_page()

                        selection
                            :title("Add informations")
                            :blank()
                            :text("Task: " .. task.content)
                            :blank()
                            :text("General informations")
                            :concat(function()
                                return module.private.generate_default_flags(selection, task, "contexts", "c")
                            end)
                            :concat(function()
                                return module.private.generate_default_flags(selection, task, "waiting.for", "w")
                            end)
                            :blank()
                            :text("Dates")
                            :concat(function()
                                return module.private.generate_date_flags(selection, task, "due", "d")
                            end)
                            :concat(function()
                                return module.private.generate_date_flags(selection, task, "start", "s")
                            end)
                            :blank()
                            :concat(function()
                                return module.private.generate_project_flags(selection, task, "p")
                            end)
                            :flag("<CR>", "Finish", function()
                                local end_row, bufnr, projectAtEnd =
                                    module.required["core.gtd.queries"].get_end_document_content(
                                        "inbox.norg"
                                    )

                                module.required["core.gtd.queries"].create("task", task, bufnr, end_row, projectAtEnd)
                            end)

                        return selection
                    end,

                    -- Do not pop or destroy the prompt when confirmed
                    pop = false,
                    destroy = false,
                })
                return selection
            end,
            destroy = false,
        })
    end,

    generate_display_flags = function(selection, configs)
        -- Get tasks and projects
        local tasks = module.required["core.gtd.queries"].get("tasks", { exclude_files = configs.exclude })
        local projects = module.required["core.gtd.queries"].get("projects", { exclude_files = configs.exclude })
        tasks = module.required["core.gtd.queries"].add_metadata(tasks, "task")
        projects = module.required["core.gtd.queries"].add_metadata(projects, "project")

        selection
            :text("Tasks")
            :flag("t", "Today's tasks", function()
                module.public.display_today_tasks(tasks)
            end)
            :flag("c", "Contexts", function()
                module.public.display_contexts(tasks, { exclude = { "someday" }, priority = { "_" } })
            end)
            :flag("w", "Waiting For", function()
                module.public.display_waiting_for(tasks)
            end)
            :blank()
            :text("Projects")
            :flag("p", "Show projects", function()
                module.public.display_projects(tasks, projects, { priority = { "_" } })
            end)
        return selection
    end,
}

return module
