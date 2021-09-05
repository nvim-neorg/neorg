return function (module)
    return {
        display_today_tasks = function (tasks)
            local name = "Today's Tasks"
            local res = {
                "* " .. name,
                ""
            }
            for _, task in ipairs(tasks) do
                table.insert(res, "- " .. task)
            end
            local buf = module.required["core.ui"].create_norg_buffer(name, "vsplitr")
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, res)
        end,

        display_waiting_for = function (tasks)
            local name = "Waiting For Tasks"
            local res = {
                "* " .. name,
                "",
            }

            for waiting_for_name, waiting_for_tasks in pairs(tasks) do
                table.insert(res, "** " .. waiting_for_name)
                for _,t in pairs(waiting_for_tasks) do
                    table.insert(res, "- " .. t)
                end
                table.insert(res, "")
            end

            local buf = module.required["core.ui"].create_norg_buffer(name, "vsplitr")
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, res)
        end,

        display_contexts = function (tasks)
            local name = "Contexts"
            local res = {
                "* " .. name,
                ""
            }

            for context, context_tasks in pairs(tasks) do
                table.insert(res, "** " .. context)
                for _,t in pairs(context_tasks) do
                    table.insert(res, "- " .. t)
                end
                table.insert(res, "")
            end

            local buf = module.required["core.ui"].create_norg_buffer(name, "vsplitr")
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, res)
        end
    }
end
