--[[
    file: Todo-Introspector
    title: Todo Introspection in Neorg
    summary: Analyzes and displays todo completion levels in Neorg buffers.
--]]

local module = neorg.modules.create("core.todo-introspector")

module.setup = function()
    return {
        requires = { "core.integrations.treesitter" },
    }
end

module.load = function()
    vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "*.norg",
        callback = function()
            for _, provider in pairs(module.config.public.providers) do
                local capture_map = {
                    -- capture_name = node,
                }

                module.required["core.integrations.treesitter"].execute_query(provider.query, function(query, id, node)
                    local capture_name = query.captures[id]

                    capture_map[capture_name] = node

                    if capture_name == "target" then
                        local aggregates = provider.aggregate(capture_map)

                        if aggregates and provider.display then
                            provider.display(aggregates)
                        end

                        capture_map = {}
                    end
                end)
            end
        end,
    })
end

module.public = {
    aggregate_recursively = function(callback)
        return function(capture_map)
            local parent_node = capture_map.target

            if not parent_node then
                return
            end

            local aggregates = {}

            aggregates.self = neorg.lib.eval(callback, parent_node) or {}

            for child in parent_node:iter_children() do
                for pattern, data in pairs(module.config.public.providers) do
                    if child:type():match(table.concat({ "^", pattern, "$" })) then
                        aggregates[child:type()] = aggregates[child:type()] or {}

                        table.insert(
                            aggregates[child:type()],
                            vim.tbl_deep_extend("force", data.aggregate({
                                target = child,
                            }) or {}, neorg.lib.eval(callback, child) or {})
                        )
                    end
                end
            end

            return not vim.tbl_isempty(aggregates) and { [parent_node:type()] = aggregates } or nil
        end
    end,

    aggregate_functions = {
        generic_list = function(node)
            local info = {
                -- undone = 0,
                -- done = 0,
                -- pending = 0,
                -- urgent = 0,
                -- cancelled = 0,
                -- on_hold = 0,
                -- recurring = 0,
            }

            for child in node:iter_children() do
                local detached_modifier_extension = child:field("state")[1]

                if not detached_modifier_extension then
                    goto continue
                end

                local todo_node = nil

                do
                    for task in detached_modifier_extension:iter_children() do
                        if vim.startswith(task:type(), "todo_item_") then
                            todo_node = task
                            break
                        end
                    end
                end

                if not todo_node then
                    goto continue
                end

                local todo_item_type = todo_node:type():match("^todo_item_(.+)$")
                info[todo_item_type] = (info[todo_item_type] or 0) + 1

                ::continue::
            end

            return {
                task_info = info,
            }
        end,
    },
}

module.config.public = {
    providers = {
        ["heading%d"] = {
            query = [=[
            [
                (heading1)
                (heading2)
                (heading3)
                (heading4)
                (heading5)
                (heading6)
            ] @target
            ]=],
            aggregate = module.public.aggregate_recursively(),
            display = module.public.display_heading_completion(),
        },
        ["generic_list"] = {
            query = [[(generic_list) @target]],
            aggregate = module.public.aggregate_recursively(module.public.aggregate_functions.generic_list),
        },
    },
}

return module
