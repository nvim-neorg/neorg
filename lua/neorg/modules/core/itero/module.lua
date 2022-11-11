--[[
--
--]]

local module = neorg.modules.create("core.itero")

module.setup = function()
    return {
        requires = {
            "core.keybinds",
            "core.integrations.treesitter",
        },
    }
end

module.config.public = {
    iterables = {
        "unordered_list%d",
        "ordered_list%d",
        -- "quote%d",
    },

    stop_types = {
        "generic_list",
    },
}

module.load = function()
    module.required["core.keybinds"].register_keybinds(module.name, { "next-iteration", "stop-iteration" })
end

module.on_event = function(event)
    if event.split_type[2] == (module.name .. ".next-iteration") then
        local cursor_pos = event.cursor_position[1] - 1

        local node_on_line = module.required["core.integrations.treesitter"].get_first_node_on_line(event.buffer, cursor_pos, module.config.public.stop_types)
        local text_to_repeat = nil

        for _, iterable in ipairs(module.config.public.iterables) do
            if node_on_line:type():match(iterable) then
                text_to_repeat = module.required["core.integrations.treesitter"].get_node_text(node_on_line:named_child(0))
                vim.api.nvim_buf_set_lines(event.buffer, cursor_pos + 1, cursor_pos + 1, true, { text_to_repeat })
                break
            end
        end

        if node_on_line:has_error() then
            vim.api.nvim_buf_set_lines(event.buffer, cursor_pos, cursor_pos + 1, true, { "" })
            return
        end

        if not text_to_repeat then
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, true, true), "n", false)
            return
        end

        vim.api.nvim_win_set_cursor(event.window, { cursor_pos + 2, text_to_repeat:len() })
    elseif event.split_type[2] == (module.name .. ".stop-iteration") then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, true, true), "n", false)
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        [module.name .. ".next-iteration"] = true,
        [module.name .. ".stop-iteration"] = true,
    },
}

return module
