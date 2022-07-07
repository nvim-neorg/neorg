local module = neorg.modules.create("core.looking-glass")

module.setup = function()
    if not neorg.utils.is_minimum_version(0, 7, 0) then
        log.error("The `looking-glass` module requires Neovim 0.7+! Please upgrade your Neovim installation.")
        return {
            success = false,
        }
    end

    return {
        success = true,
        requires = {
            "core.keybinds",
            "core.integrations.treesitter",
            "core.ui",
        },
    }
end

module.load = function()
    module.required["core.keybinds"].register_keybind(module.name, "magnify-code-block")
end

module.public = {
    sync_text_segment = function(source, source_window, source_start, source_end, target, target_window)
        local namespace = vim.api.nvim_create_namespace(
            "neorg/code-block-" .. tostring(source) .. tostring(source_start) .. tostring(source_end)
        )

        vim.api.nvim_buf_clear_namespace(source, namespace, 0, -1)

        local start_extmark = vim.api.nvim_buf_set_extmark(source, namespace, source_start, 0, {})
        local end_extmark = vim.api.nvim_buf_set_extmark(source, namespace, source_end, 0, {})

        vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
            buffer = source,
            callback = function()
                if not vim.api.nvim_buf_is_loaded(target) then
                    return true
                end

                local cursor_pos = vim.api.nvim_win_get_cursor(0)

                vim.schedule(function()
                    local extmark_begin = vim.api.nvim_buf_get_extmark_by_id(source, namespace, start_extmark, {})
                    local extmark_end = vim.api.nvim_buf_get_extmark_by_id(source, namespace, end_extmark, {})

                    if extmark_end[1] == extmark_begin[1] then
                        vim.api.nvim_buf_delete(target, { force = true })
                        vim.api.nvim_buf_clear_namespace(source, namespace, 0, -1)
                        return true
                    end

                    if cursor_pos[1] > extmark_begin[1] and cursor_pos[1] <= (extmark_end[1] + 1) then
                        local current_node =
                            module.required["core.integrations.treesitter"].get_ts_utils().get_node_at_cursor(0, true)

                        if not current_node or not current_node:type():match("^ranged_tag.*") then
                            vim.api.nvim_buf_delete(target, { force = true })
                            vim.api.nvim_buf_clear_namespace(source, namespace, 0, -1)
                            return true
                        end

                        vim.api.nvim_buf_set_lines(
                            target,
                            0,
                            -1,
                            false,
                            vim.api.nvim_buf_get_lines(source, extmark_begin[1] + 1, extmark_end[1], true)
                        )

                        local target_line_count = vim.api.nvim_buf_line_count(target)

                        if cursor_pos[1] - extmark_begin[1] > target_line_count then
                            vim.api.nvim_win_set_cursor(target_window, { target_line_count, cursor_pos[2] })
                        else
                            vim.api.nvim_win_set_cursor(
                                target_window,
                                { cursor_pos[1] - extmark_begin[1], cursor_pos[2] }
                            )
                        end
                    end
                end)
            end,
        })

        vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
            buffer = target,
            callback = vim.schedule_wrap(function()
                local cursor_pos = vim.api.nvim_win_get_cursor(0)

                local extmark_begin = vim.api.nvim_buf_get_extmark_by_id(source, namespace, start_extmark, {})
                local extmark_end = vim.api.nvim_buf_get_extmark_by_id(source, namespace, end_extmark, {})

                vim.api.nvim_buf_set_lines(
                    source,
                    extmark_begin[1] + 1,
                    extmark_end[1],
                    true,
                    vim.api.nvim_buf_get_lines(target, 0, -1, true)
                )
                vim.api.nvim_win_set_cursor(source_window, { cursor_pos[1] + extmark_begin[1], cursor_pos[2] })
            end),
        })

        vim.api.nvim_create_autocmd({ "BufDelete", "WinClosed" }, {
            buffer = target,
            callback = function()
                pcall(vim.api.nvim_buf_delete, target, { force = true })
                vim.api.nvim_buf_clear_namespace(source, namespace, 0, -1)
            end,
        })
    end,
}

module.on_event = function(event)
    if event.split_type[2] == "core.looking-glass.magnify-code-block" then
        local query = vim.treesitter.parse_query(
            "norg",
            [[
            (ranged_tag
                name: (tag_name) @_name
                (#eq? @_name "code")) @tag
        ]]
        )

        local document_root = module.required["core.integrations.treesitter"].get_document_root(event.buffer)

        local code_block_info

        do
            local cursor_pos = vim.api.nvim_win_get_cursor(event.window)

            for id, node in query:iter_captures(document_root, event.buffer, cursor_pos[1] - 1, cursor_pos[1]) do
                local capture = query.captures[id]

                if capture == "tag" then
                    local tag_info = module.required["core.integrations.treesitter"].get_tag_info(node)

                    if not tag_info then
                        vim.notify("Unable to magnify current code block :(")
                        return
                    end

                    code_block_info = tag_info
                end
            end
        end

        if not code_block_info then
            vim.notify("No code block found under cursor!")
            return
        end

        local vsplit = module.required["core.ui"].create_vsplit(
            "code-block-" .. tostring(code_block_info.start.row) .. tostring(code_block_info["end"].row),
            {
                filetype = (code_block_info.parameters[1] or "none"),
            },
            true
        )

        if not vsplit then
            vim.notify("Unable to magnify current code block because our split didn't want to open :(")
            return
        end

        vim.api.nvim_buf_set_lines(vsplit, 0, -1, true, code_block_info.content)

        module.public.sync_text_segment(
            event.buffer,
            event.window,
            code_block_info.start.row,
            code_block_info["end"].row,
            vsplit,
            vim.api.nvim_get_current_win()
        )
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.looking-glass.magnify-code-block"] = true,
    },
}

return module
