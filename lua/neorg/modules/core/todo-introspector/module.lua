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
                module.required["core.integrations.treesitter"].execute_query(provider.query, function(query, id, node)
                    local capture_name = query.captures[id]

                    if capture_name == "target" then
                        local aggregates = provider.aggregate({ target = node })

                        if aggregates and provider.display then
                            provider.display(aggregates)
                        end
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

            return not vim.tbl_isempty(aggregates) and aggregates or nil
        end
    end,

    aggregate_functions = {
        list_item = function(node)
            local detached_modifier_extension = node:field("state")[1]

            if not detached_modifier_extension then
                return {}
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
                return {}
            end

            return { todo_node:type():match("^todo_item_(.+)$") }
        end,
    },

    display_heading_completion = function(aggregates)
        do
            log.warn(aggregates)
        end
    end,
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
            display = module.public.display_heading_completion,
        },
        ["generic_list"] = {
            query = [[(generic_list) @target]],
            aggregate = module.public.aggregate_recursively(),
        },
        ["unordered_list%d"] = {
            query = [=[
                [
                    (unordered_list1)
                    (unordered_list2)
                    (unordered_list3)
                    (unordered_list4)
                    (unordered_list5)
                    (unordered_list6)
                    (ordered_list1)
                    (ordered_list2)
                    (ordered_list3)
                    (ordered_list4)
                    (ordered_list5)
                    (ordered_list6)
                ] @target
            ]=],
            aggregate = module.public.aggregate_recursively(module.public.aggregate_functions.list_item),
        },
    },

    detail = {
        ["heading%d"] = "high",
        -- TODO: Implement high detail level for unordered lists
        ["unordered_list%d"] = "low",
    },
}

return module
