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

local neorg = require("neorg.core")
local modules = neorg.modules

local module = modules.create("core.promo")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
        },
    }
end

module.load = function()
    modules.await("core.keybinds", function(keybinds)
        keybinds.register_keybinds(
            module.name,
            (function()
                local keys = vim.tbl_keys(module.events.subscribed["core.keybinds"])

                for i, key in ipairs(keys) do
                    keys[i] = key:sub(module.name:len() + 2)
                end

                return keys
            end)()
        )
    end)
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

    get_line = function(buffer, target_row)
        return vim.api.nvim_buf_get_lines(buffer, target_row, target_row + 1, true)[1]
    end,

    buffer_set_line_indent = function(buffer, start_row, new_indent)
        local line = module.private.get_line(buffer, start_row)

        if line:match("^%s*$") then
            return
        end

        local leading_whitespace = line:match("^%s*"):len()

        return vim.api.nvim_buf_set_text(buffer, start_row, 0, start_row, leading_whitespace, { (" "):rep(new_indent) })
    end,

    reindent_range = function(buffer, row_start, row_end)
        local indent_module = modules.get_module("core.esupports.indent")
        if not indent_module then
            return
        end

        for i = row_start, row_end - 1 do
            local indent_level = indent_module.indentexpr(buffer, i)
            module.private.buffer_set_line_indent(buffer, i, indent_level)
        end
    end,
}

---@class core.promo
module.public = {
    get_promotable_node_prefix = function(node)
        for _, data in pairs(module.private.types) do
            if node:type():match(data.pattern) then
                return data.prefix
            end
        end
    end,

    promote_or_demote = function(buffer, mode, row, reindent_children, affect_children)
        -- Treesitter node helpers
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
            local row_start, col_start, row_end, col_end = prefix_node:range()

            assert(row_start == row_end)
            assert(col_start + 2 <= col_end)
            return row_start, col_start, (col_end - col_start - 1)
        end

        local function is_quasi_prefix(target_row)
            local line = module.private.get_line(buffer, target_row)
            -- NOTE: This is a hardcoded check determined by the limitations of
            -- the first generation treesitter parser.
            return line:match("^%s*[%-~%*]+%s*$")
        end

        local function adjust_quasi_prefix(target_row, count)
            local line = module.private.get_line(buffer, target_row)
            local l, r = line:find("%S+")
            assert(l)
            assert(count ~= 0)
            if count > 0 then
                vim.api.nvim_buf_set_text(buffer, target_row, l - 1, target_row, l - 1, { line:sub(l, l):rep(count) })
            else
                local level_remain = math.max(1, r - l + 1 + count)
                vim.api.nvim_buf_set_text(buffer, target_row, l - 1, target_row, r - level_remain, {})
            end
        end

        local root_node = module.required["core.integrations.treesitter"].get_first_node_on_line(
            buffer,
            row,
            module.private.ignore_types
        )

        local action_count = vim.v.count1

        if not root_node or root_node:has_error() then
            if is_quasi_prefix(row) then
                adjust_quasi_prefix(row, action_count * (mode == "promote" and 1 or -1))
            end
            return
        end

        local root_prefix_char = module.public.get_promotable_node_prefix(root_node)
        if not root_prefix_char then
            local n_space_diff = vim.bo.shiftwidth * action_count
            if mode == "demote" then
                n_space_diff = -n_space_diff
            end

            local current_visual_indent = vim.fn.indent(row + 1)
            local new_indent = math.max(0, current_visual_indent + n_space_diff)

            module.private.buffer_set_line_indent(buffer, row, new_indent)
            return
        end

        local root_prefix_node = get_header_prefix_node(root_node)
        local _, _, root_level = get_prefix_position_and_level(root_prefix_node)

        local adjust_prefix
        if mode == "promote" then
            adjust_prefix = function(prefix_node)
                local prefix_row, prefix_col, _ = get_prefix_position_and_level(prefix_node)
                vim.api.nvim_buf_set_text(
                    buffer,
                    prefix_row,
                    prefix_col,
                    prefix_row,
                    prefix_col,
                    { root_prefix_char:rep(action_count) }
                )
            end
        else
            action_count = math.min(action_count, root_level - 1)
            assert(action_count >= 0)

            if action_count == 0 then
                assert(root_level == 1)
                return
            end

            adjust_prefix = function(prefix_node)
                local prefix_row, prefix_col, level = get_prefix_position_and_level(prefix_node)
                assert(level > action_count)
                vim.api.nvim_buf_set_text(buffer, prefix_row, prefix_col, prefix_row, prefix_col + action_count, {})
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
            local _, _, level = get_prefix_position_and_level(get_header_prefix_node(node))

            f(node)

            for sibling in node:parent():iter_children() do
                if started then
                    if not is_target(sibling) then
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
        local apply_recursive = root_level < HEADING_VERYLOW_LEVEL and apply_recursive_normal or apply_recursive_verylow

        apply_recursive(root_node, function(node)
            return module.public.get_promotable_node_prefix(node) == root_prefix_char
        end, function(node)
            indent_targets[#indent_targets + 1] = node
        end)

        local indent_row_start, indent_row_end = get_node_row_range(root_node)
        if root_level >= HEADING_VERYLOW_LEVEL then
            local _, last_child_row_end = get_node_row_range(indent_targets[#indent_targets])
            indent_row_end = math.max(indent_row_end, last_child_row_end)
        end

        for _, node in ipairs(indent_targets) do
            adjust_prefix(get_header_prefix_node(node))
        end

        if not reindent_children then
            return
        end

        module.private.reindent_range(buffer, indent_row_start, indent_row_end)
    end,
}

module.on_event = neorg.utils.wrap_dotrepeat(function(event)
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

        for i = start_pos[1], end_pos[1] do
            module.public.promote_or_demote(event.buffer, "promote", i - 1, false, false)
        end
        module.private.reindent_range(event.buffer, start_pos[1], end_pos[1])
    elseif event.split_type[2] == "core.promo.demote_range" then
        local start_pos = vim.api.nvim_buf_get_mark(event.buffer, "<")
        local end_pos = vim.api.nvim_buf_get_mark(event.buffer, ">")

        for i = start_pos[1], end_pos[1] do
            module.public.promote_or_demote(event.buffer, "demote", i - 1, false, false)
        end
        module.private.reindent_range(event.buffer, start_pos[1], end_pos[1])
    end
end)

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.promo.promote"] = true,
        ["core.promo.demote"] = true,
        ["core.promo.promote_range"] = true,
        ["core.promo.demote_range"] = true,
    },
}

return module
