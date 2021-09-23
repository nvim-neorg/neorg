return function(module)
    return {
        private = {
            edit = function (selection, flag, text, modified, opts)
                opts = opts or {}
                local prompt_title = opts.prompt_title or 'Edit'

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
                                        modified.content = vim.split(t, " ", true)
                                    else
                                        modified.content = t
                                    end
                                end
                            end,
                            pop = true,
                        })
                    end,
                })
                return selection
            end
        },
    }
end
