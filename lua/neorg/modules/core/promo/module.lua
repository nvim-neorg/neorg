--[[
    file: Promo
    title: You have Received a Promotion!
    description: The `promo` module increases or decreases the nesting level of nestable items by repeating their characters.
    summary: Promotes or demotes nestable items within Neorg files.
    ---
When dealing with Norg, it may sometimes be tedious to continually repeat a single character to increase
your nesting level. For example, for a level 6 nested unordered list, you need to repeat the `-` character
six times:
```norg
------ This is my item!
```

The `core.promo` module allows you to indent these object by utilizing the inbuilt Neovim keybinds:
- `>>` - increase the indentation level for the current object (also dedents children)
- `<<` - decrease the indentation level for the current object recursively (also dedents children)
- `>.` - increase the indentation level for the current object (non-recursively)
- `<,` - decrease the indentation level for the current object (non-recursively)

In insert mode, you are also provided with two keybinds, also being Neovim defaults:
- `<C-t>` increase the indentation level for the current object
- `<C-d>` decrease the indentation level for the current object

This module is commonly used with the [`core.itero`](@core.itero) module for an effective workflow.
--]]

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

    ignore_types = {
        "generic_list",
        "quote",
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

    promote_or_demote = function(buffer, mode, row, reindent_children, affect_children)
        local node = module.required["core.integrations.treesitter"].get_first_node_on_line(
            buffer,
            row,
            module.private.ignore_types
        )

        if not node or node:has_error() then
            return
        end

        local prefix = module.public.get_promotable_node_prefix(node)

        if not prefix then
            vim.api.nvim_feedkeys(
                mode == "promote" and table.concat({ tostring(vim.v.count), ">>" })
                    or table.concat({ vim.v.count, "<<" }),
                "n",
                false
            )
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

        local start_region, end_region = row, row + 1

        -- After the promotion/demotion reindent all children
        if reindent_children then
            local indent_module = neorg.modules.get_module("core.norg.esupports.indent")

            if not indent_module then
                goto finish
            end

            if not affect_children then
                node = module.required["core.integrations.treesitter"].get_first_node_on_line(buffer, row)
            end

            local node_range = module.required["core.integrations.treesitter"].get_node_range(node)

            start_region = node_range.row_start
            end_region = node_range.row_end

            if node_range.column_end == 0 then
                node_range.row_end = node_range.row_end - 1
            end

            for i = node_range.row_start, node_range.row_end do
                local node_on_line = module.required["core.integrations.treesitter"].get_first_node_on_line(buffer, i)

                if not module.public.get_promotable_node_prefix(node_on_line) then
                    local whitespace = (vim.api.nvim_buf_get_lines(buffer, i, i + 1, true)[1] or ""):match("^%s*"):len()
                    vim.api.nvim_buf_set_text(
                        buffer,
                        i,
                        0,
                        i,
                        whitespace,
                        { string.rep(" ", indent_module.indentexpr(buffer, i)) }
                    )
                elseif affect_children and i ~= node_range.row_start then
                    module.public.promote_or_demote(buffer, mode, i, reindent_children, affect_children)

                    -- luacheck: push ignore
                    i = module.required["core.integrations.treesitter"].get_node_range(node_on_line).row_end
                    -- luacheck: pop
                end
            end

            ::finish::
        end

        neorg.events.broadcast_event(
            neorg.events.create(
                module,
                "core.norg.concealer.events.update_region",
                { start = start_region, ["end"] = end_region }
            )
        )
    end,
}

module.on_event = function(event)
    local row = event.cursor_position[1] - 1

    if event.split_type[1] ~= "core.keybinds" then
        return
    end

    if event.split_type[2] == "core.promo.promote" then
        module.public.promote_or_demote(event.buffer, "promote", row, true, event.content[1] == "nested")
    elseif event.split_type[2] == "core.promo.demote" then
        module.public.promote_or_demote(event.buffer, "demote", row, true, event.content[1] == "nested")
    elseif event.split_type[2] == "core.promo.promote_range" then
        local start_pos = vim.api.nvim_buf_get_mark(event.buffer, "<")
        local end_pos = vim.api.nvim_buf_get_mark(event.buffer, ">")

        for i = 0, end_pos[1] - start_pos[1] do
            module.public.promote_or_demote(event.buffer, "promote", start_pos[1] + i)
        end

        neorg.events.broadcast_event(
            neorg.events.create(
                module,
                "core.norg.concealer.events.update_region",
                { start = start_pos[1] - 1, ["end"] = end_pos[1] + 2 }
            )
        )
    elseif event.split_type[2] == "core.promo.demote_range" then
        local start_pos = vim.api.nvim_buf_get_mark(event.buffer, "<")
        local end_pos = vim.api.nvim_buf_get_mark(event.buffer, ">")

        for i = 0, end_pos[1] - start_pos[1] do
            module.public.promote_or_demote(event.buffer, "demote", start_pos[1] + i)
        end

        neorg.events.broadcast_event(
            neorg.events.create(
                module,
                "core.norg.concealer.events.update_region",
                { start = start_pos[1] - 1, ["end"] = end_pos[1] + 2 }
            )
        )
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
