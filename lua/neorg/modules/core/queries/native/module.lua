--[[
    Module for requesting content from files in a workspace

USAGE:
    - To create a query:
        1. Get a bufnr for a specific file:
            local bufnr = module.required["core.norg.dirman"].get_file_bufnr("index.norg", "gtd")
        2. Extract matching nodes following a tree table
            local res = module.required["core.queries.native"].query_nodes_from_buf(tree, bufnr)
        3. Extract content from extracted nodes
            local extracted = module.required["core.queries.native"].extract_nodes(res, bufnr)
        4. Profit !

--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.queries.native")
local ts_utils = require("nvim-treesitter.ts_utils")

module.public = {
    --- Use a `tree` to query all required nodes from a `bufnr`
    --- @param tree table
    --- @param bufnr number
    --- @return table
    query_nodes_from_buf = function(tree, bufnr)
        local root_node = module.private.get_buf_root_node(bufnr)
        if not root_node then
            return
        end

        local res = module.private.query_from_tree(root_node, tree)
        return res
    end,

    --- Extract content from `nodes` from a `bufnr`
    --- @param nodes table
    --- @param bufnr number
    --- @return table
    extract_nodes = function(nodes, bufnr)
        local res = {}

        for _, node in pairs(nodes) do
            local extracted = ts_utils.get_node_text(node, bufnr)[1]
            table.insert(res, extracted)
        end
        return res
    end,
}

module.private = {
    --- Get the root node from a `bufnr`
    --- @param bufnr number
    --- @return userdata
    get_buf_root_node = function(bufnr)
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
            local matched = module.private.matching_nodes(parent, subtree)

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

    --- Returns a list of child nodes (from `parent`) that matches a `tree`
    --- @param parent userdata
    --- @param tree table
    --- @return table
    matching_nodes = function(parent, tree)
        local res = {}
        local where = tree.where
        local matched_query = module.private.matching_query(parent, tree.query)

        if not where then
            return matched_query
        else
            for _, matched in pairs(matched_query) do
                local matched_where = module.private.predicate_where(matched, where)
                if matched_where then
                    table.insert(res, matched)
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

    --- Checks if `parent` node matches a `where` query and returns a predicate accordingly
    --- @param parent userdata
    --- @param where table
    --- @return boolean
    predicate_where = function(parent, where)
        if not where then
            return true
        end

        -- Where statements requesting children nodes from parent node
        for node in parent:iter_children() do
            if where[1] == "child_exists" then
                if node:type() == where[2] then
                    return true
                end
            end
        end

        return false
    end,
}

return module
