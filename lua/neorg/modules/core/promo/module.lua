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
    get_node_on_line = function(row, event)
        local parsers = require("nvim-treesitter.parsers")
        local range = { row - 1, -1 }

        local root_lang_tree = parsers.get_parser(event.buffer)
        if not root_lang_tree then
            return
        end

        local root = require("nvim-treesitter.ts_utils").get_root_for_position(range[1], range[2], root_lang_tree)

        if not root then
            return
        end

        return root:named_descendant_for_range(range[1], range[2], range[1], range[2])
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
    promote_or_demote = function(event, mode, row)
        local cursor = not row
        local start_row
        local cursor_pos = vim.api.nvim_win_get_cursor(event.window)
        row = row or cursor_pos[1]
        local start_node = module.private.get_node_on_line(row, event)
        local node, prefix, level = module.public.find_node(start_node)
        if node then
            start_row, _, _, _ = node:range()
            -- cursor is on heading title
            if row == start_row + 1 then
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
            else
                if cursor then
                    local lines = vim.api.nvim_buf_get_lines(event.buffer, row - 1, row, false)
                    if mode == "promote" then
                        lines[1] = string.rep(" ", vim.bo[event.buffer].shiftwidth) .. lines[1]
                        vim.api.nvim_buf_set_lines(event.buffer, row - 1, row, false, lines)
                    elseif mode == "demote" then
                        local spaces = #lines[1]:match("^(%s*)")
                        lines[1] = string.rep(
                            " ",
                            spaces > vim.bo[event.buffer].shiftwidth and spaces - vim.bo[event.buffer].shiftwidth or 0
                        ) .. lines[1]:gsub("^%s*", "")
                        vim.api.nvim_buf_set_lines(event.buffer, row - 1, row, false, lines)
                    end
                end
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
        if event.split_type[2] == "core.promo.promote" then
            module.public.promote_or_demote(event, "promote")
        elseif event.split_type[2] == "core.promo.demote" then
            module.public.promote_or_demote(event, "demote")
        elseif event.split_type[2] == "core.promo.promote_range" then
            local start_pos = vim.api.nvim_buf_get_mark(event.buffer, "<")
            local end_pos = vim.api.nvim_buf_get_mark(event.buffer, ">")
            for i = 0, end_pos[1] - start_pos[1] do
                module.public.promote_or_demote(event, "promote", start_pos[1] + i)
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
                module.public.promote_or_demote(event, "demote", start_pos[1] + i)
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
