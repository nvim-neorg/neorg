return function(module)
    return {
        private = {
            --- Edit content from `key`.
            --- @param selection table #The popup selection
            --- @param flag string #The flag to use for calling the prompt
            --- @param text string #The text to show for the flag
            --- @param key string #The key to modify
            --- @param modified table #The table to insert modified text
            --- @param opts table
            ---   - opts.multiple_texts (bool):     if true, will split the modified content and convert into a list
            ---   - opts.pop_page (bool):           if true, will pop the page a second time
            ---   - opts.prompt_title (string):     provide custom prompt title. Else defaults to "Edit"
            --- @return table #The selection
            edit = function(selection, flag, text, key, modified, opts)
                opts = opts or {}
                local prompt_title = opts.prompt_title or "Edit"

                selection = selection:flag(flag, text, {
                    destroy = false,
                    callback = function()
                        selection:push_page()
                        selection
                            :title(prompt_title)
                            :blank()
                            :prompt(prompt_title, { -- TODO: add already created content in prompt
                                callback = function(t)
                                    if #t > 0 then
                                        if opts.multiple_texts then
                                            modified[key] = vim.split(t, " ", true)
                                        else
                                            modified[key] = t
                                        end
                                    end
                                    -- We don't delete the key at CR because we just modified it
                                    selection:set_data("delete_contexts", false)

                                    if opts.pop_page then
                                        selection:pop_page()
                                    end
                                end,
                                pop = true,
                            })
                    end,
                })
                return selection
            end,
        },
    }
end
