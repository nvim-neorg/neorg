local module = neorg.modules.extend("core.gtd.ui.displayers")

module.public = {
    --- Display today view for `tasks`, grouped by contexts
    --- @param tasks table
    --- @param opts table
    ---   - opts.exclude (table):   exclude all tasks that contain one of the contexts specified in the table
    display_today_tasks = function(tasks, opts)
        vim.validate({
            tasks = { tasks, "table" },
            opts = { opts, "table", true },
        })

        opts = opts or {}
        local name = "Today's Tasks"
        local res = {
            "* " .. name,
            "",
            "For a pending or undone task to appear here, it must meet one of these criterias:",
            "- Task marked with `today` context, and already started",
            "- Task starting today",
            "- Task due for today",
            "",
        }

        -- Remove tasks that contains any of the excluded contexts
        if opts.exclude then
            local exclude_tasks = function(t)
                if not t.contexts then
                    return true
                end

                for _, c in pairs(t.contexts) do
                    if vim.tbl_contains(opts.exclude, c) then
                        return false
                    end
                end
                return true
            end
            tasks = vim.tbl_filter(exclude_tasks, tasks)
        end

        local contexts_tasks = module.required["core.gtd.queries"].sort_by("contexts", tasks)

        local contexts = vim.tbl_keys(contexts_tasks)

        contexts = vim.tbl_filter(function(c)
            return c ~= "today"
        end, contexts)

        for _, c in ipairs(contexts) do
            local today_tasks = vim.tbl_filter(module.private.today_task, contexts_tasks[c])
            if #today_tasks > 0 then
                table.insert(res, "** " .. c)

                for _, t in pairs(today_tasks) do
                    local content = "- " .. t.content
                    if t.project then
                        content = content .. " `in " .. t.project .. "`"
                    end
                    if t["time.start"] then
                        local diff = module.required["core.gtd.queries"].diff_with_today(t["time.start"][1])
                        if diff.weeks == 0 and diff.days == 0 then
                            content = content .. ", `starting today`"
                        end
                    end
                    if t["time.due"] then
                        local diff = module.required["core.gtd.queries"].diff_with_today(t["time.due"][1])
                        if diff.weeks == 0 and diff.days == 0 then
                            content = content .. ", `due for today`"
                        end
                    end

                    table.insert(res, content)
                end
                table.insert(res, "")
            end
        end
        local buf = module.required["core.ui"].create_norg_buffer(name, "vsplitr")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, res)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
    end,

    display_waiting_for = function(tasks)
        vim.validate({
            tasks = { tasks, "table" },
        })

        local name = "Waiting For Tasks"
        local res = {
            "* " .. name,
            "",
        }

        -- Only show waiting fors that are not done and are already started
        local filters = function(t)
            local already_started = true
            if t["time.start"] then
                already_started = not module.required["core.gtd.queries"].starting_after_today(t["time.start"][1])
            end
            return t.state ~= "done" and already_started
        end

        tasks = vim.tbl_filter(filters, tasks)

        local waiting_for_tasks = module.required["core.gtd.queries"].sort_by("waiting.for", tasks)
        waiting_for_tasks["_"] = nil -- remove all tasks that does not have waiting for tag

        for w, w_tasks in pairs(waiting_for_tasks) do
            table.insert(res, "** " .. w)
            for _, t in pairs(w_tasks) do
                local content = "- " .. t.content
                table.insert(res, content)
            end
            table.insert(res, "")
        end

        local buf = module.required["core.ui"].create_norg_buffer(name, "vsplitr")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, res)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
    end,

    --- Display contexts view for `tasks`
    --- @param tasks table
    --- @param opts table
    ---   - opts.exclude (table):   exclude all tasks that contain one of the contexts specified in the table
    ---   - opts.priority (table):  will prioritize in the display the contexts specified (order in priority contexts not guaranteed)
    display_contexts = function(tasks, opts)
        vim.validate({
            tasks = { tasks, "table" },
            opts = { opts, "table", true },
        })

        opts = opts or {}
        local name = "Contexts"
        local res = {
            "* " .. name,
            "",
        }

        -- Keep undone tasks and not waiting for ones
        local filter = function(t)
            local already_started = true
            if t["time.start"] then
                already_started = not module.required["core.gtd.queries"].starting_after_today(t["time.start"][1])
            end
            return t.state ~= "done" and not t["waiting.for"] and already_started
        end

        tasks = vim.tbl_filter(filter, tasks)

        -- Remove tasks that contains any of the excluded contexts
        if opts.exclude then
            local exclude_tasks = function(t)
                if not t.contexts then
                    return true
                end

                for _, c in pairs(t.contexts) do
                    if vim.tbl_contains(opts.exclude, c) then
                        return false
                    end
                end
                return true
            end
            tasks = vim.tbl_filter(exclude_tasks, tasks)
        end

        local contexts_tasks = module.required["core.gtd.queries"].sort_by("contexts", tasks)
        contexts_tasks["today"] = nil -- Remove "today" context

        -- Sort tasks with opts.priority
        local contexts = vim.tbl_keys(contexts_tasks)
        if opts.priority then
            local contexts_sorter = function(a, _)
                return vim.tbl_contains(opts.priority, a)
            end
            table.sort(contexts, contexts_sorter)
        end

        for _, context in ipairs(contexts) do
            local c_tasks = contexts_tasks[context]
            local inserted_context = "** " .. context
            if context == "_" then
                inserted_context = "** /(No contexts)/"
            end
            table.insert(res, inserted_context)
            for _, t in pairs(c_tasks) do
                table.insert(res, "- " .. t.content)
            end
            table.insert(res, "")
        end

        local buf = module.required["core.ui"].create_norg_buffer(name, "vsplitr")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, res)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
    end,

    --- Display formatted projects from `tasks` table. Uses `projects` table to find all projects
    --- @param tasks table
    --- @param projects table
    --- @param opts table
    ---   - opts.priority (table):  will prioritize in the display the projects specified (order in prioritized projects not guaranteed)
    display_projects = function(tasks, projects, opts)
        vim.validate({
            tasks = { tasks, "table" },
            projects = { projects, "table" },
            opts = { opts, "table", true },
        })

        opts = opts or {}
        local name = "Projects"
        local res = {
            "* " .. name,
            "",
        }
        projects = vim.tbl_map(function(p)
            return p.content
        end, projects)

        table.insert(projects, "_")
        local projects_tasks = module.required["core.gtd.queries"].sort_by("project", tasks)

        -- Remove duplicates in projects
        projects = module.private.remove_duplicates(projects)

        -- Sort tasks with opts.priority
        if opts.priority then
            local projects_sorter = function(a, _)
                return vim.tbl_contains(opts.priority, a)
            end
            table.sort(projects, projects_sorter)
        end

        for _, project in ipairs(projects) do
            local tasks_project = projects_tasks[project] or {}

            local completed = vim.tbl_filter(function(t)
                return t.state == "done"
            end, tasks_project)

            if project ~= "_" then
                table.insert(res, "** " .. project .. " (" .. #completed .. "/" .. #tasks_project .. " done)")

                local percent_completed = (function()
                    if #tasks_project == 0 then
                        return 0
                    end
                    return math.floor(#completed * 100 / #tasks_project)
                end)()

                local completed_over_10 = math.floor(percent_completed / 10)
                local percent_completed_visual = "["
                    .. string.rep("=", completed_over_10)
                    .. string.rep(" ", 10 - completed_over_10)
                    .. "]"
                table.insert(res, "   " .. percent_completed_visual .. " " .. percent_completed .. "% done")
            elseif project == "_" and #tasks_project ~= 0 then
                local undone = vim.tbl_filter(function(a, _)
                    return a.state ~= "done"
                end, tasks_project)
                table.insert(res, "- /" .. #undone .. " tasks don't have a project assigned/")
            end
            table.insert(res, "")
        end

        local buf = module.required["core.ui"].create_norg_buffer(name, "vsplitr")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, res)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
    end,

    display_someday = function(tasks)
        vim.validate({
            tasks = { tasks, "table" },
        })

        local name = "Someday Tasks"
        local res = {
            "* " .. name,
            "",
        }
        local someday_task = function(task)
            if not task.contexts then
                return false
            end
            return task.state ~= "done" and vim.tbl_contains(task.contexts, "someday")
        end

        local someday_tasks = vim.tbl_filter(someday_task, tasks)

        if #someday_tasks ~= 0 then
            for _, t in pairs(someday_tasks) do
                local inserted = "- " .. t.content
                if #t.contexts ~= 0 then
                    local remove_someday = vim.tbl_filter(function(t)
                        return t ~= "someday"
                    end, t.contexts)

                    if #remove_someday >= 1 then
                        remove_someday = vim.tbl_map(function(c)
                            return "`" .. c .. "`"
                        end, remove_someday)
                        inserted = inserted .. " (" .. table.concat(remove_someday, ",") .. ")"
                    end
                end
                table.insert(res, inserted)
            end
        end

        local buf = module.required["core.ui"].create_norg_buffer(name, "vsplitr")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, res)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
    end,

    display_weekly_summary = function(tasks)
        -- TODO: Add date ranges
        local name = "Weekly Summary"
        local res = {
            "* " .. name,
            "",
        }

        table.insert(res, "** Today")
        table.insert(res, "")
        local today_tasks = vim.tbl_filter(module.private.today_task, tasks)
        for _, t in pairs(today_tasks) do
            local result = "- " .. t.content
            if t.contexts then
                if vim.tbl_contains(t.contexts, "today") then
                    result = result .. " `marked as today`"
                end
            end
            if t["time.start"] then
                local diff = module.required["core.gtd.queries"].diff_with_today(t["time.start"][1])
                if diff.weeks == 0 and diff.days == 0 then
                    result = result .. ", `starting today`"
                end
            end
            if t["time.due"] then
                local diff = module.required["core.gtd.queries"].diff_with_today(t["time.due"][1])
                if diff.weeks == 0 and diff.days == 0 then
                    result = result .. ", `due for today`"
                end
            end
            table.insert(res, result)
        end

        local filter_upcoming_tasks = function(task, day)
            local due = false
            local start = false
            if task["time.start"] then
                start = task["time.start"][1] == day
            end
            if task["time.due"] then
                due = task["time.due"][1] == day
            end

            return due or start
        end

        local days = { "tomorrow", "2d", "3d", "4d", "5d", "6d" }

        for i, d in ipairs(days) do
            local date = module.required["core.gtd.queries"].date_converter(d)
            local filtered_tasks = vim.tbl_filter(function(t)
                return filter_upcoming_tasks(t, date)
            end, tasks)

            table.insert(res, "")
            if d == "tomorrow" then
                table.insert(res, "** Tomorrow (" .. date .. ")")
            else
                table.insert(res, "** " .. date)
            end
            table.insert(res, "")
            for _, t in pairs(filtered_tasks) do
                local result = "- " .. t.content
                if t["time.start"] then
                    local diff = module.required["core.gtd.queries"].diff_with_today(t["time.start"][1])
                    if diff.weeks == 0 and diff.days == i then
                        result = result .. ", `starting this day`"
                    end
                end
                if t["time.due"] then
                    local diff = module.required["core.gtd.queries"].diff_with_today(t["time.due"][1])
                    if diff.weeks == 0 and diff.days == i then
                        result = result .. ", `due this day`"
                    end
                end
                table.insert(res, result)
            end
        end

        local buf = module.required["core.ui"].create_norg_buffer(name, "vsplitr")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, res)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
    end,
}

module.private = {
    --- Removes duplicates items from table `t`
    --- @param t table
    --- @return table
    remove_duplicates = function(t)
        vim.validate({ t = { t, "table" } })

        local res = {}
        for _, v in ipairs(t) do
            if not vim.tbl_contains(res, v) then
                table.insert(res, v)
            end
        end
        return res
    end,

    today_task = function(task)
        local today_context = false
        if task.contexts then
            today_context = vim.tbl_contains(task.contexts, "today")
        end

        local today_state = (task.state ~= "done")

        local already_started = true
        local starting_today = false
        if task["time.start"] then
            already_started = not module.required["core.gtd.queries"].starting_after_today(task["time.start"][1])
            local diff = module.required["core.gtd.queries"].diff_with_today(task["time.start"][1])
            starting_today = diff.days == 0 and diff.weeks == 0
        end

        local due_today = false
        if task["time.due"] then
            local diff = module.required["core.gtd.queries"].diff_with_today(task["time.due"][1])
            due_today = diff.days == 0 and diff.weeks == 0
        end

        -- all not done tasks:
        --   - marked as today and starting after today
        --   - starting today
        --   - due for today
        return today_state and (starting_today or due_today or (today_context and already_started))
    end,
}

return module
