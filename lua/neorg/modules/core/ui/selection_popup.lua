--[[
A UI module to allow the user to press different keys to select different actions
--]]

return function(module)
    return {
        public = {
            begin_selection = function(buffer)
                -- Used for storing options set by the user
                local options = {}

                local data = {}

                -- Create a namespace from the buffer name
                local namespace = vim.api.nvim_create_namespace(vim.api.nvim_buf_get_name(buffer))

                --- Simply renders things using extmarks
                local renderer = {
                    position = 0,

                    --- Renders something in the buffer
                    --- @vararg table #A vararg of { text, highlight } tables
                    render = function(self, ...)
                        -- Don't render if we're on the first line
                        -- because buffers always open with one line available
                        -- anyway
                        if self.position > 0 then
                            vim.api.nvim_buf_set_lines(buffer, -1, -1, false, { "" })
                        end

                        vim.api.nvim_buf_set_extmark(buffer, namespace, self.position, 0, {
                            virt_text_pos = "overlay",
                            virt_text = { ... },
                        })

                        -- Track which line we're on
                        self.position = self.position + 1
                    end,
                }

                local selection = {
                    --- Retrieves the options for a certain type
                    --- @param type string #The type of element to extract the options for
                    --- @return table #The options for said type or {}
                    options_for = function(_, type)
                        return options[type] or {}
                    end,

                    --- Applies some new functions for the selection
                    --- @param tbl_of_functions table #A table of custom elements
                    --- @return table #`self`
                    apply = function(self, tbl_of_functions)
                        self = vim.tbl_deep_extend("force", self, tbl_of_functions)
                        return self
                    end,

                    --- Sets some options for the selection to take into account
                    --- @param opts table #A table of options
                    --- @return table #`self`
                    options = function(self, opts)
                        options = vim.tbl_deep_extend("force", options, opts)
                        return self
                    end,

                    --- Renders some text on the screen
                    --- @param text string #The text to display
                    --- @param highlight string #An optional highlight group to use (defaults to "Normal")
                    --- @return table #`self`
                    text = function(self, text, highlight)
                        local custom_highlight = self:options_for("text").highlight

                        renderer:render({
                            text, highlight or custom_highlight or "Normal"
                        })

                        return self
                    end,
                }

                return selection
            end
        }
    }
end
