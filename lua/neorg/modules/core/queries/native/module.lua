require("neorg.modules.base")

local module = neorg.modules.create("core.queries.native")

module.setup = function()
    return { sucess = true, requires = { "core.norg.dirman" } }
end

module.load = function()
    local tree = {
        {
            query = { "first", "document_content" },
            subtree = {
                {
                    query = { "all", "heading1" },
                    subtree = {
                        {
                            query = { "all", "generic_list" },
                            subtree = {
                                { query = { "all", "todo_item1" } },
                            },
                        },
                    },
                },
            },
        },
    }
    local res = module.public.query_from_file("index.norg", "gtd", tree)
    log.warn(res)
end

module.public = {
    --- Use a `tree` to query all required nodes from a `file` in a `workspace`
    --- @param file string
    --- @param workspace string
    --- @param tree table
    --- @return table
    query_from_file = function(file, workspace, tree)
        local root_node = module.private.get_file_root_node(file, workspace)
        if not root_node then
            return
        end

        local res = module.private.query_from_tree(root_node, tree)
        return res
    end,
}

module.private = {
    --- Get the root node from a `file` in a neorg `workspace`
    --- @param file string
    --- @param workspace_name string
    --- @return userdata
    get_file_root_node = function(file, workspace_name)
        local bufnr = module.required["core.norg.dirman"].get_file_bufnr(file, workspace_name)

        if not bufnr then
            return
        end

        local parser = vim.treesitter.get_parser(bufnr, "norg")
        local tstree = parser:parse()[1]
        return tstree:root()
    end,

    --- Recursively generates results from a `parent` node, following a `tree` table
    --- @see First implementation in: https://github.com/danymat/neogen/blob/main/lua/neogen/utilities/nodes.lua
    --- @param parent userdata
    --- @param tree table
    --- @param results table|nil
    --- @return table
    query_from_tree = function(parent, tree, results)
        local res = results or {}

        for _, subtree in pairs(tree) do
            local matched = module.private.matching_query(parent, subtree.query)

            -- We extract matching nodes that doesn't have subtree
            if not subtree.subtree then
                res = vim.list_extend(res, matched)
            else
                for _, node in pairs(matched) do
                    local nodes = module.private.query_from_tree(node, subtree.subtree, res)
                    res = vim.tbl_deep_extend("force", res, nodes)
                end
            end
        end
        return res
    end,

    --- Get a list of child nodes (from `parent`) that match the provided `query`
    --- @see First implementation in: https://github.com/danymat/neogen/blob/main/lua/neogen/utilities/nodes.lua
    --- @param parent userdata
    --- @param query table
    --- @return table
    matching_query = function(parent, query)
        local res = {}

        if #query < 2 then
            return
        end

        for node in parent:iter_children() do
            if node:type() == query[2] then
                -- query : { "first", "node_name"} first child node that match node_name
                if query[1] == "first" then
                    table.insert(res, node)
                    break
                    -- query : { "match", "node_name", "test" } all node_name nodes that match "test" content
                elseif query[1] == "match" then
                    -- TODO Match node content
                    -- query : { "all", "node_name" } all child nodes that match node_name
                elseif query[1] == "all" then
                    table.insert(res, node)
                end
            end
        end

        return res
    end,
}

return module
