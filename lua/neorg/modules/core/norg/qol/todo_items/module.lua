--[[
    file: Todo-Items
    title: Todo Item Swiss Army Knife
    summary: Module for implementing todo lists.
    ---
This module handles the whole concept of toggling TODO items, as well as updating
parent and/or children items alongside the current item.

The following keybinds are exposed:
- `core.norg.qol.todo_items.todo.task_done` (`gtd`)
- `core.norg.qol.todo_items.todo.task_undone` (`gtu`)
- `core.norg.qol.todo_items.todo.task_pending` (`gtp`)
- `core.norg.qol.todo_items.todo.task_on_hold` (`gth`)
- `core.norg.qol.todo_items.todo.task_cancelled` (`gtc`)
- `core.norg.qol.todo_items.todo.task_recurring` (`gtr`)
- `core.norg.qol.todo_items.todo.task_important` (`gti`)
- `core.norg.qol.todo_items.todo.task_cycle` (`<C-Space>`)
- `core.norg.qol.todo_items.todo.task_cycle_reverse` (no default keybind)

With your cursor on a line that contains an item with a TODO attribute, press
any of the above keys to toggle the state of that particular item.
Parent items of the same type and children items of the same type are update accordingly.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.qol.todo_items")

module.setup = function()
    return { success = true, requires = { "core.keybinds", "core.integrations.treesitter" } }
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

module.config.public = {
    -- The order of cycling between todo items.
    order = {
        { "undone", " " },
        { "done", "x" },
        { "pending", "-" },
    },
}

---@class core.norg.qol.todo_items
module.public = {
    --- Updates the parent todo item for the current todo item if it exists
    ---@param recursion_level number the index of the parent to change. The higher the number the more the code will traverse up the syntax tree.
    update_parent = function(buf, line, recursion_level)
        -- Force a reparse (this is required because otherwise some cached nodes will be incorrect)
        vim.treesitter.get_parser(buf, "norg"):parse()

        -- If present grab the list item that is under the cursor
        local item_at_cursor = module.public.get_list_item_from_cursor(buf, line)

        -- If we didn't manage to grab any valid item then return
        if not item_at_cursor then
            return
        end

        -- If we set a recursion level then go through and traverse up the syntax tree `recursion_level` times
        for _ = 0, recursion_level do
            item_at_cursor = item_at_cursor:parent()
        end

        -- If the list node isn't present or if the list element's type isn't a todo_item then return
        if not item_at_cursor then
            return
        end

        if
            not item_at_cursor:named_child(1)
            or item_at_cursor:named_child(1):type() ~= "detached_modifier_extension"
        then
            return
        end

        local counts = {
            undone = 0,
            pending = 0,
            done = 0,
            cancelled = 0,
            recurring = 0,
            on_hold = 0,
            urgent = 0,
            uncertain = 0,
        }
        local counter = 0

        -- Go through all the children of the current todo item node and count the amount of "done" children
        for node in item_at_cursor:iter_children() do
            if node:named_child(1) and node:named_child(1):type() == "detached_modifier_extension" then
                for status in node:named_child(1):iter_children() do
                    if status:type():match("^todo_item_") then
                        local type = status:type():match("^todo_item_(.+)$")

                        counts[type] = counts[type] + 1

                        if type == "cancelled" then
                            break
                        end

                        counter = counter + 1
                    end
                end
            end
        end

        -- [[
        --  Compare the counter to the amount of done items.
        --  If we have even one pending item then set the resulting char to `*`
        --  If the counter is the same as the done item count then that means all items are complete and we should display a done item in the parent.
        --  If the done item count is 0 then no task has been completed and we should set an undone item as the parent.
        --  If all other checks fail and the done item count is less than the total number of todo items then set a pending item.
        -- ]]

        if counter == 0 then
            return
        end

        local resulting_char = ""

        if counts.pending > 0 then
            resulting_char = "-"
        elseif counter == counts.done then
            resulting_char = "x"
        elseif counts.done == 0 then
            resulting_char = " "
        elseif counts.done < counter then
            resulting_char = "-"
        end

        local first_status_extension = module.public.find_first_status_extension(item_at_cursor:named_child(1))

        -- TODO(vhyrro):
        -- Implement a toggleable behaviour where Neorg can automatically convert this:
        --     * (@ Mon 5th Feb) Test
        --     ** ( ) Test
        -- To this:
        --     * (x|@ Mon 5th Feb) Test
        --     ** (x) Test
        if not first_status_extension then
            return
        end

        local range = module.required["core.integrations.treesitter"].get_node_range(first_status_extension)

        -- Replace the line where the todo item is situated
        vim.api.nvim_buf_set_text(
            buf,
            range.row_start,
            range.column_start,
            range.row_end,
            range.column_end,
            { resulting_char }
        )

        module.public.update_parent(buf, line, recursion_level + 1)
    end,

    --- Find the first occurence of a status extension within a detached
    --  modifier extension node.
    ---@param detached_modifier_extension_node userdata #A valid node of type `detached_modifier_extension`
    find_first_status_extension = function(detached_modifier_extension_node)
        if not detached_modifier_extension_node then
            return
        end

        for status in detached_modifier_extension_node:iter_children() do
            if vim.startswith(status:type(), "todo_item_") then
                return status
            end
        end
    end,

    --- Tries to locate a todo_item node under the cursor
    ---@return userdata nil if no such node could be found else returns the todo_item node
    get_list_item_from_cursor = function(buf, line)
        local node_at_cursor = module.required["core.integrations.treesitter"].get_first_node_on_line(buf, line)

        if not node_at_cursor then
            return
        end

        -- This is done because sometimes the first node can be
        -- e.g `generic_list`, which only contains the top level list items and
        -- not their data. It doesn't cost us much to do this operation for other
        -- nodes anyway.
        if node_at_cursor:named_child(0) then
            node_at_cursor = node_at_cursor:named_child(0)
        end

        while true do
            if not node_at_cursor then
                log.trace("Could not find TODO item under cursor, aborting...")
                return
            end

            local second_named_child = node_at_cursor:named_child(1)

            if second_named_child and second_named_child:type() == "detached_modifier_extension" then
                break
            else
                node_at_cursor = node_at_cursor:parent()
            end
        end

        return node_at_cursor
    end,

    --- Returns the type of a todo item (either "done", "pending" or "undone")
    ---@param todo_node userdata the todo node to extract the data from
    ---@return string one of "done", "pending" or "undone" or an empty string if an error occurred
    get_todo_item_type = function(todo_node)
        if not todo_node or not todo_node:named_child(1) then
            return ""
        end

        local todo_type = module.public.find_first_status_extension(todo_node:named_child(1))

        return todo_type and todo_type:type():sub(string.len("todo_item_") + 1) or ""
    end,

    --- Converts the current node and all its children to a certain type
    ---@param buf number the current buffer number
    ---@param node userdata the node to modify
    ---@param todo_item_type string one of "done", "pending" or "undone"
    ---@param char string the character to place within the square brackets of the todo item (one of "x", "*" or " ")
    make_all = function(buf, node, todo_item_type, char)
        if not node then
            return
        end

        local function update(child)
            local first_status_extension = module.public.find_first_status_extension(child:named_child(1))

            if not first_status_extension then
                return
            end

            local range = module.required["core.integrations.treesitter"].get_node_range(first_status_extension)

            vim.api.nvim_buf_set_text(
                buf,
                range.row_start,
                range.column_start,
                range.row_end,
                range.column_end,
                { char }
            )
        end

        local type = node:type():match("^(.+)%d+$")

        -- If the type of the current todo item differs from the one we want to change to then
        -- We do this because we don't want to be unnecessarily modifying a line that doesn't need changing
        if module.public.get_todo_item_type(node) ~= todo_item_type then
            update(node)

            for child in node:iter_children() do
                if type == child:type():match("^(.+)%d+$") then
                    update(child)
                    module.public.make_all(buf, child, todo_item_type, char)
                end
            end
        end
    end,

    task_cycle = function(buf, linenr, types)
        local todo_item_at_cursor = module.public.get_list_item_from_cursor(buf, linenr - 1)
        local todo_item_type = module.public.get_todo_item_type(todo_item_at_cursor)

        --- Gets the next item of a flat list based on the first item
        ---@param type_list list #A list of { "type", "char" } items
        ---@param item_type string #The `type` field from the `type_list` array
        ---@return number #An index into the next item of `type_list`
        local function get_index(type_list, item_type)
            for i, element in ipairs(type_list) do
                if element[1] == item_type then
                    if i >= #type_list then
                        return 1
                    else
                        return i + 1
                    end
                end
            end
        end

        local index = get_index(types, todo_item_type)

        local next = types[index] or types[1]

        for child in todo_item_at_cursor:iter_children() do
            if module.public.get_todo_item_type(child) ~= "" then
                if (index + 1) >= #types then
                    next = types[#types - index + 1]
                else
                    next = types[index + 1]
                end
                break
            end
        end

        module.public.make_all(buf, todo_item_at_cursor, next[1], next[2])
        module.public.update_parent(buf, linenr - 1, 0)
    end,
}

module.on_event = function(event)
    local todo_str = "core.norg.qol.todo_items.todo."

    if event.split_type[1] == "core.keybinds" then
        local todo_item_at_cursor = module.public.get_list_item_from_cursor(event.buffer, event.cursor_position[1] - 1)

        if not todo_item_at_cursor then
            return
        end

        local map_of_names_to_symbols = {
            undone = " ",
            pending = "-",
            on_hold = "=",
            cancelled = "_",
            done = "x",
            important = "!",
            recurring = "+",
        }

        local match = event.split_type[2]:match(todo_str .. "task_(.+)")

        if match and match ~= "cycle" and match ~= "cycle_reverse" then
            module.public.make_all(
                event.buffer,
                todo_item_at_cursor,
                match,
                map_of_names_to_symbols[match] or "<unsupported>"
            )
            module.public.update_parent(event.buffer, event.cursor_position[1] - 1, 0)
        elseif event.split_type[2] == todo_str .. "task_cycle" then
            module.public.task_cycle(event.buffer, event.cursor_position[1], module.config.public.order)
        elseif event.split_type[2] == todo_str .. "task_cycle_reverse" then
            module.public.task_cycle(event.buffer, event.cursor_position[1], vim.fn.reverse(module.config.public.order))
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.norg.qol.todo_items.todo.task_done"] = true,
        ["core.norg.qol.todo_items.todo.task_undone"] = true,
        ["core.norg.qol.todo_items.todo.task_pending"] = true,
        ["core.norg.qol.todo_items.todo.task_on_hold"] = true,
        ["core.norg.qol.todo_items.todo.task_cancelled"] = true,
        ["core.norg.qol.todo_items.todo.task_important"] = true,
        ["core.norg.qol.todo_items.todo.task_recurring"] = true,
        ["core.norg.qol.todo_items.todo.task_cycle"] = true,
        ["core.norg.qol.todo_items.todo.task_cycle_reverse"] = true,
    },
}

return module
