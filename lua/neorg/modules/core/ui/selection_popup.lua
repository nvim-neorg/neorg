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

                        if not vim.tbl_isempty({ ... }) then
                            vim.api.nvim_buf_set_extmark(buffer, namespace, self.position, 0, {
                                virt_text_pos = "overlay",
                                virt_text = { ... },
                            })
                        end

                        -- Track which line we're on
                        self.position = self.position + 1
                    end,

                    --- Resets the renderer by clearing the buffer and resetting
                    --- the render head
                    reset = function(self)
                        self.position = 0
                        vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
                        vim.api.nvim_buf_set_lines(buffer, 0, -1, true, {})
                    end,
                }

                local selection = {
                    --- Retrieves the options for a certain type
                    --- @param type string #The type of element to extract the options for
                    --- @return table #The options for said type or {}
                    options_for = function(type)
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

                    --- Returns the data the selection holds
                    data = function()
                        return data
                    end,

                    --- Detaches the selection popup from the current buffer
                    --- Does *not* close the buffer
                    detach = function()
                        renderer:reset()
                        return data
                    end,

                    --- Destroys the selection popup and the buffer it occupied
                    destroy = function()
                        renderer:reset()
                        vim.api.nvim_buf_delete(buffer, { force = true })
                        return data
                    end,

                    --- Renders some text on the screen
                    --- @param text string #The text to display
                    --- @param highlight string #An optional highlight group to use (defaults to "Normal")
                    --- @return table #`self`
                    text = function(self, text, highlight)
                        local custom_highlight = self.options_for("text").highlight

                        renderer:render({
                            text, highlight or custom_highlight or "Normal"
                        })

                        return self
                    end,

                    --- Simply enters a blank line
                    --- @param count number #An optional number of blank lines to apply
                    blank = function(self, count)
                        count = count or 1
                        renderer:render()

                        if count <= 1 then
                            return self
                        else
                            return self:blank(count - 1)
                        end
                    end,

                    -- TODO
                    flag = function(self, flag, description, callback)
                        local configuration = vim.tbl_deep_extend("force", {
                            keys = {
                                flag
                            }
                        }, self.options_for("flag"), type(callback) == "table" and callback or {})


                    end,
                }

                return selection
            end
        }
    }
end
