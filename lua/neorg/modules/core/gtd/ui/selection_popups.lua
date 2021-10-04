local module = neorg.modules.extend("core.gtd.ui.selection_popups")

module.public = {
    show_quick_actions = function(configs)
        -- Generate quick_actions selection popup
        local buffer = module.required["core.ui"].create_split("Quick Actions")
        local selection = module.required["core.ui"].begin_selection(buffer):listener(
            "destroy",
            { "<Esc>" },
            function(self)
                self:destroy()
            end
        )

        selection = selection
            :title("Quick Actions")
            :blank()
            :text("Capture")
            :concat(module.private.add_to_inbox)
            :blank()
            :text("Displays")
            :concat(function(_selection)
                return module.private.generate_display_flags(_selection, configs)
            end)

        selection = selection:blank():flag("x", "Debug Mode", function()
            local nodes = module.required["core.gtd.queries"].get("tasks", { filename = "index.norg" })
            module.required["core.gtd.queries"].generate_missing_uuids(nodes, "tasks")
        end)
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
        local selection = module.required["core.ui"].begin_selection(buffer)
        selection = selection:listener("destroy", { "<Esc>" }, function(self)
            self:destroy()
        end)

        -- TODO: Make the content prettier
        selection = selection:title("Edit Task"):blank():text("Task: " .. task_extracted.content)
        if task_extracted.contexts then
            selection = selection:text("Contexts: " .. table.concat(task_extracted.contexts, ", "))
        end
        if task_extracted.waiting_for then
            selection = selection:text("Waiting for: " .. table.concat(task_extracted.waiting_for, ", "))
        end
        if task_extracted.start then
            selection = selection:text("Starting: " .. task_extracted.start[1])
        end
        if task_extracted.due then
            selection = selection:text("Due for: " .. task_extracted.due[1])
        end
        selection = selection
            :blank()
            :concat(function(_selection)
                return module.private.edit(
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
            :rflag("c", "Edit contexts", function()
                selection = selection
                    :text("Edit contexts")
                    :blank()
                    :concat(function(_selection)
                        selection = module.private.edit(
                            _selection,
                            "e",
                            "Edit contexts",
                            "contexts",
                            modified,
                            { prompt_title = "Edit Contexts", pop_page = true, multiple_texts = true }
                        )
                        return selection
                    end)

                    :flag("d", "Delete contexts", {
                        destroy = false,
                        callback = function()
                            if not task["contexts"] then
                                log.warn("No context to delete")
                            else
                                selection:set_data("delete_contexts", true)
                            end
                            selection:pop_page()
                        end,
                    })

                return selection
            end)

            :rflag("w", "Edit waiting fors", function()
                -- content
            end)
            :blank()
            :text("Due/Start dates")
            :rflag("s", "Reschedule or remove start date", function()
                -- content
            end)
            :rflag("d", "Reschedule or remove due date", function()
                -- content
            end)

        selection = selection:blank():blank():flag("<CR>", "Validate", function()
            local data = selection:data()

            task = module.required["core.gtd.queries"].modify(task, "task", "content", modified.content)

            if data.delete_contexts then
                task = module.required["core.gtd.queries"].delete(task, "task", "contexts")
            else
                task = module.required["core.gtd.queries"].modify(
                    task,
                    "task",
                    "contexts",
                    modified.contexts,
                    { tag = "$contexts" }
                )
            end

            vim.api.nvim_buf_call(task.bufnr, function()
                vim.cmd(" write ")
            end)
        end)
    end,
}

return module
