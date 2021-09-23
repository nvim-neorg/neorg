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
                        return module.private.edit(_selection, "e", "Edit content: " .. task_extracted.content, "content", modified, { prompt_title = "Edit Content"})
                    end)
                    :concat(function(_selection)
                        local text = (function ()
                           if task_extracted.contexts then
                              return table.concat(task_extracted.contexts, ", ")
                            else return "No contexts"
                           end
                        end)()
                        return module.private.edit(_selection, "c", "Edit contexts: " .. text, "contexts", modified, { prompt_title = "Edit contexts", multiple_texts = true})
                    end)

                selection = selection
                    :blank()
                    :blank()
                    :flag("<CR>", "Validate", function()
                        module.required["core.gtd.queries"].modify(task_not_extracted, "content", modified.content)
                        module.required["core.gtd.queries"].modify(task_not_extracted, "contexts", modified.contexts, { force_create = true, tag = "$contexts"})
                        vim.api.nvim_buf_call(task_not_extracted.bufnr, function () vim.cmd(" write ") end)
                    end)
            end,
        },
    }
end
