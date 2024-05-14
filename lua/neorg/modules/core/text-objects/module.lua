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
["core.keybinds"] = {
    config = {
        hook = function(keybinds)
            -- Binds to move items up or down
            keybinds.remap_event("norg", "n", "<up>", "core.text-objects.item_up")
            keybinds.remap_event("norg", "n", "<down>", "core.text-objects.item_down")

            -- text objects, these binds are available as `vaH` to "visual select around a header" or
            -- `diH` to "delete inside a header"
            keybinds.remap_event("norg", { "o", "x" }, "iH", "core.text-objects.textobject.heading.inner")
            keybinds.remap_event("norg", { "o", "x" }, "aH", "core.text-objects.textobject.heading.outer")
        end,
    },
},
```

--]]

local neorg = require("neorg.core")
local utils, log, modules = neorg.utils, neorg.log, neorg.modules
local ts

local module = modules.create("core.text-objects")

module.setup = function()
    if not utils.is_minimum_version(0, 7, 0) then
        log.error("This module requires at least Neovim 0.7 to run!")

        return {
            success = false,
        }
    end

    return {
        success = true,
        requires = { "core.keybinds", "core.integrations.treesitter" },
    }
end

-- TODO: what's a better name for this?
local tags = {
    "item_up",
    "item_down",
    "textobject.heading.outer",
    "textobject.heading.inner",
    "textobject.tag.inner",
    "textobject.tag.outer",
    "textobject.list.outer",
}

module.load = function()
    module.required["core.keybinds"].register_keybinds(module.name, tags)
    ts = module.required["core.integrations.treesitter"]
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
module.public = {
    get_element_from_cursor = function(node_pattern)
        local node_at_cursor = vim.treesitter.get_node()

        if not node_at_cursor:parent():type():match(node_pattern) then
            log.trace(string.format("Could not find element of pattern '%s' under the cursor", node_pattern))
            return
        end

        return node_at_cursor:parent()
    end,

    move_item_down = function(pattern, expected_sibling_name, buffer)
        local element = module.public.get_element_from_cursor(pattern)

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
        local element = module.public.get_element_from_cursor(pattern)

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

    vim.api.nvim_buf_set_mark(0, "<", range.row_start + 1, range.column_start, {})
    vim.api.nvim_buf_set_mark(0, ">", range.row_end + 1, range.column_end, {})
    vim.cmd("normal! gv")
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

---Handle events
---@param event neorg.event
module.on_event = function(event)
    local config = module.config.public.moveables

    if event.split_type[2] == "core.text-objects.item_down" then
        for _, data in pairs(config) do
            module.public.move_item_down(data[1], data[2], event.buffer)
        end
    elseif event.split_type[2] == "core.text-objects.item_up" then
        for _, data in pairs(config) do
            module.public.move_item_up(data[1], data[2], event.buffer)
        end
    else
        local textobj = event.split_type[2]:find("textobject")

        if textobj then
            local textobject_type = event.split_type[2]:sub(textobj + string.len("textobject") + 1)
            local textobj_lookup = module.config.private.textobjects[textobject_type]

            if textobj_lookup then
                return textobj_lookup(vim.treesitter.get_node())
            end
        end
    end
end

module.events.subscribed = { ["core.keybinds"] = {} }
for _, name in ipairs(tags) do
    module.events.subscribed["core.keybinds"][("%s.%s"):format(module.name, name)] = true
end

return module
