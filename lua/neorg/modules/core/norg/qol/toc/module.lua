--[[
    file: TOC
    title: Table of Contents within Neorg
    summary: Generates a table of contents for a given Neorg buffer.
--]]

local module = neorg.modules.create("core.norg.qol.toc")

module.setup = function()
    return {
        requires = { "core.integrations.treesitter", "core.ui" },
    }
end

module.load = function()
    neorg.modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            toc = {
                name = "core.norg.qol.toc",
                max_args = 1,
                condition = "norg",
                complete = {
                    { "left", "right" },
                },
            },
        })
    end)
end

module.public = {
    parse_toc_macro = function(buffer)
        local name, toc_name

        local success = module.required["core.integrations.treesitter"].execute_query(
            [[
        (infirm_tag
            (tag_name) @name
            (tag_parameters)? @parameters)
        ]],
            function(query, id, node)
                local capture_name = query.captures[id]

                if capture_name == "name" then
                    name = module.required["core.integrations.treesitter"].get_node_text(node, buffer)
                elseif capture_name == "parameters" then
                    toc_name = module.required["core.integrations.treesitter"].get_node_text(node, buffer)
                end
            end,
            buffer
        )

        if not success then
            return
        end

        return {
            name = name,
            parameters = toc_name,
        }
    end,

    update_toc = function(namespace, toc_title, original_buffer, original_window, ui_buffer, ui_window)
        vim.api.nvim_buf_clear_namespace(original_buffer, namespace, 0, -1)

        vim.api.nvim_buf_set_lines(ui_buffer, 0, -1, true, toc_title)
        local offset = vim.api.nvim_buf_line_count(ui_buffer)

        local prefix, title
        local extmarks = {}

        local success = module.required["core.integrations.treesitter"].execute_query(
            [[
            (_
              .
              (_) @prefix
              .
              title: (paragraph_segment) @title)
            ]],
            vim.schedule_wrap(function(query, id, node)
                local capture = query.captures[id]

                if capture == "prefix" then
                    if node:type():match("_prefix$") then
                        prefix = node
                    else
                        prefix = nil
                    end
                elseif capture == "title" then
                    title = node
                end

                if prefix and title then
                    local _, column = title:start()
                    table.insert(
                        extmarks,
                        vim.api.nvim_buf_set_extmark(original_buffer, namespace, (prefix:start()), column, {})
                    )

                    local prefix_text =
                        module.required["core.integrations.treesitter"].get_node_text(prefix, original_buffer)
                    local title_text =
                        module.required["core.integrations.treesitter"].get_node_text(title, original_buffer)

                    if prefix_text:sub(1, 1) ~= "*" and prefix_text:match("^%W%W") then
                        prefix_text = table.concat({ prefix_text:sub(1, 1), " " })
                    end

                    vim.api.nvim_buf_set_lines(
                        ui_buffer,
                        -1,
                        -1,
                        true,
                        { table.concat({ "{", prefix_text, title_text, "}" }) }
                    )

                    prefix, title = nil, nil
                end
            end),
            original_buffer
        )

        if not success then
            return
        end

        vim.api.nvim_buf_set_keymap(ui_buffer, "n", "<CR>", "", {
            callback = function()
                local curline = vim.api.nvim_win_get_cursor(ui_window)[1]
                local extmark_lookup = extmarks[curline - offset]

                if not extmark_lookup then
                    return
                end

                local location = vim.api.nvim_buf_get_extmark_by_id(original_buffer, namespace, extmark_lookup, {})

                vim.api.nvim_set_current_win(original_window)
                vim.api.nvim_set_current_buf(original_buffer)
                vim.api.nvim_win_set_cursor(original_window, { location[1] + 1, location[2] })
            end,
        })
    end,
}

module.on_event = function(event)
    if event.split_type[2] == module.name then
        local toc = module.public.parse_toc_macro(event.buffer)

        local toc_title = toc and toc.parameters and vim.split(toc.parameters, "\n") or { "Table of Contents" }

        local namespace = vim.api.nvim_create_namespace("neorg/toc")
        local buffer, window =
            module.required["core.ui"].create_vsplit("toc", { ft = "norg" }, (event.content[1] or "left") == "left")

        vim.api.nvim_win_set_option(window, "scrolloff", 999)
        module.public.update_toc(namespace, toc_title, event.buffer, event.window, buffer, window)

        vim.api.nvim_buf_set_keymap(buffer, "n", "q", "", {
            callback = function()
                vim.api.nvim_buf_delete(buffer, { force = true })
            end,
        })

        vim.api.nvim_create_autocmd("WinClosed", {
            buffer = buffer,
            once = true,
            callback = function()
                vim.api.nvim_buf_delete(buffer, { force = true })
            end,
        })

        do
            local previous_buffer, previous_window = event.buffer, event.window

            vim.api.nvim_create_autocmd("BufWritePost", {
                pattern = "*.norg",
                callback = function()
                    if not vim.api.nvim_buf_is_valid(buffer) or not vim.api.nvim_buf_is_loaded(buffer) then
                        return true
                    end

                    toc = module.public.parse_toc_macro(previous_buffer)
                    toc_title = toc and toc.parameters and vim.split(toc.parameters, "\n") or { "Table of Contents" }
                    module.public.update_toc(namespace, toc_title, previous_buffer, previous_window, buffer, window)
                end,
            })

            vim.api.nvim_create_autocmd("BufEnter", {
                pattern = "*.norg",
                callback = function()
                    if not vim.api.nvim_buf_is_valid(buffer) or not vim.api.nvim_buf_is_loaded(buffer) then
                        return true
                    end

                    local buf = vim.api.nvim_get_current_buf()

                    if buf == buffer or previous_buffer == buf then
                        return
                    end

                    previous_buffer, previous_window = buf, vim.api.nvim_get_current_win()

                    toc = module.public.parse_toc_macro(buf)
                    toc_title = toc and toc.parameters and vim.split(toc.parameters, "\n") or { "Table of Contents" }
                    module.public.update_toc(namespace, toc_title, buf, previous_window, buffer, window)
                end,
            })
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        [module.name] = true,
    },
}

return module
