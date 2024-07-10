--[[
    file: Norg-Text-Objects
    title: Navigation, Selection, and Swapping
    summary: A Neorg module for moving and selecting elements of the document.
    ---

**WARNING:** Requires nvim 0.10+

- Easily move items up and down in the document
- Provides text objects for headings, tags, and lists

## Usage

Users can create keybinds for some or all of the different events this module exposes. Those are:

those events are:

- `core.text-objects.item_up` - Moves the current "item" up
- `core.text-objects.item_down` - same but down
- `core.text-objects.textobject.heading.outer`
- `core.text-objects.textobject.heading.inner`
- `core.text-objects.textobject.tag.inner`
- `core.text-objects.textobject.tag.outer`
- `core.text-objects.textobject.list.outer` - around the entire list

_Movable "items" include headings, and list items (ordered/unordered/todo)_

### Example

Example keybinds that would go in your Neorg configuration:

```lua
vim.keymap.set("n", "<up>", "<Plug>(neorg.text-objects.item-up)", {})
vim.keymap.set("n", "<down>", "<Plug>(neorg.text-objects.item-down)", {})
vim.keymap.set({ "o", "x" }, "iH", "<Plug>(neorg.text-objects.textobject.heading.inner)", {})
vim.keymap.set({ "o", "x" }, "aH", "<Plug>(neorg.text-objects.textobject.heading.outer)", {})
```

--]]

local neorg = require("neorg.core")
local utils, log, modules, lib = neorg.utils, neorg.log, neorg.modules, neorg.lib
local ts

local module = modules.create("core.text-objects")

module.setup = function()
    if not utils.is_minimum_version(0, 10, 0) then
        log.error("This module requires at least Neovim 0.10 to run!")

        return {
            success = false,
        }
    end

    return {
        success = true,
        requires = { "core.integrations.treesitter" },
    }
end

module.load = function()
    ts = module.required["core.integrations.treesitter"]
    vim.keymap.set("", "<Plug>(neorg.text-objects.item-up)", module.public.move_up)
    vim.keymap.set("", "<Plug>(neorg.text-objects.item-down)", module.public.move_down)
    vim.keymap.set("", "<Plug>(neorg.text-objects.textobject.heading.outer)", lib.wrap(module.public.highlight_node, "heading.outer"))
    vim.keymap.set("", "<Plug>(neorg.text-objects.textobject.heading.inner)", lib.wrap(module.public.highlight_node, "heading.inner"))
    vim.keymap.set("", "<Plug>(neorg.text-objects.textobject.tag.inner)", lib.wrap(module.public.highlight_node, "tag.inner"))
    vim.keymap.set("", "<Plug>(neorg.text-objects.textobject.tag.outer)", lib.wrap(module.public.highlight_node, "tag.outer"))
    vim.keymap.set("", "<Plug>(neorg.text-objects.textobject.list.outer)", lib.wrap(module.public.highlight_node, "lits.outer"))
end

module.config.public = {
    moveables = {
        headings = {
            "heading%d",
            "heading%d",
        },
        todo_items = {
            "todo_item%d",
            {
                "todo_item%d",
                "unordered_list%d",
            },
        },
        unordered_list_elements = {
            "unordered_list%d",
            {
                "todo_item%d",
                "unordered_list%d",
            },
        },
    },
}

---@class core.text-objects
module.private = {
    get_element_from_cursor = function(node_pattern)
        local node_at_cursor = vim.treesitter.get_node()

        if
            not node_at_cursor
            or not node_at_cursor:parent()
            or not node_at_cursor:parent():type():match(node_pattern)
        then
            log.trace(string.format("Could not find element of pattern '%s' under the cursor", node_pattern))
            return
        end

        return node_at_cursor:parent()
    end,

    move_item_down = function(pattern, expected_sibling_name, buffer)
        local element = module.private.get_element_from_cursor(pattern)

        if not element then
            return
        end

        local next_element = element:next_named_sibling()

        if type(expected_sibling_name) == "string" then
            if next_element and next_element:type():match(expected_sibling_name) then
                ts.swap_nodes(element, next_element, buffer, true)
            end
        else
            for _, expected in ipairs(expected_sibling_name) do
                if next_element and next_element:type():match(expected) then
                    ts.swap_nodes(element, next_element, buffer, true)
                    return
                end
            end
        end
    end,

    move_item_up = function(pattern, expected_sibling_name, buffer)
        local element = module.private.get_element_from_cursor(pattern)

        if not element then
            return
        end

        local prev_element = element:prev_named_sibling()

        if type(expected_sibling_name) == "string" then
            if prev_element and prev_element:type():match(expected_sibling_name) then
                ts.swap_nodes(element, prev_element, buffer, true)
            end
        else
            for _, expected in ipairs(expected_sibling_name) do
                if prev_element and prev_element:type():match(expected) then
                    ts.swap_nodes(element, prev_element, buffer, true)
                    return
                end
            end
        end
    end,
}

module.public = {
    move_up = function()
        local config = module.config.public.moveables
        local buffer = vim.api.nvim_get_current_buf()

        for _, data in pairs(config) do
            module.private.move_item_up(data[1], data[2], buffer)
        end
    end,

    move_down = function()
        local config = module.config.public.moveables
        local buffer = vim.api.nvim_get_current_buf()

        for _, data in pairs(config) do
            module.private.move_item_down(data[1], data[2], buffer)
        end
    end,

    highlight_node = function(name)
        local textobj_lookup = module.config.private.textobjects[name]

        if textobj_lookup then
            return textobj_lookup(vim.treesitter.get_node())
        end
    end,
}

local function find(node, expected_type)
    while not node:type():match(expected_type) do
        if not node:parent() or node:type() == "document" then
            return
        end

        node = node:parent()
    end

    return node
end

local function find_content(node, expected_type, content_field)
    local heading = find(node, expected_type)

    if not heading then
        return
    end

    local content = heading:field(content_field or "content")

    return #content > 0 and content
end

local function highlight_node(node)
    if not node then
        return
    end

    local range = module.required["core.integrations.treesitter"].get_node_range(node)
    if range.column_end == 0 then
        range.row_end = range.row_end - 1
        range.column_end = vim.api.nvim_buf_get_lines(0, range.row_end, range.row_end + 1, true)[1]:len()
    end
    if range.column_start == vim.api.nvim_buf_get_lines(0, range.row_start, range.row_start + 1, true)[1]:len() then
        range.row_start = range.row_start + 1
        range.column_start = 0
    end

    -- This method of selection is from ts_utils, it avoids a bug with the nvim_buf_set_mark
    -- approach
    local selection_mode = "v"
    local mode = vim.api.nvim_get_mode()
    if mode.mode ~= selection_mode then
        vim.cmd.normal({ selection_mode, bang = true })
    end

    vim.api.nvim_win_set_cursor(0, { range.row_start + 1, range.column_start })
    vim.cmd.normal({ bang = true, args = { "o" } })
    vim.api.nvim_win_set_cursor(0, { range.row_end + 1, range.column_end })
end

module.config.private = {
    textobjects = {
        ["heading.outer"] = function(node)
            return highlight_node(find(node, "^heading%d+$"))
        end,
        ["heading.inner"] = function(node)
            return highlight_node(find_content(node, "^heading%d+$"))
        end,
        ["tag.outer"] = function(node)
            return highlight_node(find(node, "ranged_tag$"))
        end,
        ["tag.inner"] = function(node)
            -- TODO: Fix Treesitter, this is currently buggy
            return highlight_node(find_content(node, "ranged_tag$"))
        end,
        ["list.outer"] = function(node)
            return highlight_node(find(node, "generic_list"))
        end,
    },
}

return module
