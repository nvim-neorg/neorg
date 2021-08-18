return function (module)
    return {

        -- @Summary Add user task to inbox
        -- @Description Show prompt asking for user input and append the task to the inbox
        add_task_to_inbox = function()
            -- Define a callback (for prompt) to add the task to the inbox list
            local cb = function(text, actions)
                local results = {}
                -- Add found_syntaxes to results and check for uniqueness
                for name, syntax in pairs(module.private.syntax) do
                    results[name] = module.private.find_syntaxes(text, syntax)
                    if syntax.unique == true and #results[name] > 1 then
                        log.error("Please specify max 1 " .. name)
                        actions.close()
                        return
                    end
                end

                -- Format each found syntax and rearrange priority
                local output_table = {}
                for syntax, content in pairs(results) do
                    if #content ~= 0 then
                        local priority = module.private.syntax[syntax].priority
                        local formatted_content = module.private.output_formatter(module.private.syntax[syntax], content)
                        table.insert(output_table, priority, formatted_content)
                    end
                end

                -- Output each syntax node
                local output = ""
                for _, value in pairs(output_table) do
                    output = output .. value
                end

                module.private.add_to_list(module.config.public.default_lists.inbox, output)
                log.info("Added task to " .. module.private.workspace_full_path)
                actions.close()
            end

            -- Show prompt asking for input
            module.required["core.ui"].create_prompt("INBOX_WINDOW", "Add to inbox.norg > ", cb, {
                center_x = true,
                center_y = true,
            }, {
                    width = 60,
                    height = 1,
                    row = 3,
                    col = 0,
                })
        end,
    }
end
