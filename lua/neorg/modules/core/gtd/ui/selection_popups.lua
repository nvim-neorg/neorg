return function(module)
    return {
        public = {
            show_quick_actions = function(configs)
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
                                    { "s", "Someday" },
                                    { "d", "Due tasks", true },
                                },
                            },
                        },
                    },
                }, function(choices)
                    local tasks = module.required["core.gtd.queries"].get("tasks", { exclude_files = configs.exclude })
                    local projects = module.required["core.gtd.queries"].get(
                        "projects",
                        { exclude_files = configs.exclude }
                    )
                    tasks = module.required["core.gtd.queries"].add_metadata(tasks, "task")
                    projects = module.required["core.gtd.queries"].add_metadata(projects, "project")

                    if choices[1] == "a" then
                        module.public.add_task_to_inbox()
                    elseif choices[1] == "l" and choices[2] == "i" then
                        module.required["core.norg.dirman"].open_file(configs.workspace, configs.default_lists.inbox)
                    elseif choices[1] == "p" then
                        module.public.display_projects(tasks, projects, { priority = { "_" } })
                    elseif choices[1] == "t" then
                        if choices[2] == "t" then
                            module.public.display_today_tasks(tasks, { exclude = { "someday" } })
                        elseif choices[2] == "w" then
                            module.public.display_waiting_for(tasks)
                        elseif choices[2] == "s" then
                            module.public.display_someday(tasks)
                        elseif choices[2] == "d" then
                            log.warn(tasks)
                        elseif choices[2] == "c" then
                            module.public.display_contexts(tasks, { exclude = { "someday" }, priority = { "_" } })
                        end
                    elseif choices[1] == "x" then
                        local end_row, bufnr = module.required["core.gtd.queries"].get_end_document_content(
                            "index.norg"
                        )
                        module.required["core.gtd.queries"].create("project", {
                            content = "This is a test",
                            contexts = { "today", "someday" },
                            start = "2021-12-22",
                            due = "2021-12-23",
                            waiting_for = { "vhyrro" },
                        }, bufnr, end_row)
                    end
                end)
            end,
        },
    }
end
