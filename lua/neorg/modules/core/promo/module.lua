local module = neorg.modules.create("core.promo")

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
}

module.public = {
    get_promotable_node_prefix = function(node)
        for _, data in pairs(module.private.types) do
            if node:type():match(data.pattern) then
                return data.prefix
            end
        end
    end,

    promote_or_demote = function(buffer, mode, row)
        local node = module.required["core.integrations.treesitter"].get_first_node_on_line(buffer, row)

        local prefix = module.public.get_promotable_node_prefix(node)

        if not prefix then
            vim.api.nvim_feedkeys(mode == "promote" and ">>" or "<<", "n", false)
            return
        end

        local title_node = node:named_child(0)
        local title_range = module.required["core.integrations.treesitter"].get_node_range(title_node)
        local title = module.required["core.integrations.treesitter"].get_node_text(title_node, buffer)

        do
            if mode == "promote" then
                title = table.concat({ prefix, title })
            elseif mode == "demote" then
                if title:match(table.concat({ "^", prefix, "*" })):len() <= 1 then
                    return
                end

                title = title:sub(2)
            end

            vim.api.nvim_buf_set_text(
                buffer,
                title_range.row_start,
                title_range.column_start,
                title_range.row_end,
                title_range.column_end,
                { title }
            )
        end

        neorg.events.broadcast_event(
            neorg.events.create(module, "core.norg.concealer.events.update_region", { start = row, ["end"] = row + 1 })
        )
    end,
}

module.on_event = function(event)
    local row = event.cursor_position[1] - 1

    if event.split_type[1] == "core.keybinds" then
        if event.split_type[2] == "core.promo.promote" then
            module.public.promote_or_demote(event.buffer, "promote", row)
        elseif event.split_type[2] == "core.promo.demote" then
            module.public.promote_or_demote(event.buffer, "demote", row)
        elseif event.split_type[2] == "core.promo.promote_range" then
            local start_pos = vim.api.nvim_buf_get_mark(event.buffer, "<")
            local end_pos = vim.api.nvim_buf_get_mark(event.buffer, ">")
            for i = 0, end_pos[1] - start_pos[1] do
                module.public.promote_or_demote(event.buffer, "promote", start_pos[1] + i)
            end
            local concealer_event = neorg.events.create(
                module,
                "core.norg.concealer.events.update_region",
                { start = start_pos[1] - 1, ["end"] = end_pos[1] + 2 }
            )
            neorg.events.broadcast_event(concealer_event, function() end)
        elseif event.split_type[2] == "core.promo.demote_range" then
            local start_pos = vim.api.nvim_buf_get_mark(event.buffer, "<")
            local end_pos = vim.api.nvim_buf_get_mark(event.buffer, ">")
            for i = 0, end_pos[1] - start_pos[1] do
                module.public.promote_or_demote(event.buffer, "demote", start_pos[1] + i)
            end
            local concealer_event = neorg.events.create(
                module,
                "core.norg.concealer.events.update_region",
                { start = start_pos[1] - 1, ["end"] = end_pos[1] + 2 }
            )
            neorg.events.broadcast_event(concealer_event, function() end)
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.promo.promote"] = true,
        ["core.promo.demote"] = true,
        ["core.promo.promote_range"] = true,
        ["core.promo.demote_range"] = true,
    },
}

return module
