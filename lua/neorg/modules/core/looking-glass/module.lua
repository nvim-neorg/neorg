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
    sync_text_segment = function(source, target, start, _end) end,
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

        if not vpslit then
            vim.notify("Unable to magnify current code block because our split didn't want to open :(")
            return
        end

        -- module.public.sync_text_segment()
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.looking-glass.magnify-code-block"] = true,
    },
}

return module
