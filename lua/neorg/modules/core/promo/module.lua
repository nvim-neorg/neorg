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

	if mode == "promote" then
            function adjust_prefix(prefix_node)
                row,col = prefix_node:start()
                vim.api.nvim_buf_set_text(buffer, row, col, row, col, {prefix})
                return true
            end
        else
            function adjust_prefix(prefix_node)
                row_start,col_start = prefix_node:start()
                row_end, col_end = prefix_node:end_()
                -- TODO: assert row_start==row_end ?
                -- TODO: assert col_start+2 <= col_end ?
                if col_start+2 == col_end then
                    return false
                end
                vim.api.nvim_buf_set_text(buffer, row, col, row, col+1, {''})
                return true
            end
        end

        -- apply f recursively to node, until f returns false
        -- assumption: the prefix node of the root comes before all other children
        function apply_recursive(node, f)
            if not f(node) then
                return
            end
            for child in node:iter_children() do
                if not apply_recursive(child, f) then
                    return
                end
            end
        end

        apply_recursive(node, function(c)
            if c:type():sub(-7) == "_prefix" then
                return adjust_prefix(c)
            end
            return true
	end)

        local node_range = module.required["core.integrations.treesitter"].get_node_range(node)
        -- TODO: preserve cursor position
        vim.api.nvim_win_set_cursor(0,{node_range.row_start+1,0})
        n_rows = node_range.row_end - node_range.row_start + 1
        -- indent range
        vim.api.nvim_feedkeys(n_rows .. '==', "n", false)
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

        if neorg.modules.loaded_modules["core.concealer"] then
            neorg.events.broadcast_event(
                neorg.events.create(
                    neorg.modules.loaded_modules["core.concealer"],
                    "core.concealer.events.update_region",
                    { start = start_pos[1] - 1, ["end"] = end_pos[1] + 2 }
                )
            )
        end
    elseif event.split_type[2] == "core.promo.demote_range" then
        local start_pos = vim.api.nvim_buf_get_mark(event.buffer, "<")
        local end_pos = vim.api.nvim_buf_get_mark(event.buffer, ">")

        for i = 0, end_pos[1] - start_pos[1] do
            module.public.promote_or_demote(event.buffer, "demote", start_pos[1] + i)
        end

        if neorg.modules.loaded_modules["core.concealer"] then
            neorg.events.broadcast_event(
                neorg.events.create(
                    neorg.modules.loaded_modules["core.concealer"],
                    "core.concealer.events.update_region",
                    { start = start_pos[1] - 1, ["end"] = end_pos[1] + 2 }
                )
            )
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
