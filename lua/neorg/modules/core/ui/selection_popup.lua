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

                attach_renderer = function(self, renderer)
                    self.renderer = renderer
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

                    table.insert(builder.selection, {
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

                    return builder
                end,

                title = function(builder, text, highlight)
                    return builder:text(text, highlight or "TSTitle")
                end,

                switch = function(builder, switch_name, description, configuration)
                    table.insert(builder.selection, {
                        type = "switch",
                        enabled = false,

                        setup = function(_)
                            builder.renderer:allocate_lines(1)
                            return {
                                keys = configuration.keys,
                            }
                        end,

                        render = function(self)
                            builder.renderer:render({
                                {
                                    switch_name,
                                    self.enabled
                                            and configuration.highlights.enabled
                                        or configuration.highlights.disabled,
                                },
                                {
                                    configuration.delimiter or builder.renderer.configuration.tab,
                                    configuration.highlights.delimiter or "Normal",
                                },
                                {
                                    description or "no description",
                                    configuration.highlights.description or "TSString",
                                },
                            })
                        end,

                        clean = function(_)
                            builder.renderer:clean_line()
                        end,

                        trigger = function(self, key)
                            self.enabled = not self.enabled
                            if configuration.callback then
                                configuration.callback(self.enabled, key)
                            end
                        end,

                        done = function(_, data)
                            configuration.done(data)
                        end,
                    })

                    return builder
                end,

                blank = function(builder, count)
                    count = count or 1

                    table.insert(builder.selection, {
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

                    return builder
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

            begin_selection = function(name)
                if module.private.selection_popups[name] then
                    log.error("TODO: Error")
                    return {}
                end

                local template = vim.deepcopy(module.public.selection_builder_template)

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

                    for _, item in ipairs(builder.selection) do
                        item:render(renderer)
                    end

                    -- vim.cmd("autocmd BufLeave,BufDelete,BufUnload <buffer=" .. tostring(buffer) .. "> :lua vim.api.nvim_buf_delete(" .. tostring(buffer) .. ", { force = true });")
                end

                module.private.selection_popups[name] = template

                return template
            end,
        },
    }
end
