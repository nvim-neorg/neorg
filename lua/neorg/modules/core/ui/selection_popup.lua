--[[
    A UI module to allow the user to press different keys to select different actions
--]]

return function(module)
    return {
        private = {
            -- Stores all currently open selection popups
            callbacks = {},
        },

        public = {
            --- Invokes a key callback in a certain selection
            --- @param name string #The name of the selection
            --- @param key string #The key that was pressed
            --- @param type string #The type of element the callback belongs to (could be "flag", "switch" etc.)
            invoke_key_in_selection = function(name, key, type)
                module.private.callbacks[name].callbacks[type](key)
            end,

            --- Constructs a new selection
            --- @param buffer number #The number of the buffer the selection should attach to
            --- @return table #A selection object
            begin_selection = function(buffer)
                -- Used for storing options set by the user
                local options = {}

                -- Data that is gathered up over the lifetime of the selection popup
                local data = {}

                -- Get the name of the buffer we are about to attach to
                local name = vim.api.nvim_buf_get_name(buffer)

                -- Create a namespace from the buffer name
                local namespace = vim.api.nvim_create_namespace(name)

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
                    callbacks = {},

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

                    --- Attaches a key listener to the current buffer
                    --- @param type string #The type of element to attach to (can be "flag" or "switch" or something)
                    --- @param keys table #An array of keys to bind
                    --- @param func function #A callback to invoke whenever the key has been pressed
                    add_listener = function(self, type, keys, func)
                        self.callbacks[type] = func

                        for _, key in ipairs(keys) do
                            vim.api.nvim_buf_set_keymap(
                                buffer,
                                "n",
                                key,
                                string.format(
                                    "<cmd>lua neorg.modules.get_module('%s').invoke_key_in_selection('%s', '%s', '%s')<CR>",
                                    module.name,
                                    name,
                                    key,
                                    type
                                ),
                                {
                                    silent = true,
                                    noremap = true,
                                    nowait = true,
                                }
                            )
                        end
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
                            text,
                            highlight or custom_highlight or "Normal",
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

                    --- Creates a pressable flag
                    --- @param flag string #The flag. These should be a single character
                    --- @param description string #The description for the flag
                    --- @param callback table|function #The callback to invoke or configuration options for the flag
                    flag = function(self, flag, description, callback)
                        -- Set up the configuration by properly merging everything
                        local configuration = vim.tbl_deep_extend(
                            "force",
                            {
                                keys = {
                                    flag,
                                },
                                highlights = {
                                    -- TODO: Change highlight group names
                                    key = "NeorgSelectionWindowKey",
                                    description = "NeorgSelectionWindowKeyname",
                                    delimiter = "NeorgSelectionWindowArrow",
                                },
                                delimiter = " -> ",
                            },
                            self.options_for( -- First merge the global options
                                "flag"
                            ),
                            type(callback) == "table" and callback or {} -- Then optionally merge the flag-specific options
                        )

                        -- Attach a listener to this flag
                        self:add_listener("flag", configuration.keys, function()
                            -- Invoke the user-defined callback
                            (function()
                                if type(callback) == "function" then
                                    return callback
                                else
                                    return callback.callback or function() end
                                end
                            end)()()

                            -- Delete the selection afterwards too
                            self:destroy()
                        end)

                        -- Actually render the flag
                        renderer:render({
                            flag,
                            configuration.highlights.key,
                        }, {
                            configuration.delimiter,
                            configuration.highlights.delimiter,
                        }, {
                            description or "no description",
                            configuration.highlights.description,
                        })
                    end,
                }

                -- Attach the selection to a list of callbacks
                module.private.callbacks[name] = selection

                return selection
            end,
        },
    }
end
