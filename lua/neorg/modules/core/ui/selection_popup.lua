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

                attach_renderer = function(builder, renderer)
                    builder.renderer = renderer
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
                    return builder:text(text, highlight or "TSTitle")
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
                            self.configuration.done(data)
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

                trigger = function(self, id, key, line)
                    if self.selection[id] and self.selection[id].trigger then
                        local item = self.selection[id]
                        item:trigger(key)
                        self.renderer.line = line
                        item:clean(self.renderer)
                        item:render(self.renderer)
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
            },

            get_selection_popup = function(name)
                return module.private.selection_popups[name] or {}
            end,

            remove_selection_popup = function(name)
                module.private.selection_popups[name] = nil
            end,

            begin_selection = function(name)
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

                template.finish = function(builder, buffer, configuration)
                    configuration = configuration or {}

                    local renderer = vim.deepcopy(module.public.renderer_template)

                    renderer:reset(buffer, configuration.renderer)
                    template:attach_renderer(renderer)

                    for id, item in ipairs(builder.selection) do
                        item.configuration = item.configuration
                                and vim.tbl_deep_extend(
                                    "force",
                                    item.configuration,
                                    configuration[item.type] or {}
                                )
                            or {}

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

                    for _, item in ipairs(builder.selection) do
                        item:render(renderer)
                    end

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
