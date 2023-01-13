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
            for _, provider in ipairs(module.config.public.providers) do
                local capture_map = {
                    -- capture_name = node,
                }

                module.required["core.integrations.treesitter"].execute_query(provider.query, function(query, id, node)
                    local capture_name = query.captures[id]
                    capture_map[capture_name] = node
                end)

                provider.callback(capture_map)
            end
        end,
    })
end

module.config.public = {
    providers = {
        ["heading%d"] = {
            query = [[
            ]],
            -- TODO: What should <type> be?
            -- Should the order be:
            -- - Headings aggregate lists
            -- - Lists aggregate sublists
            -- Where they only display their completion if they have aggregated at least one object?
            -- This may complicate things but will make for a better user exp
            callback = module.public.display_todo_completion("(<undone> of <done> <type>) [<percentage>% complete]"),
        },
        ["generic_list"] = {
            query = [[]],
            callback = module.public.display_todo_completion("(<undone>/<done>) [<percentage>%]"),
        },
    },

    anchor_points = {
        "^generic_list$",
    },

    todo_types = {
        "^unordered_list%d$",
        "^ordered_list%d$",
    },
}

module.public = {
    display_todo_completion = function(format)
        return function(capture_map)
        end
    end,

    analyze_todo_completion = function(node, types, callback)
        for child in node:iter_children() do
            local matching_child = neorg.lib.filter(types, function(_, type)
                return child:type():match(type) and child or nil
            end)

            if not matching_child then
                goto continue
            end

            local detached_modifer_extension = matching_child:field("state")[1]

            if not detached_modifer_extension then
                goto continue
            end

            for extension in detached_modifer_extension:iter_children() do
                callback(extension)
            end

            ::continue::
        end
    end,
}

return module
