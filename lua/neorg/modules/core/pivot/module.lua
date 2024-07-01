--[[
    file: Pivot
    title: Ordered or Unordered?
    description: That ~~is~~ was the question. Now you no longer have to ask!
    summary: Toggles the type of list currently under the cursor.
    ---
`core.pivot` allows you to switch (or pivot) between the two list types in Norg with the press of a button.

### Keybinds

This module exposes two keybinds:
- `core.pivot.toggle-list-type` (default binding: `<LocalLeader>lt` ["list toggle"]) - takes a
  list and, based on the opposite type of the first list item, inverts all the other items in that list.
  Does not respect mixed lists, all items in the list will be converted to the same type.
- `core.pivot.invert-list-type` (default binding: `<LocalLeader>li` ["list invert"]) - same behaviour as
  the previous keybind, however respects mixed lists - unordered items will become ordered, whereas ordered
  items will become unordered.
--]]

local neorg = require("neorg.core")
local log, modules = neorg.log, neorg.modules

local module = modules.create("core.pivot")

module.private = {
    ---@param node TSNode
    ---@return string?
    get_list_type = function(node)
        return node:type():match("^(u?n?ordered)_list%d$")
    end,

    ---@param node TSNode
    ---@return number
    get_list_level = function(node)
        local parsed = node:type():match("^u?n?ordered_list(%d)$")
        return parsed and tonumber(parsed) or 0
    end,

    ---@param node TSNode
    get_target_type = function(node)
        local node_type = module.private.get_list_type(node)
        local node_level = module.private.get_list_level(node)

        local target_type = node_type == "unordered" and "~" or "-"

        return target_type:rep(node_level)
    end,

    ---@param bufnr number
    ---@param line number
    ---@return TSNode?
    get_first_node_on_line = function(bufnr, line)
        --- @type TSNode?
        local node = module.required["core.integrations.treesitter"].get_first_node_on_line(bufnr, line - 1)

        if not node or not node:type() then
            return
        end

        -- if generic list take first child in the list
        if node:type() == "generic_list" then
            node = node:child(0)
        end

        return node
    end,
}

module.setup = function()
    return {
        requires = {
            "core.integrations.treesitter",
        },
    }
end

module.load = function()
    modules.await("core.keybinds", function(keybinds)
        keybinds.register_keybinds(module.name, { "toggle-list-type", "invert-list-type" })
    end)
end

module.on_event = function(event)
    if event.split_type[2] == "core.pivot.toggle-list-type" or event.split_type[2] == "core.pivot.invert-list-type" then
        local node = module.private.get_first_node_on_line(event.buffer, event.cursor_position[1])

        if not node then
            log.error("No node found under the cursor! Make sure your cursor is in a list.")
            return
        end

        local parent = module.required["core.integrations.treesitter"].find_parent(node, {
            "^unordered_list%d$",
            "^ordered_list%d$",
            "^generic_list$", -- for level 1 lists the parent is a generic_list
        }, false)

        if not parent then
            log.error("No list found under the cursor! `toggle-list-type` works only for lists.")
            return
        end

        local type = module.private.get_target_type(node)

        for child in parent:iter_children() do
            if event.split_type[2] == "core.pivot.invert-list-type" then
                type = module.private.get_target_type(child)
            end

            -- We loop over every subchild because list items may have attached
            -- weak carryover tags which we have to skip.
            for subchild in child:iter_children() do
                if subchild:type():match("_prefix$") then
                    local line, col_start, _, col_end = subchild:range()

                    vim.api.nvim_buf_set_text(event.buffer, line, col_start, line, col_end - 1, { type })

                    break
                end
            end
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.pivot.toggle-list-type"] = true,
        ["core.pivot.invert-list-type"] = true,
    },
}

return module
