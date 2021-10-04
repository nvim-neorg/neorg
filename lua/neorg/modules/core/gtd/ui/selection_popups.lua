return function(module)
    return {
        public = {
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
                if task_extracted["waiting.for"] then
                    selection = selection:text("Waiting for: " .. table.concat(task_extracted["waiting.for"], ", "))
                end
                if task_extracted["time.start"] then
                    selection = selection:text("Starting: " .. task_extracted["time.start"][1])
                end
                if task_extracted["time.due"] then
                    selection = selection:text("Due for: " .. task_extracted["time.due"][1])
                end

                selection = selection
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

                selection = selection:blank():blank():flag("<CR>", "Validate", function()
                    local data = selection:data()

                    local edits = { "contexts", "waiting.for", "content", "time.start", "time.due" }

                    for _, k in pairs(edits) do
                        if data["delete_" .. k] then
                            task = module.required["core.gtd.queries"].delete(task, "task", k)
                        else
                            task = module.required["core.gtd.queries"].modify(
                                task,
                                "task",
                                k,
                                modified[k],
                                { tag = "$" .. k }
                            )
                        end
                    end

                    vim.api.nvim_buf_call(task.bufnr, function()
                        vim.cmd(" write ")
                    end)
                end)
            end,
        },
    }
end
