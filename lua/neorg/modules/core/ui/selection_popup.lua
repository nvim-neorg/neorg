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
                local self = module.private.callbacks[name]
                self.callbacks[({ type:gsub("<(.+)>", "%1") })[1]](self, key)
            end,

            --- Constructs a new selection
            --- @param buffer number #The number of the buffer the selection should attach to
            --- @return table #A selection object
            begin_selection = function(buffer)
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
                        vim.api.nvim_buf_set_option(buffer, "modifiable", true)

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

                        vim.api.nvim_buf_set_option(buffer, "modifiable", false)
                    end,

                    --- Resets the renderer by clearing the buffer and resetting
                    --- the render head
                    reset = function(self)
                        self.position = 0

                        vim.api.nvim_buf_set_option(buffer, "modifiable", true)

                        vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
                        vim.api.nvim_buf_set_lines(buffer, 0, -1, true, {})

                        vim.api.nvim_buf_set_option(buffer, "modifiable", false)
                    end,
                }

                local selection = {
                    callbacks = {},
                    page = 1,
                    pages = { {} },
                    opts = {},
                    keys = {},

                    --- Retrieves the options for a certain type
                    --- @param type string #The type of element to extract the options for
                    --- @return table #The options for said type or {}
                    options_for = function(self, type)
                        return self.opts[type] or {}
                    end,

                    --- Applies some new functions for the selection
                    --- @param tbl_of_functions table #A table of custom elements
                    --- @return table #`self`
                    apply = function(self, tbl_of_functions)
                        self = vim.tbl_deep_extend("force", self, tbl_of_functions)
                        return self
                    end,

                    --- Adds a new element to the current page
                    --- @param element function #A pointer to the function that created the item
                    --- @vararg any #The arguments that were used to construct the element
                    add = function(self, element, ...)
                        table.insert(self.pages[self.page], { self[element], { ... } })
                    end,

                    --- Attaches a key listener to the current buffer
                    --- @param type string #The type of element to attach to (can be "flag" or "switch" or something)
                    --- @param keys table #An array of keys to bind
                    --- @param func function #A callback to invoke whenever the key has been pressed
                    --- @param mode string #Optional, default "n": the mode to create the listener
                    --- @return table #`self`
                    add_listener = function(self, type, keys, func, mode)
                        -- Remove the <> characters from the string because that causes issues with Lua internally
                        type = ({ type:gsub("<(.+)>", "%1") })[1]

                        -- Extend ourself with the new callbacks. This allows us to give the callbacks value a "scope"
                        self = vim.tbl_deep_extend(
                            "force",
                            self,
                            { callbacks = {
                                [type] = func,
                            } }
                        )

                        -- Go through all keys that the user has bound a listener to and bind them!
                        for _, key in ipairs(keys) do
                            -- TODO: Docs
                            vim.api.nvim_buf_set_keymap(
                                buffer,
                                mode or "n",
                                key,
                                string.format(
                                    '<cmd>lua neorg.modules.get_module("%s").invoke_key_in_selection("%s", "%s", "%s")<CR>',
                                    module.name,
                                    name,
                                    ({ key:gsub("<(.+)>", "|%1|") })[1],
                                    type
                                ),
                                {
                                    silent = true,
                                    noremap = true,
                                    nowait = true,
                                }
                            )
                        end

                        return self
                    end,

                    --- Sets some options for the selection to take into account
                    --- @param opts table #A table of options
                    --- @return table #`self`
                    options = function(self, opts)
                        self.opts = vim.tbl_deep_extend("force", self.opts, opts)
                        return self
                    end,

                    --- Returns the data the selection holds
                    data = function()
                        return data
                    end,

                    --- Detaches the selection popup from the current buffer
                    --- Does *not* close the buffer
                    detach = function(self)
                        if not vim.api.nvim_buf_is_valid(buffer) then
                            return
                        end

                        renderer:reset()

                        self.page = 1
                        self.pages = {}

                        return data
                    end,

                    --- Destroys the selection popup and the buffer it occupied
                    destroy = function(self)
                        if not vim.api.nvim_buf_is_valid(buffer) then
                            return
                        end

                        renderer:reset()

                        self.page = 1
                        self.pages = {}

                        vim.api.nvim_buf_delete(buffer, { force = true })
                        return data
                    end,

                    --- Renders some text on the screen
                    --- @param text string #The text to display
                    --- @param highlight string #An optional highlight group to use (defaults to "Normal")
                    --- @return table #`self`
                    text = function(self, text, highlight)
                        local custom_highlight = self:options_for("text").highlight

                        self:add("text", text, highlight)

                        renderer:render({
                            text,
                            highlight or custom_highlight or "Normal",
                        })

                        return self
                    end,

                    --- Generates a title
                    --- @param text string #The text to display
                    --- @return table #`self`
                    title = function(self, text)
                        return self:text(text, "TSTitle")
                    end,

                    --- Simply enters a blank line
                    --- @param count number #An optional number of blank lines to apply
                    blank = function(self, count)
                        count = count or 1
                        renderer:render()

                        self:add("blank", count)

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
                                -- Whether to destroy the selection popup when this flag is pressed
                                destroy = true,
                            },
                            self:options_for( -- First merge the global options
                                "flag"
                            ),
                            type(callback) == "table" and callback or {} -- Then optionally merge the flag-specific options
                        )

                        self:add("flag", flag, description, callback)

                        -- Attach a listener to this flag
                        self = self:add_listener("flag_" .. flag, configuration.keys, function()
                            -- Invoke the user-defined callback
                            (function()
                                if type(callback) == "function" then
                                    return callback
                                else
                                    return callback and callback.callback or function() end
                                end
                            end)()(data)

                            -- Delete the selection before any action
                            -- We assume pressing a flag does quit the popup
                            if configuration.destroy then
                                self:destroy()
                            end
                        end)

                        module.private.callbacks[name] = self

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

                        return self
                    end,

                    --- Constructs a recursive (nested) flag
                    --- @param flag string #The flag key, should be one character only
                    --- @param description string #The description of the flag
                    --- @param callback function|table #The callback to invoke after the flag is entered
                    --- @return table #`self`
                    rflag = function(self, flag, description, callback)
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
                                    description = "NeorgSelectionWindowNestedKeyname",
                                    delimiter = "NeorgSelectionWindowArrow",
                                },
                                delimiter = " -> ",
                            },
                            self:options_for( -- First merge the global options
                                "rflag"
                            ),
                            type(callback) == "table" and callback or {} -- Then optionally merge the rflag-specific options
                        )

                        self:add("rflag", flag, description, callback)

                        -- Attach a listener to this flag
                        self = self:add_listener("flag_" .. flag, configuration.keys, function()
                            -- Create a new page to allow the renderer to start fresh
                            self:push_page();

                            -- Invoke the user-defined callback
                            (function()
                                if type(callback) == "function" then
                                    return callback()
                                elseif callback.callback then
                                    return callback.callback()
                                end
                            end)()
                        end)

                        module.private.callbacks[name] = self

                        -- Actually render the flag
                        renderer:render({
                            flag,
                            configuration.highlights.key,
                        }, {
                            configuration.delimiter,
                            configuration.highlights.delimiter,
                        }, {
                            "+" .. (description or "no description"),
                            configuration.highlights.description,
                        })

                        return self
                    end,

                    --- Pushes a new page onto the stack, clearing the buffer
                    --- and starting fresh
                    push_page = function(self)
                        self.page = self.page + 1
                        self.pages[self.page] = {}
                        renderer:reset()

                        for _, key in ipairs(vim.api.nvim_buf_get_keymap(buffer, "")) do
                            vim.api.nvim_buf_del_keymap(buffer, key.mode, key.lhs)
                        end
                    end,

                    --- Pops the page stack, effectively restoring the previous
                    --- state
                    pop_page = function(self)
                        -- If we have no pages left then there's nothing to pop
                        if self.page - 1 < 1 then
                            return
                        end

                        -- Delete the current page from existence
                        self.pages[self.page] = {}
                        -- Decrement the page counter
                        self.page = self.page - 1

                        -- Create a local copy of the previous (now current) page
                        -- We do this because when we start rendering objects
                        -- they'll start getting added onto the current page
                        -- and will start looping to infinity.
                        local page_copy = vim.deepcopy(self.pages[self.page])
                        -- Clear the current page;
                        self.pages[self.page] = {}

                        -- Reset the renderer to make sure we're starting afresh
                        renderer:reset()

                        -- Loop through all items in the page and recreate
                        -- each element
                        for _, item in ipairs(page_copy) do
                            item[1](self, unpack(item[2]))
                        end
                    end,

                    --- Creates a prompt inside the page
                    --- @param text string #The prompt text
                    --- @param callback table|function #The callback to invoke or configuration options for the prompt
                    prompt = function(self, text, callback)
                        -- Set up the configuration by properly merging everything
                        local configuration = vim.tbl_deep_extend(
                            "force",
                            {
                                text = text or "Input",
                                delimiter = " -> ",
                                -- Automatically destroys the popup when prompt is confirmed
                                destroy = true,
                            },

                            self:options_for( -- First merge the global options
                                "prompt"
                            ),
                            type(callback) == "table" and callback or {} -- Then optionally merge the flag-specific options
                        )

                        self:add("prompt", text)
                        self:blank()

                        -- Create prompt text
                        vim.fn.prompt_setprompt(buffer, configuration.text .. configuration.delimiter)

                        -- Create prompt
                        vim.api.nvim_buf_set_option(buffer, "modifiable", true)
                        local options = vim.api.nvim_buf_get_option(buffer, "buftype")
                        vim.api.nvim_buf_set_option(buffer, "buftype", "prompt")

                        -- Create a callback to be invoked on prompt confirmation
                        vim.fn.prompt_setcallback(buffer, function(content)
                            if content:len() > 0 then
                                -- Delete the selection before any action
                                -- We assume pressing a flag does quit the popup
                                if configuration.pop then
                                    -- Reset buftype options to previous ones
                                    vim.api.nvim_buf_set_option(buffer, "buftype", options)
                                    self:pop_page()
                                elseif configuration.destroy then
                                    self:destroy()
                                end

                                -- Invoke the user-defined callback
                                if type(callback) == "function" then
                                    callback(content)
                                else
                                    callback.callback(content)
                                end
                            end
                        end)

                        -- Jump to insert mode
                        vim.api.nvim_feedkeys("i", "t", false)

                        return self
                    end,
                }

                -- Attach the selection to a list of callbacks
                module.private.callbacks[name] = selection

                return selection
            end,
        },
    }
end
