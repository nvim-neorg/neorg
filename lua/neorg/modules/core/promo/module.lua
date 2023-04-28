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
        local root_node = module.required["core.integrations.treesitter"].get_first_node_on_line(
            buffer,
            row,
            module.private.ignore_types
        )

        if not root_node or root_node:has_error() then
            return
        end

        -- vim buffer helpers
        local function buffer_get_line(buffer, row)
            return vim.api.nvim_buf_get_lines(buffer, row, row+1, true)[1]
        end

        local function count_leading_whitespace(s)
            return s:match("^%s*"):len()
        end

        local function buffer_insert(buffer, row, col, s)
            return vim.api.nvim_buf_set_text(buffer, row, col, row, col, {s})
        end

        local function buffer_delete(buffer, row, col, n_char)
            return vim.api.nvim_buf_set_text(buffer, row, col, row, col+n_char, {})
        end

        local function buffer_set_line_indent(buffer, row, new_indent)
            local n_whitespace = count_leading_whitespace(buffer_get_line(buffer, row))
            return vim.api.nvim_buf_set_text(buffer, row, 0, row, n_whitespace, { (" "):rep(new_indent) })
        end

        -- treesitter node helpers
        local function get_header_prefix_node(header_node)
            local first_child = header_node:child(0)
            assert(first_child:type() == header_node:type() .. "_prefix")
            return first_child
        end

        local function get_node_row_range(node)
            local row_start, _ = node:start()
            local row_end, _ = node:end_()
            return row_start, row_end
        end

        local function is_prefix_node(node)
            return node:type():match("_prefix$") ~= nil
        end

        local function get_prefix_position_and_level(prefix_node)
            assert(is_prefix_node(prefix_node))
            row_start,col_start = prefix_node:start()
            row_end, col_end = prefix_node:end_()
            assert(row_start == row_end)
            assert(col_start+2 <= col_end)
            return row_start, col_start, (col_end - col_start - 1)
        end

        local action_count = vim.v.count
        assert(action_count >= 0)
        action_count = math.max(action_count, 1)

        local root_prefix_char = module.public.get_promotable_node_prefix(root_node)
        if not root_prefix_char then
            local n_space_diff = vim.bo.shiftwidth * action_count
            if mode == "demote" then
                n_space_diff = -n_space_diff
            end
            local current_visual_indent = vim.fn.indent(row+1)
            local new_indent = math.max(0, current_visual_indent + n_space_diff)
            buffer_set_line_indent(buffer, row, new_indent)
            return
        end

        local root_prefix_node = get_header_prefix_node(root_node)
        local _, _, root_level = get_prefix_position_and_level(root_prefix_node)

        local adjust_prefix
        if mode == "promote" then
            adjust_prefix = function(prefix_node)
                local row,col,_ = get_prefix_position_and_level(prefix_node)
                buffer_insert(buffer, row, col, root_prefix_char:rep(action_count))
            end
        else
            action_count = math.min(action_count, root_level-1)
            assert(action_count >= 0)
            if action_count == 0 then
                assert(root_level == 1)
                -- TODO: warning?
                return
            end

            adjust_prefix = function(prefix_node)
                local row, col, level = get_prefix_position_and_level(prefix_node)
                assert(level > action_count)
                buffer_delete(buffer, row, col, action_count)
            end
        end

        if not affect_children then
            adjust_prefix(root_prefix_node)
            return
        end

        local function apply_recursive_normal(node, is_target, f)
            if not is_target(node) then
                return
            end
            f(node)
            for child in node:iter_children() do
                apply_recursive_normal(child, is_target, f)
            end
        end

        local function apply_recursive_verylow(node, is_target, f)
            local started = false
            local _r, _c, level = get_prefix_position_and_level(get_header_prefix_node(node))
            f(node)
            for sibling in node:parent():iter_children() do
                if started then
                    if not is_target(sibling) then
                        -- assert(false), shouldn't reach here ?
                        break
                    end
                    local _, _, sibling_level = get_prefix_position_and_level(get_header_prefix_node(sibling))
                    if sibling_level <= level then
                        break
                    end
                    f(sibling)
                end
                started = started or (sibling == node)
            end
        end

        local HEADING_VERYLOW_LEVEL = 6

        local indent_targets = {}
        local apply_recursive = root_level<HEADING_VERYLOW_LEVEL and apply_recursive_normal or apply_recursive_verylow

        apply_recursive(root_node,
            function(node) return module.public.get_promotable_node_prefix(node) == root_prefix_char end,
            function(node) indent_targets[#indent_targets+1] = node end
        )

        local indent_row_start, indent_row_end = get_node_row_range(root_node)
        if root_level >= HEADING_VERYLOW_LEVEL then
            local _, last_child_row_end = get_node_row_range(indent_targets[#indent_targets])
            indent_row_end = math.max(indent_row_end, last_child_row_end)
        end

        for _,node in ipairs(indent_targets) do
            adjust_prefix(get_header_prefix_node(node))
        end

        if not reindent_children then
            return
        end

        local indent_module = neorg.modules.get_module("core.esupports.indent")
        if not indent_module then
            return
        end

        local function notify_concealer(row_start, row_end)
            -- HACK(vhyrro): This should be changed after the codebase refactor
            local concealer_module = neorg.modules.loaded_modules["core.concealer"]
            if not concealer_module then
                return
            end
            neorg.events.broadcast_event(
                neorg.events.create(
                    concealer_module,
                    "core.concealer.events.update_region",
                    { start = row_start, ["end"] = row_end }
                )
            )
        end

        local function reindent_range(row_start, row_end)
            for i = row_start, row_end-1 do
                local indent_level = indent_module.indentexpr(buffer, i)
                buffer_set_line_indent(buffer, i, indent_level)
            end
        end

        reindent_range(indent_row_start, indent_row_end)
        notify_concealer(indent_row_start, indent_row_end)
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
