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
local log, modules, lib = neorg.log, neorg.modules, neorg.lib

local module = modules.create("core.pivot")

module.setup = function()
    return {
        requires = {
            "core.integrations.treesitter",
        },
    }
end

module.load = function()
    vim.keymap.set("", "<Plug>(neorg.pivot.list.toggle)", lib.wrap(module.public.change_list, false))
    vim.keymap.set("", "<Plug>(neorg.pivot.list.invert)", lib.wrap(module.public.change_list, true))
end

module.private = {
    --- Return current node we are on, accounting for possible root of list
    ---@param bufnr integer
    ---@return TSNode?
    get_current_node = function(bufnr)
        local cursor = vim.api.nvim_win_get_cursor(0)
        local node = module.required["core.integrations.treesitter"].get_first_node_on_line(bufnr, cursor[1] - 1)

        -- if on root of the list we are actually interested in the first list item not the generic_list node
        if node and node:type() == "generic_list" then
            node = node:child(0)
        end

        return node
    end,

    ---@param node TSNode
    ---@return TSNode?
    get_parent_list = function(node)
        local parent = node:parent()

        return module.required["core.integrations.treesitter"].find_parent(parent, {
            "generic_list",
            "unordered_list1",
            "unordered_list2",
            "unordered_list3",
            "unordered_list4",
            "unordered_list5",
            "unordered_list6",
            "ordered_list1",
            "ordered_list2",
            "ordered_list3",
            "ordered_list4",
            "ordered_list5",
            "ordered_list6",
        })
    end,

    --- Returns the prefix the current list node should be toggled to
    ---@param node TSNode
    ---@return string
    get_target_prefix = function(node)
        local type = node:type():match("^un") and "~" or "-"
        local level = tonumber(node:type():match("ordered_list(%d)")) or 0

        return type:rep(level)
    end,
}

---@class core.pivot
module.public = {
    ---@param invert boolean
    change_list = neorg.utils.wrap_dotrepeat(function(invert)
        local buffer = vim.api.nvim_get_current_buf()

        local node = module.private.get_current_node(buffer)

        if not node then
            log.error("No node found under the cursor! Make sure your cursor is in a list.")
            return
        end

        local parent_list = module.private.get_parent_list(node)

        if not parent_list then
            log.error("No list found under the cursor! `toggle-list-type` and `invert-list-type` only work for lists.")
            return
        end

        local first_child = parent_list:iter_children()()

        if not first_child then
            return
        end

        local target_prefix = module.private.get_target_prefix(node)

        for child in parent_list:iter_children() do
            if invert then
                target_prefix = module.private.get_target_prefix(child)
            end

            -- We loop over every subchild because list items may have attached
            -- weak carryover tags which we have to skip.
            for subchild in child:iter_children() do
                if subchild:type():match("_prefix$") then
                    local line, col_start, _, col_end = subchild:range()

                    vim.api.nvim_buf_set_text(buffer, line, col_start, line, col_end - 1, { target_prefix })
                    break
                end
            end
        end
    end),
}

return module
