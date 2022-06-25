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
    sync_text_segment = function(source, source_start, source_end, target)
        vim.api.nvim_buf_attach(source, false, {
            on_lines = function(_, _, _, first, _, last)
                if not vim.api.nvim_buf_is_loaded(target) then
                    return true
                end

                local cursor_row = vim.api.nvim_win_get_cursor(0)[1]

                if cursor_row < source_start or cursor_row > source_end then
                    return
                end

                vim.schedule(function()
                    vim.api.nvim_buf_set_lines(target, first - source_start - 1, last - source_end - 1, true, vim.api.nvim_buf_get_lines(source, first, last, true))
                end)
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

            for id, node in query:iter_captures(document_root, event.buffer, cursor_pos[1], cursor_pos[1] + 1) do
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

        module.public.sync_text_segment(event.buffer, code_block_info.start.row, code_block_info["end"].row, vsplit)
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.looking-glass.magnify-code-block"] = true,
    },
}

return module
