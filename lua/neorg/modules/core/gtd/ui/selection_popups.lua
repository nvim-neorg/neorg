return function(module)
    return {
        public = {
            show_quick_actions = function(configs)
                -- Get tasks and projects
                local tasks = module.required["core.gtd.queries"].get("tasks", { exclude_files = configs.exclude })
                local projects = module.required["core.gtd.queries"].get(
                    "projects",
                    { exclude_files = configs.exclude }
                )
                tasks = module.required["core.gtd.queries"].add_metadata(tasks, "task")
                projects = module.required["core.gtd.queries"].add_metadata(projects, "project")

                -- Generate quick_actions selection popup
                local buffer = module.required["core.ui"].create_split("Quick Actions")
                local selection = module.required["core.ui"].begin_selection(buffer)

                selection
                    :title("This is a text")
                    :blank()
                    :text("Capture")
                    :flag("a", "Add a task to inbox", module.public.add_task_to_inbox)
                    :blank()
                    :text("Displays")
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
            end,
        },
    }
end
