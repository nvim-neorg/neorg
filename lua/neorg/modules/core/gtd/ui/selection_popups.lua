return function(module)
    return {
        public = {
            show_quick_actions = function(configs)
                -- Generate quick_actions selection popup
                local buffer = module.required["core.ui"].create_split("Quick Actions")
                local selection = module.required["core.ui"].begin_selection(buffer)

                -- FIXME: The destroy listener is not bound in new pages
                selection:add_listener("destroy", { "q", "<Esc>" }, function()
                    selection:destroy()
                end)

                selection
                    :title("Quick Actions")
                    :blank()
                    :text("Capture")
                    :concat(module.private.add_to_inbox)
                    :blank()
                    :text("Displays")
                    :concat(function(_selection)
                        module.private.generate_display_flags(_selection, configs)
                    end)
            end,
        },
        private = {
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
                                    :rflag("d", "Add a due date", function()
                                        selection
                                            :title("Add a due date")
                                            :blank()
                                            :flag("t", "Tomorrow", {
                                                destroy = false,
                                                callback = function()
                                                    task.due = module.public.date_converter("tomorrow")
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
                                                                    task.due = module.public.date_converter(text)
                                                                    if not task.due then
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
                                    :flag("f", "Finish", function()
                                        local end_row, bufnr =
                                            module.required["core.gtd.queries"].get_end_document_content(
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
