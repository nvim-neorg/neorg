local module = neorg.modules.extend("core.gtd.ui.edit_popup_helpers")

module.private = {
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
    edit_prompt = function(selection, flag, text, key, modified, opts)
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

    edit = function(selection, flag, texts, modified, key, task)
        selection = selection:rflag(flag, texts.edit, function()
            selection = selection
                :text(texts.edit)
                :blank()
                :concat(function(_selection)
                    selection = module.private.edit_prompt(
                        _selection,
                        "e",
                        texts.edit,
                        key,
                        modified,
                        { prompt_title = texts.edit, pop_page = true, multiple_texts = true }
                    )
                    return selection
                end)

                :flag("d", texts.delete, {
                    destroy = false,
                    callback = function()
                        if not task[key] then
                            log.warn("Nothing to delete")
                        else
                            selection:set_data("delete_" .. key, true)
                        end
                        selection:pop_page()
                    end,
                })

            return selection
        end)
        return selection
    end,

    edit_date = function(selection, flag, texts, modified, key, task)
        selection = selection:rflag(flag, texts.title, function()
            selection = selection
                :text(texts.title)
                :blank()
                :flag("t", "Reschedule for tomorrow", {
                    destroy = false,
                    callback = function()
                        modified[key] = module.required["core.gtd.queries"].date_converter("tomorrow")
                        selection:pop_page()
                    end,
                })
                :flag("c", "Custom", {
                    destroy = false,
                    callback = function()
                        selection:push_page()
                        selection
                            :title("Custom Date")
                            :text("Allowed date format: today, tomorrow, Xw, Xd, Xm, Xy (X is a number)")
                            :text("You can even use 'mon', 'tue', 'wed' ... for the next weekday date")
                            :blank()
                            :prompt("Enter date", {
                                callback = function(text)
                                    if #text > 0 then
                                        modified[key] = module.required["core.gtd.queries"].date_converter(text)
                                        if not modified[key] then
                                            log.error("Date format not recognized, please try again...")
                                        else
                                            selection:pop_page()
                                        end
                                    end
                                end,
                                pop = true,
                            })
                    end,
                })
                :blank()
                :flag("d", texts.delete, {
                    destroy = false,
                    callback = function()
                        if not task[key] then
                            log.warn("Nothing to delete")
                        else
                            selection:set_data("delete_" .. key, true)
                        end
                        selection:pop_page()
                    end,
                })
        end)
        return selection
    end,
}

return module
