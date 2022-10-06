local module = neorg.modules.create("core.norg.esupports.promo")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
            "core.keybinds",
        },
    }
end

module.load = function()
    module.required["core.keybinds"].register_keybinds(
        module.name,
        (function()
            local keys = vim.tbl_keys(module.events.subscribed["core.keybinds"])

            for i, key in ipairs(keys) do
                keys[i] = key:sub(module.name:len() + 2)
            end

            return keys
        end)()
    )
end

module.config.public = {}

module.private = {
    find_heading = function(node)
        while node do
            if node:type():match("^heading%d$") then
                return node
            end
            node = node:parent()
        end
    end,
    find_ordered_list = function(node)
        while node do
            if node:type():match("^ordered_list%d$") then
                return node
            end
            node = node:parent()
        end
    end,
}

module.public = {
    promote = function(event)
        local cursor_pos = vim.api.nvim_win_get_cursor(event.window)
        local cursor_node = module.required["core.integrations.treesitter"].get_ts_utils().get_node_at_cursor(0, true)
        local heading_node = module.private.find_heading(cursor_node)
        if heading_node then
            local start_row, _, _, _ = heading_node:range()
            -- cursor is on heading title
            if cursor_pos[1] == start_row + 1 then
                local level = tonumber(heading_node:type():match("^heading(%d)$"))
                local title = vim.treesitter.get_node_text(heading_node, event.buffer, { concat = false })
                -- remove prefix
                local title_text = (title[1]):sub(level + 2)
                -- TODO: do we want it like this?
                local new_level = level < 6 and level + 1 or 6
                vim.api.nvim_buf_set_lines(
                    event.buffer,
                    start_row,
                    start_row + 1,
                    false,
                    { string.rep("*", new_level) .. " " .. title_text }
                )
            end
        end
        local ordered_list_node = module.private.find_ordered_list(cursor_node)
        if ordered_list_node then
            local start_row, _, _, _ = ordered_list_node:range()
            -- cursor is on ordered list item
            if cursor_pos[1] == start_row + 1 then
                local level = tonumber(ordered_list_node:type():match("^ordered_list(%d)$"))
                local item = vim.treesitter.get_node_text(ordered_list_node, event.buffer, { concat = false })
                -- remove prefix
                local item_text = (item[1]):sub(level + 2)
                -- TODO: do we want it like this?
                local new_level = level < 6 and level + 1 or 6
                vim.api.nvim_buf_set_lines(
                    event.buffer,
                    start_row,
                    start_row + 1,
                    false,
                    { string.rep("~", new_level) .. " " .. item_text }
                )
            end
        end
    end,
    demote = function(event)
        local cursor_pos = vim.api.nvim_win_get_cursor(event.window)
        local cursor_node = module.required["core.integrations.treesitter"].get_ts_utils().get_node_at_cursor(0, true)
        local heading_node = module.private.find_heading(cursor_node)
        if heading_node then
            local start_row, _, _, _ = heading_node:range()
            -- cursor is on heading title
            if cursor_pos[1] == start_row + 1 then
                local level = tonumber(heading_node:type():match("^heading(%d)$"))
                local title = vim.treesitter.get_node_text(heading_node, event.buffer, { concat = false })
                -- remove prefix
                local title_text = (title[1]):sub(level + 2)
                local new_level = level > 1 and level - 1 or 1
                vim.api.nvim_buf_set_lines(
                    event.buffer,
                    start_row,
                    start_row + 1,
                    false,
                    { string.rep("*", new_level) .. " " .. title_text }
                )
            end
        end
        local ordered_list_node = module.private.find_ordered_list(cursor_node)
        if ordered_list_node then
            local start_row, _, _, _ = ordered_list_node:range()
            -- cursor is on ordered list item
            if cursor_pos[1] == start_row + 1 then
                local level = tonumber(ordered_list_node:type():match("^ordered_list(%d)$"))
                local item = vim.treesitter.get_node_text(ordered_list_node, event.buffer, { concat = false })
                -- remove prefix
                local item_text = (item[1]):sub(level + 2)
                local new_level = level > 1 and level - 1 or 1
                vim.api.nvim_buf_set_lines(
                    event.buffer,
                    start_row,
                    start_row + 1,
                    false,
                    { string.rep("~", new_level) .. " " .. item_text }
                )
            end
        end
    end,
}

module.on_event = function(event)
    if event.split_type[1] == "core.keybinds" then
        if event.split_type[2] == "core.norg.esupports.promo.promote" then
            module.public.promote(event)
        elseif event.split_type[2] == "core.norg.esupports.promo.demote" then
            module.public.demote(event)
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.norg.esupports.promo.promote"] = true,
        ["core.norg.esupports.promo.demote"] = true,
    },
}

return module
