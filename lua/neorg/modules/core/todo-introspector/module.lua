--[[
    file: Todo-Introspector
    title: Displays how many subtasks are done in a task
    summary: Module for displaying progress of completed subtasks in the virtual line.
    ---

When a todo list item has a list of subtasks this module enables virtual text in the top level item and displays the
progress of the subtasks. By default it displays in the format of [completed/total] (progress%).
--]]
local neorg = require("neorg")
local modules = neorg.modules

local module = modules.create("core.todo-introspector")

module.private = {
    namespace = vim.api.nvim_create_namespace("neorg/todo-introspector"),

    --- List of active buffers
    buffers = {},
}

---@class core.todo-introspector
module.config.public = {

    -- Highlight group to display introspector in.
    --
    -- Defaults to "Normal".
    highlight_group = "Normal",

    -- Which status types to count towards the totol.
    --
    -- Defaults to the following: `done`, `pending`, `undone`, `urgent`.
    counted_statuses = {
        "done",
        "pending",
        "undone",
        "urgent",
    },

    -- Which status should count towards the completed count (should be a subset of counted_statuses).
    --
    -- Defaults to the following: `done`.
    completed_statuses = {
        "done",
    },

    -- Callback to format introspector. Takes in two parameters:
    -- * `completed`: number of completed tasks
    -- * `total`: number of total counted tasks
    --
    -- Should return a string with the format you want to display the introspector in.
    --
    -- Defaults to "[completed/total] (progress%)"
    format = function(completed, total)
        -- stylua: ignore start
        return string.format(
            "[%d/%d] (%d%%)",
            completed,
            total,
            (total ~= 0 and math.floor((completed / total) * 100) or 0)
        )
        -- stylua: ignore end
    end,
}

module.setup = function()
    return {
        requires = { "core.integrations.treesitter" },
    }
end

module.load = function()
    vim.api.nvim_create_autocmd("Filetype", {
        pattern = "norg",
        desc = "Attaches the TODO introspector to any Norg buffer.",
        callback = function(ev)
            local buf = ev.buf

            if module.private.buffers[buf] then
                return
            end

            module.private.buffers[buf] = true
            module.public.attach_introspector(buf)
        end,
    })
end

--- Attaches the introspector to a given Norg buffer.
--- Errors if the target buffer is not a Norg buffer.
---@param buffer number #The buffer ID to attach to.
function module.public.attach_introspector(buffer)
    if not vim.api.nvim_buf_is_valid(buffer) or vim.bo[buffer].filetype ~= "norg" then
        error(string.format("Could not attach to buffer %d, buffer is not a norg file!", buffer))
    end

    module.required["core.integrations.treesitter"].execute_query(
        [[
    (_
      state: (detached_modifier_extension)) @item
    ]],
        function(query, id, node)
            if query.captures[id] == "item" then
                module.public.perform_introspection(buffer, node)
            end
        end,
        buffer
    )

    vim.api.nvim_buf_attach(buffer, false, {
        on_lines = vim.schedule_wrap(function(_, buf, _, first)
            if not vim.api.nvim_buf_is_valid(buf) then
                return
            end
            -- If we delete the last line of a file `first` will point to a nonexistent line
            -- For this reason we fall back to the line count (accounting for 0-based indexing)
            -- whenever a change to the document is made.
            first = math.min(first, vim.api.nvim_buf_line_count(buf) - 1)

            ---@type TSNode?
            local node = module.required["core.integrations.treesitter"].get_first_node_on_line(buf, first)

            if not node then
                return
            end

            vim.api.nvim_buf_clear_namespace(buffer, module.private.namespace, first + 1, first + 1)

            local function introspect(start_node)
                local parent = start_node

                while parent do
                    local child = parent:named_child(1)

                    if child and child:type() == "detached_modifier_extension" then
                        module.public.perform_introspection(buffer, parent)
                        -- NOTE: do not break here as we want the introspection to propagate all the way up the syntax tree
                    end

                    parent = parent:parent()
                end
            end

            introspect(node)

            local node_above = module.required["core.integrations.treesitter"].get_first_node_on_line(buf, first - 1)

            do
                local todo_status = node_above:named_child(1)

                if todo_status and todo_status:type() == "detached_modifier_extension" then
                    introspect(node_above)
                end
            end
        end),

        on_detach = function()
            vim.api.nvim_buf_clear_namespace(buffer, module.private.namespace, 0, -1)
            module.private.buffers[buffer] = nil
        end,
    })
end

--- Aggregates TODO item counts from children.
---@param node TSNode
---@return number completed Total number of completed tasks
---@return number total Total number of counted tasks
function module.public.calculate_items(node)
    local counts = {}
    for _, status in ipairs(module.config.public.counted_statuses) do
        counts[status] = 0
    end

    local total = 0

    -- Go through all the children of the current todo item node and count the amount of "done" children
    for child in node:iter_children() do
        if child:named_child(1) and child:named_child(1):type() == "detached_modifier_extension" then
            for status in child:named_child(1):iter_children() do
                if status:type():match("^todo_item_") then
                    local type = status:type():match("^todo_item_(.+)$")

                    if not counts[type] then
                        break
                    end

                    counts[type] = counts[type] + 1
                    total = total + 1
                end
            end
        end
    end

    local completed = 0
    for _, status in ipairs(module.config.public.completed_statuses) do
        if counts[status] then
            completed = completed + counts[status]
        end
    end

    return completed, total
end

--- Displays the amount of done items in the form of an extmark.
---@param buffer number
---@param node TSNode
function module.public.perform_introspection(buffer, node)
    local completed, total = module.public.calculate_items(node)

    local line, col = node:start()

    vim.api.nvim_buf_clear_namespace(buffer, module.private.namespace, line, line + 1)

    if total == 0 then
        return
    end

    vim.api.nvim_buf_set_extmark(buffer, module.private.namespace, line, col, {
        virt_text = {
            {
                module.config.public.format(completed, total),
                module.config.public.highlight_group,
            },
        },
        invalidate = true,
    })
end

return module
