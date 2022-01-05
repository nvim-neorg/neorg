local module = neorg.modules.extend("core.gtd.ui.displayers")

---@class core.gtd.ui
module.public = {
    --- Display today view for `tasks`, grouped by contexts
    --- @param tasks core.gtd.queries.task
    --- @param opts table
    ---   - opts.exclude (table):   exclude all tasks that contain one of the contexts specified in the table
    --- @overload fun(tasks:table)
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
            "- Task marked as pending",
            "",
        }
        local positions = {}

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

        tasks = vim.tbl_filter(module.private.today_task, tasks)

        -- Sort tasks by contexts
        local contexts_tasks = module.required["core.gtd.queries"].sort_by("contexts", tasks)

        -- Remove duplicated tasks in today
        if contexts_tasks.today then
            contexts_tasks.today = vim.tbl_filter(function(t)
                return #t.contexts == 1
            end, contexts_tasks.today)

            -- Merge today context with "No contexts" tasks
            if not contexts_tasks["_"] then
                contexts_tasks["_"] = contexts_tasks.today
            else
                for _, task in pairs(contexts_tasks.today) do
                    table.insert(contexts_tasks["_"], task)
                end
            end
            contexts_tasks.today = nil
        end

        -- Prioritize the contexts below
        local contexts = vim.tbl_keys(contexts_tasks)
        local priority = { "_" }
        local contexts_sorter = function(a, _)
            return vim.tbl_contains(priority, a)
        end
        table.sort(contexts, contexts_sorter)

        for _, context in ipairs(contexts) do
            local _tasks = contexts_tasks[context]
            if #_tasks > 0 then
                local inserted_context = context
                if context == "_" then
                    inserted_context = "/(No contexts)/"
                end
                table.insert(res, "** " .. inserted_context)

                for _, t in pairs(_tasks) do
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
                        elseif diff.weeks < 0 or diff.days < 0 then
                            content = content .. ", `overdue: " .. t["time.due"][1] .. "`"
                        end
                    end

                    table.insert(res, content)
                    positions[#res] = t
                end
                table.insert(res, "")
            end
        end
        return module.private.generate_display(name, positions, res)
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
        local positions = {}

        -- Only show waiting fors that are not done and are already started
        local filters = function(t)
            local already_started = true
            if t["time.start"] then
                already_started = not module.required["core.gtd.queries"].starting_after_today(t["time.start"][1], true)
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
                positions[#res] = t
            end
            table.insert(res, "")
        end

        return module.private.generate_display(name, positions, res)
    end,

    --- Display contexts view for `tasks`
    --- @param tasks core.gtd.queries.task
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
        local positions = {}

        -- Keep undone tasks and not waiting for ones
        local filter = function(t)
            local already_started = true
            if t["time.start"] then
                already_started = not module.required["core.gtd.queries"].starting_after_today(t["time.start"][1], true)
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
                positions[#res] = t
            end
            table.insert(res, "")
        end

        return module.private.generate_display(name, positions, res)
    end,

    --- integer percent calculation with check for zero in denominator
    --- @param numerator number
    --- @param denominator number
    percent = function(numerator, denominator)
        if denominator == 0 then
            return 0
        end
        return math.floor(numerator * 100 / denominator)
    end,

    --- make a progress bar from a percentage
    --- @param pct number
    percent_string = function(pct)
        local completed_over_10 = math.floor(pct / 10)
        return "[" .. string.rep("=", completed_over_10) .. string.rep(" ", 10 - completed_over_10) .. "]"
    end,

    --- Display formatted projects from `tasks` table. Uses `projects` table to find all projects
    --- @param tasks core.gtd.queries.task
    --- @param projects core.gtd.queries.project
    display_projects = function(tasks, projects)
        vim.validate({
            tasks = { tasks, "table" },
            projects = { projects, "table" },
        })

        local name = "Projects"
        local res = {
            "*" .. name .. "*",
            "",
        }
        local positions = {}

        local projects_tasks = module.required["core.gtd.queries"].sort_by("project_uuid", tasks)

        -- Show informations for tasks without projects
        local unknown_project = projects_tasks["_"]
        if unknown_project and #unknown_project > 0 then
            local undone = vim.tbl_filter(function(a, _)
                return a.state ~= "done"
            end, unknown_project)
            table.insert(res, "- /" .. #undone .. " tasks don't have a project assigned/")
            positions[#res] = undone
            table.insert(res, "")
        end

        local projects_by_aof = module.required["core.gtd.queries"].sort_by("area_of_focus", projects)

        -- Prioritize the contexts below
        local aofs = vim.tbl_keys(projects_by_aof)
        local sorter = function(a, _)
            return a == "_"
        end

        local user_configs = neorg.modules.get_module_config("core.gtd.base").displayers.projects

        table.sort(aofs, sorter)
        local added_projects = {}
        for _, aof in ipairs(aofs) do
            local _projects = projects_by_aof[aof]
            if aof == "_" then
                table.insert(res, "| /Projects with no Area Of Focus/")
            else
                table.insert(res, "| " .. aof)
            end
            table.insert(res, "")
            for _, project in pairs(_projects) do
                local tasks_project = module.private.find_project(projects_tasks, project.internal.node) or {}

                local completed = vim.tbl_filter(function(t)
                    return t.state == "done"
                end, tasks_project)

                if vim.tbl_isempty(tasks_project) and not user_configs.show_projects_without_tasks then
                    goto continue
                end

                if not user_configs.show_completed_projects and #tasks_project > 0 and #completed == #tasks_project then
                    goto continue
                end

                if project ~= "_" and not vim.tbl_contains(added_projects, project.internal.node) then
                    table.insert(
                        res,
                        "* " .. project.content .. " (" .. #completed .. "/" .. #tasks_project .. " done)"
                    )
                    positions[#res] = project

                    local pct = module.public.percent(#completed, #tasks_project)
                    local pct_str = module.public.percent_string(pct)
                    table.insert(res, "   " .. pct_str .. " " .. pct .. "% done")
                    table.insert(added_projects, project.internal.node)
                    table.insert(res, "")
                end
                ::continue::
            end
        end

        module.private.extras = projects_tasks
        return module.private.generate_display(name, positions, res)
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
        local positions = {}

        local someday_task = function(task)
            if not task.contexts then
                return false
            end
            return task.state ~= "done" and vim.tbl_contains(task.contexts, "someday")
        end

        local someday_tasks = vim.tbl_filter(someday_task, tasks)

        if #someday_tasks ~= 0 then
            for _, task in pairs(someday_tasks) do
                local inserted = "- " .. task.content
                if #task.contexts ~= 0 then
                    local remove_someday = vim.tbl_filter(function(t)
                        return t ~= "someday"
                    end, task.contexts)

                    if #remove_someday >= 1 then
                        remove_someday = vim.tbl_map(function(c)
                            return "`" .. c .. "`"
                        end, remove_someday)
                        inserted = inserted .. " (" .. table.concat(remove_someday, ",") .. ")"
                    end
                end
                table.insert(res, inserted)
                positions[#res] = task
            end
        end

        return module.private.generate_display(name, positions, res)
    end,

    display_weekly_summary = function(tasks)
        local name = "Weekly Summary"
        local res = {
            "* " .. name,
            "",
            "This is a summary of your tasks due or starting these next 7 days",
            "",
        }
        local positions = {}

        table.insert(res, "** Today")
        table.insert(res, "")
        local today_tasks = vim.tbl_filter(module.private.today_task, tasks)
        for _, t in pairs(today_tasks) do
            local result = "- " .. t.content
            if t.contexts then
                if vim.tbl_contains(t.contexts, "today") then
                    result = result .. ", `marked as today`"
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
                elseif diff.weeks < 0 or diff.days < 0 then
                    result = result .. ", `overdue: " .. t["time.due"][1] .. "`"
                end
            end
            table.insert(res, result)
            positions[#res] = t
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

            return task.state ~= "done" and (due or start)
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
                positions[#res] = t
            end
        end

        return module.private.generate_display(name, positions, res)
    end,
}

module.private = {
    data = {},
    current_bufnr = nil,
    display_namespace_nr = nil,

    today_task = function(task)
        local today_context = false
        if task.contexts then
            today_context = vim.tbl_contains(task.contexts, "today")
        end

        local state = task.state ~= "done"

        local already_started = true
        local starting_today = false
        if task["time.start"] then
            already_started = not module.required["core.gtd.queries"].starting_after_today(task["time.start"][1], true)
            local diff = module.required["core.gtd.queries"].diff_with_today(task["time.start"][1])
            starting_today = diff.days == 0 and diff.weeks == 0
        end

        local due_today = false
        if task["time.due"] then
            local diff = module.required["core.gtd.queries"].diff_with_today(task["time.due"][1])
            due_today = diff.days <= 0 and diff.weeks <= 0
        end

        return state
            and (
                starting_today
                or due_today
                or (today_context and already_started)
                or (task.state == "pending" and already_started)
            )
    end,

    --- Create the buffer and attach options to it
    --- @param name string the buffer name
    --- @param vars table the variables to add in the data. Must be of a table of type [line] = data
    --- @param res table the lines to add
    generate_display = function(name, vars, res)
        local buf = module.required["core.ui"].create_norg_buffer(name, "vsplitr", nil, { keybinds = false })
        module.required["core.mode"].set_mode("gtd-displays")

        module.private.data = vars
        module.private.current_bufnr = buf
        module.private.display_namespace_nr = vim.api.nvim_create_namespace("neorg display")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, res)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)

        return buf
    end,

    --- Update created variables inside the buffer (will offset the variables depending of the lines_inserted)
    --- @param lines_inserted table the lines inserted
    --- @param line number the position of the line we inserted the values from
    --- @param remove boolean|nil if true, will offset the variables negatively
    update_vars = function(lines_inserted, line, remove)
        local lines = vim.api.nvim_buf_line_count(module.private.current_bufnr)
        local updated_vars = {}

        for i = line, lines do
            local var = module.private.data[i]

            -- Remove the var at positions after the line, and save them to updated_vars
            if var then
                updated_vars[i] = var
                module.private.data[i] = nil
            end
        end

        for i, var in pairs(updated_vars) do
            local new_line
            if remove then
                new_line = i - #lines_inserted
            else
                new_line = i + #lines_inserted
            end

            module.private.data[new_line] = var
        end
        -- P(vim.tbl_keys(module.private.data))
    end,

    --- Get the corresponding task from the buffer variable in the current line
    --- @return core.gtd.queries.task the task node
    get_by_var = function()
        -- Get the current task at cursor
        local current_line = vim.api.nvim_win_get_cursor(0)[1]
        local data = module.private.data[current_line]

        -- If not under task, return as is
        if not data then
            return {}
        end

        return data
    end,

    goto_node = function()
        local data = module.private.get_by_var()

        if not data or vim.tbl_isempty(data) then
            return
        end

        module.private.close_buffer()

        -- Go to the node
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()
        vim.api.nvim_win_set_buf(0, data.internal.bufnr)
        ts_utils.goto_node(data.internal.node)

        -- Reset the data
        module.private.data = {}
        module.private.extras = {}
    end,

    refetch_data_not_extracted = function(node, _type)
        -- Get all nodes from the bufnr and add metadatas to it
        -- This is mandatory because we need to have the correct task position, else the update will not work
        local nodes = module.required["core.gtd.queries"].get(_type .. "s", { bufnr = node[2] })
        nodes = module.required["core.gtd.queries"].add_metadata(nodes, _type, { extract = false, same_node = true })

        -- Find the correct task node
        local found_data = vim.tbl_filter(function(n)
            return n.node:id() == node[1]:id()
        end, nodes)

        if #found_data == 0 then
            log.error("Error in fetching " .. _type)
            return
        end

        return found_data[1]
    end,

    is_buffer_open = function()
        return module.private.current_bufnr ~= nil
    end,

    close_buffer = function()
        if not module.private.is_buffer_open() then
            return
        end

        -- Go back to previous mode
        local previous_mode = module.required["core.mode"].get_previous_mode()
        module.required["core.mode"].set_mode(previous_mode)

        module.private.data = {}
        module.private.extras = {}
        module.private.current_bufnr = nil
        module.private.display_namespace_nr = nil

        -- Closes the display
        vim.cmd(":bd")
    end,

    toggle_details = function()
        local data = module.private.get_by_var()
        local res = {}
        local offset = 0

        if not data or vim.tbl_isempty(data) then
            return
        end

        local surround = function(v)
            return "*" .. v .. "*"
        end

        if #data > 1 then
            for _, task in pairs(data) do
                if type(task) == "table" then
                    local state = (function()
                        if task.state == "done" then
                            return "- [x] "
                        elseif task.state == "undone" then
                            return "- [ ] "
                        else
                            return "- [*] "
                        end
                    end)()
                    local inserted = "  " .. state .. task.content
                    table.insert(res, inserted)
                end
            end
            -- For displaying projects, we assume that there is no data.state in it
        elseif not data.state then
            offset = 1
            local tasks = module.private.extras[data.uuid]
            if not tasks then
                table.insert(res, "  - /No tasks found for this project/")
            else
                for _, task in pairs(tasks) do
                    local state = (function()
                        if task.state == "done" then
                            return "- [x] "
                        elseif task.state == "undone" then
                            return "- [ ] "
                        elseif task.state == "pending" then
                            return "- [-] "
                        elseif task.state == "uncertain" then
                            return "- [?] "
                        elseif task.state == "urgent" then
                            return "- [!] "
                        elseif task.state == "recurring" then
                            return "- [+] "
                        elseif task.state == "onhold" then
                            return "- [=] "
                        elseif task.state == "cancelled" then
                            return "- [_] "
                        end
                    end)()
                    table.insert(res, "  " .. state .. task.content)
                end
            end
        else
            if data.project then
                table.insert(res, "-- Project: " .. surround(data.project))
            end
            if data.contexts then
                local contexts = vim.tbl_map(surround, data.contexts)
                table.insert(res, "-- Contexts: " .. table.concat(contexts, ","))
            end
            if data["waiting.for"] then
                local waiting_for = vim.tbl_map(surround, data["waiting.for"])
                table.insert(res, "-- Waiting for: " .. table.concat(waiting_for, ","))
            end
            if data["time.start"] then
                table.insert(res, "-- Starting the " .. surround(data["time.start"][1]))
            end
            if data["time.due"] then
                table.insert(res, "-- Due for " .. surround(data["time.due"][1]))
            end
        end

        data.detailed = data.detailed == true

        vim.api.nvim_buf_set_option(module.private.current_bufnr, "modifiable", true)
        local current_line = vim.api.nvim_win_get_cursor(0)[1]
        module.private.update_vars(res, current_line + 1, data.detailed)

        if data.detailed then
            vim.api.nvim_buf_set_lines(
                module.private.current_bufnr,
                current_line + offset,
                current_line + offset + #res,
                false,
                {}
            )
            data.detailed = false
        else
            vim.api.nvim_buf_set_lines(
                module.private.current_bufnr,
                current_line + offset,
                current_line + offset,
                false,
                res
            )
            data.detailed = true
        end

        module.private.data[current_line] = data
        vim.api.nvim_buf_set_option(module.private.current_bufnr, "modifiable", false)
    end,

    find_project = function(_tasks, node)
        if type(node) ~= "userdata" then
            return
        end

        for _node_id, tasks in pairs(_tasks) do
            if _node_id == node:id() then
                return tasks
            end
        end
    end,
}

return module
