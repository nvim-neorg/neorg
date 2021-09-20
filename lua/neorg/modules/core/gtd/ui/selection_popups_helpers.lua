return function (module)
    return {
        private = {
            --- Generate flags for specific mode
            --- @param selection table
            --- @param task table #Task to add due/start date
            --- @param mode string #Date mode to use: start|due
            --- @param flag string #The flag to use
            --- @return table #`selection`
            generate_date_flags = function (selection, task, mode, flag)
                local title = "Add a " .. mode .. " date"
                selection:rflag(flag, title, function()
                    selection
                    :title(title)
                    :blank()
                    :flag("t", "Tomorrow", {
                        destroy = false,
                        callback = function()
                            task[mode] = module.public.date_converter("tomorrow")
                            selection:pop_page()
                        end,
                    })
                    :flag("c", "Custom", {
                        destroy = false,
                        callback = function()
                            selection:push_page()
                            selection
                            :title("Custom Date")
                            :text(
                                "Allowed date: today, tomorrow, Xw, Xd, Xm (X is a number)"
                            )
                            :blank()
                            :prompt("Due", {
                                callback = function(text)
                                    if #text > 0 then
                                        task[mode] = module.public.date_converter(text)
                                        if not task[mode] then
                                            log.error(
                                                "Date format not recognized, please try again..."
                                            )
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

                return selection
            end,

            add_to_inbox = function(selection)
                selection:flag("a", "Add a task to inbox", {
                    callback = function()
                        selection:push_page()

                        selection:title("Add a task to inbox"):blank():prompt("Task", {
                            callback = function(text)
                                local task = {}
                                task.content = text
                                selection:push_page()

                                selection
                                :title("Hey")
                                :blank()
                                :text("Task: " .. task.content)
                                :blank()
                                :flag("c", "Add Contexts", {
                                    destroy = false,
                                    callback = function()
                                        selection:push_page()
                                        selection
                                        :title("Add contexts")
                                        :text("Separate contexts with space")
                                        :blank()
                                        :prompt("Contexts", {
                                            callback = function(text)
                                                if #text > 0 then
                                                    task.contexts = task.contexts or {}
                                                    task.contexts = vim.list_extend(
                                                        task.contexts,
                                                        vim.split(text, " ", false)
                                                    )
                                                end
                                            end,
                                            pop = true,
                                        })
                                    end,
                                })
                                :concat(function (_selection)
                                    return module.private.generate_date_flags(_selection, task, "due", "d")
                                end)
                                :concat(function (_selection)
                                    return module.private.generate_date_flags(_selection, task, "start", "s")
                                end)
                                :flag("f", "Finish", function()
                                    local end_row, bufnr = module.required["core.gtd.queries"].get_end_document_content(
                                            "inbox.norg"
                                        )
                                    module.required["core.gtd.queries"].create("task", task, bufnr, end_row)
                                end)
                            end,
                            -- Do not pop or destroy the prompt when confirmed
                            pop = false,
                            destroy = false,
                        })
                    end,
                    destroy = false,
                })
                return selection
            end,

            generate_display_flags = function(selection, configs)
                -- Get tasks and projects
                local tasks = module.required["core.gtd.queries"].get("tasks", { exclude_files = configs.exclude })
                local projects = module.required["core.gtd.queries"].get(
                    "projects",
                    { exclude_files = configs.exclude }
                )
                tasks = module.required["core.gtd.queries"].add_metadata(tasks, "task")
                projects = module.required["core.gtd.queries"].add_metadata(projects, "project")

                selection
                :flag("p", "Projects", function()
                    module.public.display_projects(tasks, projects, { priority = { "_" } })
                end)
                :rflag("t", "Tasks", function()
                    selection
                    :title("Tasks")
                    :blank(2)
                    :flag("t", "Today's tasks", function()
                        module.public.display_today_tasks(tasks)
                    end)
                    :flag("c", "Contexts", function()
                        module.public.display_contexts(tasks, { exclude = { "someday" }, priority = { "_" } })
                    end)
                    :flag("w", "Waiting For", function()
                        module.public.display_waiting_for(tasks)
                    end)
                end)
                return selection
            end,
        },
    }
end
