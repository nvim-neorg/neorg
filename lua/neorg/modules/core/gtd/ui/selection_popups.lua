local module = neorg.modules.extend("core.gtd.ui.selection_popups")

module.public = {
    show_views_popup = function()
        -- Generate views selection popup
        local buffer = module.required["core.ui"].create_split("Quick Actions")
        local selection = module.required["core.ui"].begin_selection(buffer):listener(
            "destroy",
            { "<Esc>" },
            function(self)
                self:destroy()
            end
        )

        selection:title("Views"):blank():concat(function(_selection)
            local configs = neorg.modules.get_module_config("core.gtd.base")
            return module.private.generate_display_flags(_selection, configs)
        end)

        module.private.display_messages()
    end,

    edit_task_at_cursor = function()
        local task_node = module.required["core.gtd.queries"].get_at_cursor("task")

        if not task_node then
            log.warn("No task at cursor position")
            return
        end

        local task = module.private.refetch_data_not_extracted(task_node, "task")
        module.public.edit_task(task)
    end,

    edit_task = function(task)
        -- Add metadatas to task node
        local task_extracted = module.required["core.gtd.queries"].add_metadata(
            { { task.node, task.bufnr } },
            "task",
            { same_node = true, extract = true }
        )[1]

        local modified = {}

        -- Create selection popup
        local buffer = module.required["core.ui"].create_split("Edit Task")
        local selection = module.required["core.ui"].begin_selection(buffer):listener(
            "destroy",
            { "<Esc>" },
            function(self)
                self:destroy()
            end
        )

        selection:title("Edit Task"):blank():text("Task: " .. task_extracted.content)
        if task_extracted.contexts then
            selection:text("Contexts: " .. table.concat(task_extracted.contexts, ", "))
        end
        if task_extracted["waiting.for"] then
            selection:text("Waiting for: " .. table.concat(task_extracted["waiting.for"], ", "))
        end
        if task_extracted["time.start"] then
            selection:text("Starting: " .. task_extracted["time.start"][1])
        end
        if task_extracted["time.due"] then
            selection:text("Due for: " .. task_extracted["time.due"][1])
        end

        selection
            :blank()
            :concat(function(_selection)
                return module.private.edit_prompt(
                    _selection,
                    "e",
                    "Edit content",
                    "content",
                    modified,
                    { prompt_title = "Edit Content" }
                )
            end)
            :blank()
            :text("General Metadatas")
            :concat(function(_selection)
                return module.private.edit(
                    _selection,
                    "c",
                    { edit = "Edit contexts", delete = "Delete contexts" },
                    modified,
                    "contexts",
                    task
                )
            end)
            :concat(function(_selection)
                return module.private.edit(
                    _selection,
                    "w",
                    { edit = "Edit waiting fors", delete = "Delete waiting fors" },
                    modified,
                    "waiting.for",
                    task
                )
            end)
            :blank()
            :text("Due/Start dates")
            :concat(function(_selection)
                return module.private.edit_date(_selection, "s", {
                    title = "Reschedule or remove start date",
                    edit = "Reschedule date",
                    delete = "Remove start date",
                }, modified, "time.start", task)
            end)
            :concat(function(_selection)
                return module.private.edit_date(_selection, "d", {
                    title = "Reschedule or remove due date",
                    edit = "Reschedule date",
                    delete = "Remove due date",
                }, modified, "time.due", task)
            end)

        selection:blank(2):flag("<CR>", "Validate", function()
            local data = selection:data()

            local edits = { "contexts", "waiting.for", "content", "time.start", "time.due" }

            for _, k in pairs(edits) do
                if data["delete_" .. k] then
                    task = module.required["core.gtd.queries"].delete(task, "task", k)
                else
                    task = module.required["core.gtd.queries"].modify(task, "task", k, modified[k], { tag = "#" .. k })
                end
            end

            vim.api.nvim_buf_call(task.bufnr, function()
                vim.cmd(" write ")
            end)
        end)

        module.private.display_messages()
    end,

    show_capture_popup = function()
        -- Generate views selection popup
        local buffer = module.required["core.ui"].create_split("Quick Actions")
        local selection = module.required["core.ui"].begin_selection(buffer):listener(
            "destroy",
            { "<Esc>" },
            function(self)
                self:destroy()
            end
        )

        selection:title("Capture"):blank():concat(module.private.capture_task)
        module.private.display_messages()
    end,
}

module.private = {
    display_messages = function()
        vim.cmd(string.format([[echom '%s']], "Press ESC to exit without saving"))
    end,
}

return module
