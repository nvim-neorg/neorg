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

module.public = {
    ---@param invert boolean
    change_list = neorg.utils.wrap_dotrepeat(function(invert)
        local buffer = vim.api.nvim_get_current_buf()
        local cursor = vim.api.nvim_win_get_cursor(0)

        local node = module.required["core.integrations.treesitter"].get_first_node_on_line(
            buffer,
            cursor[1] - 1
        )

        if not node then
            log.error("No node found under the cursor! Make sure your cursor is in a list.")
            return
        end

        node = module.required["core.integrations.treesitter"].find_parent(node, "^generic_list$")

        if not node then
            log.error("No list found under the cursor! `toggle-list-type` works only for lists.")
            return
        end

        local first_child = node:iter_children()()

        if not first_child then
            return
        end

        local type = first_child:type():match("^un") and "~" or "-"

        for child in node:iter_children() do
            if invert then
                type = child:type():match("^un") and "~" or "-"
            end

            -- We loop over every subchild because list items may have attached
            -- weak carryover tags which we have to skip.
            for subchild in child:iter_children() do
                if subchild:type():match("_prefix$") then
                    local line, column = subchild:range()

                    vim.api.nvim_buf_set_text(buffer, line, column, line, column + 1, { type })

                    break
                end
            end
        end
    end),
}

return module
