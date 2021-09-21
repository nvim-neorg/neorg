return function(module)
    return {
        private = {
            edit_content = function(selection, modified)
                selection = selection:flag("e", "Edit Content", {
                    destroy = false,
                    callback = function()
                        selection:push_page()
                        selection
                            :title("Edit Content")
                            :blank()
                            :prompt("New content", { -- TODO: add already created content in prompt
                                callback = function(text)
                                    if #text > 0 then
                                        modified.content = text
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
