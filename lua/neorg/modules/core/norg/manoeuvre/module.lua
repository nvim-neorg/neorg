--[[
    File: Norg-Manoeuvre
    Title: Move around elements easily
    Summary: A Neorg module for moving around different elements up and down.
    ---
--]]

-- NOTE(vhyrro): This module is obsolete! There is no successor module to this yet, although
-- we hope to implement one with the module rewrite of 0.2.

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.manoeuvre")

module.setup = function()
    if not require("neorg.external.helpers").is_minimum_version(0, 7, 0) then
        log.error("This module requires at least Neovim 0.7 to run!")

        return {
            success = false,
        }
    end

    return { success = true, requires = { "core.keybinds", "core.integrations.treesitter" } }
end

module.load = function()
    module.required["core.keybinds"].register_keybinds(module.name, {
        "item_up",
        "item_down",
        "textobject.around-heading",
        "textobject.inner-heading",
        "textobject.around-tag",
        "textobject.inner-tag",
        "textobject.around-whole-list",
    })
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

---@class core.norg.manoeuvre
module.public = {
    get_element_from_cursor = function(node_pattern)
        local node_at_cursor = module.required["core.integrations.treesitter"].get_ts_utils().get_node_at_cursor()

        if not node_at_cursor:parent():type():match(node_pattern) then
            log.trace(string.format("Could not find element of pattern '%s' under the cursor", node_pattern))
            return
        end

        return node_at_cursor:parent()
    end,

    move_item_down = function(pattern, expected_sibling_name)
        local element = module.public.get_element_from_cursor(pattern)

        if not element then
            return
        end

        local next_element = element:next_named_sibling()

        if type(expected_sibling_name) == "string" then
            if next_element and next_element:type():match(expected_sibling_name) then
                -- TODO: This is a bit buggy and doesn't always set the cursor position to where you'd expect
                module.required["core.integrations.treesitter"].get_ts_utils().swap_nodes(
                    element,
                    next_element,
                    0,
                    true
                )
            end
        else
            for _, expected in ipairs(expected_sibling_name) do
                if next_element and next_element:type():match(expected) then
                    module.required["core.integrations.treesitter"].get_ts_utils().swap_nodes(
                        element,
                        next_element,
                        0,
                        true
                    )
                    return
                end
            end
        end
    end,

    move_item_up = function(pattern, expected_sibling_name)
        local element = module.public.get_element_from_cursor(pattern)

        if not element then
            return
        end

        local prev_element = element:prev_named_sibling()

        if type(expected_sibling_name) == "string" then
            if prev_element and prev_element:type():match(expected_sibling_name) then
                module.required["core.integrations.treesitter"].get_ts_utils().swap_nodes(
                    element,
                    prev_element,
                    0,
                    true
                )
            end
        else
            for _, expected in ipairs(expected_sibling_name) do
                if prev_element and prev_element:type():match(expected) then
                    module.required["core.integrations.treesitter"].get_ts_utils().swap_nodes(
                        element,
                        prev_element,
                        0,
                        true
                    )
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
        ["around-heading"] = function(node)
            return highlight_node(find(node, "^heading%d+$"))
        end,
        ["inner-heading"] = function(node)
            return highlight_node(find_content(node, "^heading%d+$"))
        end,
        ["around-tag"] = function(node)
            return highlight_node(find(node, "ranged_tag$"))
        end,
        ["inner-tag"] = function(node)
            -- TODO: Fix Treesitter, this is currently buggy
            return highlight_node(find_content(node, "ranged_tag$"))
        end,
        ["around-whole-list"] = function(node)
            return highlight_node(find(node, "generic_list"))
        end,
    },
}

module.on_event = function(event)
    local config = module.config.public.moveables

    if event.split_type[2] == "core.norg.manoeuvre.item_down" then
        for _, data in pairs(config) do
            module.public.move_item_down(data[1], data[2])
        end
    elseif event.split_type[2] == "core.norg.manoeuvre.item_up" then
        for _, data in pairs(config) do
            module.public.move_item_up(data[1], data[2])
        end
    else
        local textobj = event.split_type[2]:find("textobject")

        if textobj then
            local textobject_type = event.split_type[2]:sub(textobj + string.len("textobject") + 1)
            local textobj_lookup = module.config.private.textobjects[textobject_type]

            if textobj_lookup then
                return textobj_lookup(
                    module.required["core.integrations.treesitter"].get_ts_utils().get_node_at_cursor()
                )
            end
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        [module.name .. ".item_down"] = true,
        [module.name .. ".item_up"] = true,

        -- TODO(vhyrro): Automate the creation of these
        [module.name .. ".textobject.around-heading"] = true,
        [module.name .. ".textobject.inner-heading"] = true,

        [module.name .. ".textobject.around-tag"] = true,
        [module.name .. ".textobject.inner-tag"] = true,

        [module.name .. ".textobject.around-whole-list"] = true,
    },
}

return module
