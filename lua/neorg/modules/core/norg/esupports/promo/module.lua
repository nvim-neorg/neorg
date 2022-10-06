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
    types = {
        heading = {
            pattern = "^heading(%d)$",
            prefix = "*",
        },
        unordered_list = {
            pattern = "^unordered_list(%d)$",
            prefix = "-",
        },
        ordered_list = {
            pattern = "^ordered_list(%d)$",
            prefix = "~",
        },
        quote = {
            pattern = "^quote(%d)$",
            prefix = ">",
        },
    },
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
    find_unordered_list = function(node)
        while node do
            if node:type():match("^unordered_list%d$") then
                return node
            end
            node = node:parent()
        end
    end,
}

module.public = {
    find_node = function(node)
        while node do
            for _, type in pairs(module.private.types) do
                if node:type():match(type.pattern) then
                    local level = tonumber(node:type():match(type.pattern))
                    return node, type.prefix, level
                end
            end
            node = node:parent()
        end
    end,
    promote_or_demote = function(event, mode)
        local start_row
        local cursor_pos = vim.api.nvim_win_get_cursor(event.window)
        local cursor_node = module.required["core.integrations.treesitter"].get_ts_utils().get_node_at_cursor(0, true)
        local node, prefix, level = module.public.find_node(cursor_node)
        if node then
            start_row, _, _, _ = node:range()
            -- cursor is on heading title
            if cursor_pos[1] == start_row + 1 then
                local title = vim.treesitter.get_node_text(node, event.buffer, { concat = false })
                -- remove prefix
                local title_text = (title[1]):sub(level + 2)
                local new_level
                if mode == "promote" then
                    -- TODO: do we want it like this?
                    new_level = level < 6 and level + 1 or 6
                elseif mode == "demote" then
                    new_level = level > 1 and level - 1 or 1
                end
                vim.api.nvim_buf_set_lines(
                    event.buffer,
                    start_row,
                    start_row + 1,
                    false,
                    { string.rep(prefix, new_level) .. " " .. title_text }
                )
            end
        end
        local concealer_event = neorg.events.create(
            module,
            "core.norg.concealer.events.update_region",
            { start = start_row, ["end"] = start_row + 2 }
        )
        neorg.events.broadcast_event(concealer_event, function() end)
    end,
}

module.on_event = function(event)
    if event.split_type[1] == "core.keybinds" then
        if event.split_type[2] == "core.norg.esupports.promo.promote" then
            module.public.promote_or_demote(event, "promote")
        elseif event.split_type[2] == "core.norg.esupports.promo.demote" then
            module.public.promote_or_demote(event, "demote")
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
