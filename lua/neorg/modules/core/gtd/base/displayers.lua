return function(module)
    return {
        display_today_tasks = function(tasks)
            local name = "Today's Tasks"
            local res = {
                "* " .. name,
                "",
            }
            local today_task = function(task)
                if not task.contexts then
                    return false
                end
                return vim.tbl_contains(task.contexts, "today")
            end

            local today_tasks = vim.tbl_filter(today_task, tasks)

            for _, t in pairs(today_tasks) do
                local content = "- " .. t.content
                table.insert(res, content)
            end

            local buf = module.required["core.ui"].create_norg_buffer(name, "vsplitr")
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, res)
            vim.api.nvim_buf_set_option(buf, "modifiable", false)
        end,

        display_waiting_for = function(tasks)
            local name = "Waiting For Tasks"
            local res = {
                "* " .. name,
                "",
            }
            local waiting_for_tasks = module.private.sort_by("waiting_for", tasks)
            waiting_for_tasks["_"] = nil

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
        ---   - opts.exclude (table):   exclude all specified contexts from the view
        display_contexts = function(tasks, opts)
            opts = opts or {}
            local name = "Contexts"
            local res = {
                "* " .. name,
                "",
            }

            local contexts_tasks = module.private.sort_by("contexts", tasks)

            if opts.exclude then
                for _, c in pairs(opts.exclude) do
                    contexts_tasks[c] = nil
                end
            end

            for context, c_tasks in pairs(contexts_tasks) do
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
    }
end
