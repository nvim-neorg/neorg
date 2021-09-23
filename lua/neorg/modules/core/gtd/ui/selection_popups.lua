return function(module)
    return {
        -- FIXME: Still errors in multiple flags selection
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

                selection
                    :title("Quick Actions")
                    :blank()
                    :text("Capture")
                    :concat(module.private.add_to_inbox)
                    :blank()
                    :text("Displays")
                    :concat(function(_selection)
                        return module.private.generate_display_flags(_selection, configs)
                    end)
            end,

            edit_task = function(task)
                -- Add metadatas to task node
                local task_extracted = module.required["core.gtd.queries"].add_metadata({ task }, "task")[1]
                local task_not_extracted = module.required["core.gtd.queries"].add_metadata(
                    { task },
                    "task",
                    { extract = false }
                )[1]

                local modified = {}

                -- Create selection popup
                local buffer = module.required["core.ui"].create_split("Edit Task")
                local selection = module.required["core.ui"].begin_selection(buffer)
                selection = selection:listener("destroy", { "<Esc>" }, function(self)
                    self:destroy()
                end)

                -- TODO: Make the content prettier
                selection = selection:title("Edit Task")
                    :blank()
                    :concat(function(_selection)
                        return module.private.edit(_selection, "e", "Edit content: " .. task_extracted.content, modified, { prompt_title = "Edit Content"})
                    end)
                --if task_extracted.contexts then
                    --selection = selection:text("- Contexts: " .. table.concat(task_extracted.contexts, ","))
                --end
                --if task_extracted.waiting_for then
                    --selection = selection:text("- Waiting For: " .. table.concat(task_extracted.waiting_for, ","))
                --end
                --if task_extracted.start then
                    --selection = selection:text("- Start: " .. task_extracted.start)
                --end
                --if task_extracted.due then
                    --selection = selection:text("- Due: " .. task_extracted.due)
                --end

                selection = selection
                    :blank()
                    :blank()
                    :flag("<CR>", "Validate", function()
                        if modified.content then
                            module.required["core.gtd.queries"].modify(task_not_extracted, "content", modified.content)
                        end
                    end)
            end,
        },
    }
end
