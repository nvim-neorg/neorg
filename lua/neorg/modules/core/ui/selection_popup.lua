--[[
    A UI module to allow the user to press different keys to select different actions
--]]

-- TODO: Add support for these functions
-- renderer.next().type
-- renderer.previous()
-- renderer.line()
--- renderer.line().length etc.
-- renderer.next_line(count or 1)
-- renderer.configuration(<type>)
-- renderer.render()
-- renderer.render_mode()
-- renderer.clean_line()
-- renderer.clean_range()
-- renderer.allocate_lines()
-- renderer.reset()

return function(module)
    return {
        private = {
            selection_popups = {},
        },

        public = {
            selection_builder_template = {
                selection = {},
                renderer = {},
                actions = {},
                data = {},

                attach_renderer = function(builder, renderer)
                    builder.renderer = renderer
                end,

                map_actions = function(builder, actions)
                    builder.actions = vim.tbl_deep_extend("force", builder.actions, actions)
                end,

                add = function(builder, item, configuration)
                    item.configuration = item.configuration
                            and vim.tbl_deep_extend(
                                "force",
                                item.configuration,
                                configuration or {}
                            )
                        or {}

                    table.insert(builder.selection, item)

                    return builder
                end,

                text = function(builder, title, highlight)
                    local renderable_title = title

                    if type(title) == "string" then
                        local split_title = vim.split(title, "\n")

                        renderable_title = {}

                        for i, title_line in ipairs(split_title) do
                            renderable_title[i] = { title_line, highlight }
                        end
                    end

                    return builder:add({
                        type = "text",

                        setup = function(_)
                            builder.renderer:allocate_lines(vim.fn.len(renderable_title))
                        end,

                        render = function(_)
                            builder.renderer:render(renderable_title)
                        end,

                        clean = function(_)
                            builder.renderer:clean_line()
                        end,
                    })
                end,

                title = function(builder, text, highlight)
                    return builder:add({
                        type = "title",
                        configuration = {
                            highlight = "TSTitle",
                        },

                        setup = function(_)
                            builder.renderer:allocate_lines(1)
                        end,

                        render = function(self)
                            builder.renderer:render({ { text, self.configuration.highlight } })
                        end,

                        clean = function(_)
                            builder.renderer:clean_line()
                        end,
                    }, {
                        highlight = highlight,
                    })
                end,

                switch = function(builder, switch_name, description, configuration)
                    return builder:add({
                        type = "switch",
                        configuration = {
                            enabled = false,
                            highlights = {
                                enabled = "TSAnnotation",
                                disabled = "TSComment",
                                delimiter = "TSMath",
                            },
                        },

                        setup = function(self)
                            builder.renderer:allocate_lines(1)
                            return {
                                keys = self.configuration.keys,
                            }
                        end,

                        render = function(self)
                            builder.renderer:render({
                                {
                                    switch_name,
                                    self.configuration.enabled
                                            and self.configuration.highlights.enabled
                                        or self.configuration.highlights.disabled,
                                },
                                {
                                    self.configuration.delimiter or builder.renderer.configuration.tab,
                                    self.configuration.highlights.delimiter or "Normal",
                                },
                                {
                                    description or "no description",
                                    self.configuration.highlights.description or "TSString",
                                },
                            })
                        end,

                        clean = function(_)
                            builder.renderer:clean_line()
                        end,

                        trigger = function(self, key)
                            self.configuration.enabled = not self.configuration.enabled
                            if self.configuration.callback then
                                self.configuration.callback(self.enabled, key)
                            end
                        end,

                        done = function(self, data)
                            if self.configuration.done then
                                self.configuration.done(data)
                            end
                        end,
                    }, configuration)
                end,

                blank = function(builder, count)
                    count = count or 1

                    return builder:add({
                        type = "newlines",

                        setup = function(_)
                            builder.renderer:allocate_lines(count)
                        end,

                        render = function(_)
                            builder.renderer:next_line(count)
                        end,

                        clean = function(_)
                            builder.renderer:clean_line()
                        end,
                    })
                end,

                --- Creates a clickable flag the user can press
                --- @param builder table #Equivalent to `self`
                --- @param flag string #The name of the flag. You want this to be a single character
                --- @param description string #The description of the flag
                --- @param configuration table #A configuration table
                --- @return table #The builder class
                flag = function(builder, flag, description, configuration)
                    return builder:add({
                        type = "flag",
                        configuration = {
                            highlights = {
                                key = "NeorgSelectionWindowKey",
                                description = "NeorgSelectionWindowKeyname",
                                delimiter = "NeorgSelectionWindowArrow",
                            },
                            delimiter = " -> ",
                            keys = {
                                flag,
                            },
                        },

                        setup = function(self)
                            builder.renderer:allocate_lines(1)
                            return {
                                keys = self.configuration.keys,
                            }
                        end,

                        render = function(self)
                            builder.renderer:render({
                                {
                                    flag,
                                    self.configuration.highlights.key,
                                },
                                {
                                    self.configuration.delimiter or builder.renderer.configuration.tab,
                                    self.configuration.highlights.delimiter or "Normal",
                                },
                                {
                                    description,
                                    self.configuration.highlights.description or "Normal",
                                },
                            })
                        end,

                        clean = function(self)
                            builder.renderer:clean_line()
                        end,

                        trigger = function(self, key)
                            return {
                                data = "a",
                                action = "close",
                            }
                        end,

                        done = function(self, data)
                            if self.configuration.done then
                                self.configuration.done(data)
                            end
                        end,
                    }, configuration)
                end,

                -- TODO: Move out of this scope
                trigger = function(self, id, key, line)
                    if self.selection[id] and self.selection[id].trigger then
                        local item = self.selection[id]
                        local return_data = item:trigger(key)
                        self.renderer.line = line
                        item:clean(self.renderer)
                        item:render(self.renderer)

                        if return_data then
                            if type(return_data.data) == "table" then
                                self.data = vim.tbl_deep_extend("force", self.data, return_data.data or {})
                            else
                                self.data = return_data.data
                            end

                            if self.actions[return_data.action] then
                                self.actions[return_data.action](self, id, key, line)
                            else
                                return_data.action(self, id, key, line)
                            end
                        end
                    end
                end,

                done = function(self)
                    for _, selection in ipairs(self.selection) do
                        if selection.done then
                            selection:done(self.data)
                        end
                    end
                end,

                finish = function(builder, buffer, configuration)
                    return {
                        configuration = configuration,
                        selection = builder.selection,
                        buffer = buffer,
                    }
                end,
            },

            renderer_template = {
                line = 0,
                buffer = 0,
                allocated_lines = 0,
                configuration = {
                    tab = "  ",
                },
                page_stack = { {} },
                page_no = 1,

                reset = function(self, buffer, configuration)
                    self.line = 0
                    self.buffer = buffer
                    self.configuration = vim.tbl_deep_extend("force", self.configuration, configuration or {})

                    if not configuration or not configuration.namespace then
                        self.configuration.namespace = vim.api.nvim_create_namespace(tostring(buffer))
                    end
                end,

                allocate_lines = function(self, count)
                    self.allocated_lines = self.allocated_lines + (count or 1)
                end,

                flush_lines = function(self)
                    local lines = vim.split(string.rep("\n", self.allocated_lines - 1), "\n")
                    vim.api.nvim_buf_set_lines(self.buffer, 0, self.allocated_lines, false, lines)
                end,

                clean_line = function(self)
                    table.remove(self.page_stack[self.page_no], self.line)
                    vim.api.nvim_buf_clear_namespace(self.buffer, self.configuration.namespace, self.line, self.line)
                end,

                render = function(self, args)
                    if self.line >= self.allocated_lines then
                        log.error("TODO Error")
                        return
                    end

                    vim.api.nvim_buf_set_extmark(self.buffer, self.configuration.namespace, self.line, 0, {
                        virt_text_pos = "overlay",
                        virt_text = args,
                    })

                    self.line = self.line + 1

                    self.page_stack[self.page_no][self.line] = args
                end,

                render_all = function(self, selection)
                    for _, item in ipairs(selection) do
                        item:render(self)
                    end
                end,

                -- In the future we would want to add support for several different objects on the same line
                -- but it's a bit harder with extmarks since they're not physical text.
                -- When we do implement that the user will be required to invoke this function
                -- to start a new line
                next_line = function(self, count)
                    count = count or 1

                    if self.line + count >= self.allocated_lines then
                        log.error("TODO Error")
                        return
                    end

                    self.line = self.line + count
                    self.column = 0
                end,

                push_page = function(self)
                    self.line = 0
                    self.allocated_lines = 0
                    self.page_no = self.page_no + 1
                    table.insert(self.page_stack, {})

                    vim.api.nvim_buf_clear_namespace(self.buffer, self.configuration.namespace, 0, -1)
                end,

                pop_page = function(self)
                    -- TODO: Extra error checking for page_no
                    table.remove(self.page_stack)
                    self.page_no = self.page_no - 1
                    self:render_all(self.page_stack[self.page_no])
                end,
            },

            get_selection_popup = function(name)
                return module.private.selection_popups[name] or {}
            end,

            remove_selection_popup = function(name)
                module.private.selection_popups[name] = nil
            end,

            begin_selection = function(name, global_configuration)
                local template = vim.deepcopy(module.public.selection_builder_template)

                if not module.private.selection_popups[name] then
                    template.finish = function(_, _, _)
                        log.error(
                            "Unable to create selection with name",
                            name,
                            "- such a selection popup window already exists! Make sure to close the other popup before trying to make a new one."
                        )
                    end
                end

                template:map_actions({
                    ["close"] = function(selection)
                        selection:done()
                        vim.cmd("bd!")
                    end,
                })

                template.add = function(builder, item, configuration)
                    item.configuration = item.configuration
                            and vim.tbl_deep_extend(
                                "force",
                                item.configuration,
                                global_configuration[item.type] or {},
                                configuration or {}
                            )
                        or {}

                    table.insert(builder.selection, item)

                    return builder
                end

                template.finish = function(builder, buffer, configuration)
                    configuration = configuration or {}

                    local renderer = vim.deepcopy(module.public.renderer_template)

                    renderer:reset(buffer, configuration.renderer)
                    template:attach_renderer(renderer)

                    for id, item in ipairs(builder.selection) do
                        local metadata = item:setup(renderer)

                        if metadata then
                            for _, key in ipairs(metadata.keys or {}) do
                                vim.api.nvim_buf_set_keymap(
                                    buffer,
                                    "n",
                                    key,
                                    string.format(
                                        ":lua neorg.modules.get_module('%s').get_selection_popup('%s'):trigger(%s, '%s', %s)<CR>",
                                        module.name,
                                        name,
                                        id,
                                        key,
                                        renderer.allocated_lines - 1
                                    ),
                                    {
                                        nowait = true,
                                        noremap = true,
                                        silent = true,
                                    }
                                )
                            end
                        end
                    end

                    renderer:flush_lines()

                    renderer:render_all(builder.selection)

                    vim.cmd(
                        string.format(
                            "autocmd BufLeave,BufDelete,BufUnload <buffer=%s> :bd! | :lua neorg.modules.get_module('%s').remove_selection_popup('%s')",
                            buffer,
                            module.name,
                            name
                        )
                    )
                end

                module.private.selection_popups[name] = template

                return template
            end,
        },
    }
end
