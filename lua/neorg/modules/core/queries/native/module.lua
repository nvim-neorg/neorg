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

        local res = module.private.query_from_tree(root_node, tree, bufnr)
        return res
    end,

    --- Extract content from `nodes` of type { node, bufnr }
    --- @param nodes table
    --- @return table
    extract_nodes = function(nodes)
        local res = {}

        for _, node in pairs(nodes) do
            local extracted = ts_utils.get_node_text(node[1], node[2])[1]
            table.insert(res, extracted)
        end
        return res
    end,

    find_parent_node = function (node, node_type)
        local parent = node[1]:parent()
        while parent do
           if parent:type() == node_type then
            break
           end
           parent = parent:parent()
        end
        return { parent, node[2] }
    end
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
    query_from_tree = function(parent, tree, bufnr, results)
        local res = results or {}

        for _, subtree in pairs(tree) do
            local matched = module.private.matching_nodes(parent, subtree)

            -- We extract matching nodes that doesn't have subtree
            if not subtree.subtree then
                for _,v in pairs(matched) do
                    table.insert(res, { v, bufnr })
                end
            else
                for _, node in pairs(matched) do
                    local nodes = module.private.query_from_tree(node, subtree.subtree, bufnr, res)
                    res = vim.tbl_extend("force", res, nodes)
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
        local matched_query = module.private.matching_query(parent, tree.query, { recursive = tree.recursive })

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
    matching_query = function(parent, query, opts)
        opts = opts or {}
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

            if opts.recursive then
                local found = module.private.matching_query(node, query, { recursive = true })
                vim.list_extend(res, found)
            end
        end

        return res
    end,

    --- Checks if `parent` node matches a `where` query and returns a predicate accordingly
    --- @param parent userdata
    --- @param where table
    --- @return boolean
    predicate_where = function(parent, where)
        if not where or #where == 0 then
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
