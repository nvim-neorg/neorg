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
        public = {
            selection_builder_template = {
                selection = {},

                title = function(builder, title, highlight)
                    highlight = highlight or "TSTitle"

                    local renderable_title = title

                    if type(title) == "string" then
                        local split_title = vim.split(title, "\n")

                        renderable_title = {}

                        for i, title_line in ipairs(split_title) do
                            renderable_title[i] = { title_line, highlight }
                        end
                    end

                    table.insert(builder.selection, {
                        type = "title",

                        setup = function(self, renderer)
                            renderer:allocate_lines(vim.fn.len(renderable_title))
                        end,

                        render = function(self, renderer)
                            renderer:render(renderable_title)
                        end,

                        clean = function(self, renderer)
                            renderer:clean_line()
                        end,
                    })

                    return builder
                end,

                switch = function(builder, switch_name, configuration)
                    table.insert(builder.selection, {
                        type = "switch",
                        enabled = false,

                        setup = function(self, renderer)
                            renderer:allocate_lines(1)
                            return configuration.keys
                        end,

                        render = function(self, renderer)
                            renderer:render({
                                {
                                    switch_name,
                                    self.enabled and configuration.highlight_enabled or configuration.highlight_disabled,
                                },
                            })
                        end,

                        clean = function(self, renderer)
                            renderer:clean_line()
                        end,

                        trigger = function(self, key)
                            self.enabled = not self.enabled
                            if configuration.callback then
                                configuration.callback(key, self.enabled)
                            end
                        end,

                        done = function(self, data)
                            configuration.done(data)
                        end,
                    })

                    return builder
                end,

                blank = function(builder, count)
                    count = count or 1

                    table.insert(builder.selection, {
                        type = "newlines",

                        setup = function(self, renderer)
                            renderer:allocate_lines(count)
                        end,

                        render = function(self, renderer)
                            renderer:next_line(count)
                        end,

                        clean = function(self, renderer)
                            renderer:clean_line()
                        end,
                    })

                    return builder
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
                configuration = {},

                reset = function(self, buffer, configuration)
                    self.line = 0
                    self.buffer = buffer
                    self.configuration = vim.tbl_deep_extend("force", self.configuration, configuration or {})

                    if not configuration.namespace then
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

                render = function(self, args)
                    if self.line >= self.allocated_lines then
                        log.error("TODO Error")
                        return
                    end

                    vim.api.nvim_buf_set_extmark(self.buffer, self.configuration.namespace, self.line, 0, {
                        virt_text_pos = "overlay",
                        virt_text = args
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

            begin_selection = function(_)
                local template = vim.deepcopy(module.public.selection_builder_template)

                template.finish = function(builder, buffer, configuration)
                    local renderer = vim.deepcopy(module.public.renderer_template)

                    -- TODO: Override renderer configuration

                    renderer:reset(buffer, configuration)

                    for _, item in ipairs(builder.selection) do
                        local keys_to_bind = item:setup(renderer)

                        for _, key in ipairs(keys_to_bind or {}) do
                            log.warn("Setting key", key)
                            -- vim.api.nvim_buf_set_keymap(buffer, "n", key, "")
                        end
                    end

                    renderer:flush_lines()

                    for _, item in ipairs(builder.selection) do
                        item:render(renderer)
                    end
                end

                return template
            end,
        },
    }
end
