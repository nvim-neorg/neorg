-- [[
-- A Neorg module for moving around different elements up and down
-- ]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.manoeuvre")

module.setup = function()
    return { success = true, requires = { "core.keybinds", "core.integrations.treesitter" } }
end

module.load = function()
    module.required["core.keybinds"].register_keybinds(module.name, { "item_up", "item_down" })
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
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.norg.manoeuvre.item_down"] = true,
        ["core.norg.manoeuvre.item_up"] = true,
    },
}

return module
