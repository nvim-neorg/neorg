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
    -- If true, will automatically continue list items and the like when `<CR>`
    -- is pressed, and will stop when `<M-CR>` is pressed or `<CR>` is pressed
    -- twice.
    --
    -- When false, will do the opposite - list items will not be continued unless
    -- `<M-CR>` is pressed.
    trigger_by_default = true,

    iterables = {
        "unordered_list%d",
        "ordered_list%d",
        "heading%d",
        "quote%d",
    },

    stop_types = {
        "generic_list",
        "quote",
    },
}

module.load = function()
    module.required["core.keybinds"].register_keybinds(module.name, { "next-iteration", "stop-iteration" })
end

module.on_event = function(event)
    if event.split_type[2] == (module.name .. ".next-iteration") then
        local ts = module.required["core.integrations.treesitter"]
        local cursor_pos = event.cursor_position[1] - 1

        local current = ts.get_first_node_on_line(event.buffer, cursor_pos, module.config.public.stop_types)

        if not current then
            log.error(
                "Treesitter seems to be high and can't properly grab the node under the cursor. Perhaps try again?"
            )
            return
        end

        while current:parent() do
            if
                neorg.lib.filter(module.config.public.iterables, function(_, iterable)
                    return current:type():match(table.concat({ "^", iterable, "$" })) and iterable or nil
                end)
            then
                break
            end

            current = current:parent()
        end

        if not current or current:type() == "document" then
            vim.notify("No object to continue! Make sure you're under a list item.")
            return
        end

        local text_to_repeat = ts.get_node_text(current:named_child(0), event.buffer)

        vim.api.nvim_buf_set_lines(event.buffer, cursor_pos + 1, cursor_pos + 1, true, { text_to_repeat })
        vim.api.nvim_win_set_cursor(event.window, { cursor_pos + 2, text_to_repeat:len() })
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        [module.name .. ".next-iteration"] = true,
        [module.name .. ".stop-iteration"] = true,
    },
}

return module
