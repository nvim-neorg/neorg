return function(module)
    return {
        --- Get a table of all projects in workspace
        --- @param opts table
        ---   - opts.filename (string):     will restrict the search only for the filename provided
        ---   - opts.extract (bool):        if false will return the nodes instead of the extracted content
        --- @return table
        get_projects = function(opts)
            opts = opts or {}
            local bufnrs = {}
            local res = {}

            local tree = {
                {
                    query = { "first", "document_content" },
                    subtree = {
                        {
                            query = { "all", "heading1" },
                            recursive = true,
                            subtree = {
                                { query = { "all", "paragraph_segment" } },
                            },
                        },
                    },
                },
            }

            if opts.filename then
                local bufnr = module.private.get_bufnr_from_file(opts.filename)
                table.insert(bufnrs, bufnr)
            else
                local files = module.required["core.norg.dirman"].get_norg_files(module.config.public.workspace)
                for _, file in pairs(files) do
                    local bufnr = module.private.get_bufnr_from_file(file)
                    table.insert(bufnrs, bufnr)
                end
            end

            for _, bufnr in pairs(bufnrs) do
                local nodes = module.required["core.queries.native"].query_nodes_from_buf(tree, bufnr)

                if opts.extract == false then
                    vim.list_extend(res, nodes)
                else
                    local extracted = module.required["core.queries.native"].extract_nodes(nodes)
                    vim.list_extend(res, extracted)
                end
            end

            return res
        end,

        --- Gets a bufnr from a relative `file` path
        --- @param file string
        --- @return number
        get_bufnr_from_file = function(file)
            local bufnr = module.required["core.norg.dirman"].get_file_bufnr(
                module.private.workspace_full_path .. "/" .. file
            )
            return bufnr
        end,

        --- Get a table of all tasks in current `state` in workspace
        --- @param state string
        --- @param opts table
        ---   - opts.filename (string):     will restrict the search only for the filename provided
        ---   - opts.recursive (bool):      if true will search todos recursively in the AST
        ---   - opts.extract (bool):        if false will return the nodes instead of the extracted content
        --- @return table
        get_tasks = function(state, opts)
            opts = opts or {}
            local where_statement = {}
            local bufnrs = {}
            local res = {}

            if state then
                where_statement = { "child_exists", "todo_item_" .. state }
            end

            local tree = {
                {
                    query = { "first", "document_content" },
                    subtree = {
                        {
                            query = { "all", "generic_list" },
                            recursive = opts.recursive,
                            subtree = {
                                {
                                    query = { "all", "todo_item1" },
                                    where = where_statement,
                                    subtree = {
                                        { query = { "first", "paragraph" } },
                                    },
                                },
                            },
                        },
                    },
                },
            }

            if opts.filename then
                local bufnr = module.private.get_bufnr_from_file(opts.filename)
                table.insert(bufnrs, bufnr)
            else
                local files = module.required["core.norg.dirman"].get_norg_files(module.config.public.workspace)
                for _, file in pairs(files) do
                    local bufnr = module.private.get_bufnr_from_file(file)
                    table.insert(bufnrs, bufnr)
                end
            end

            for _, bufnr in pairs(bufnrs) do
                local nodes = module.required["core.queries.native"].query_nodes_from_buf(tree, bufnr)

                if opts.extract == false then
                    vim.list_extend(res, nodes)
                else
                    local extracted = module.required["core.queries.native"].extract_nodes(nodes)
                    vim.list_extend(res, extracted)
                end
            end
            return res
        end,

        --- Sort `nodes` by projects.
        --- The returned table is of type { [project_name] = [nodes|extracted_nodes] }
        --- @param nodes table
        --- @param opts table
        ---   - opts.extract (bool):        if false will return the nodes instead of the extracted content
        --- @return table
        sort_by_project = function(nodes, opts)
            opts = opts or {}
            local res = {}
            for _, node in pairs(nodes) do
                local project = module.required["core.queries.native"].find_parent_node(node, "heading1")
                if project[1] then
                    local extracted = module.required["core.queries.native"].extract_nodes({ project })
                    if not res[extracted[1]] then
                        res[extracted[1]] = {}
                    end
                    table.insert(res[extracted[1]], node)
                else
                    if not res["_"] then
                        res["_"] = {}
                    end
                    table.insert(res["_"], node)
                end
            end

            if opts.extract == false then
                return res
            end

            res = vim.tbl_map(module.required["core.queries.native"].extract_nodes, res)

            return res
        end,

        --- Sort `nodes` by contexts.
        --- The returned table is of type { [context_name] = [nodes|extracted_nodes] }
        --- @param nodes table
        --- @param opts table
        ---   - opts.extract (bool):        if false will return the nodes instead of the extracted content
        --- @return table
        sort_by_context = function(nodes, opts)
            opts = opts or {}
            local res = {}
            for _, node in pairs(nodes) do
                -- Assuming i'm sorting tasks nodes
                local parent_node = { node[1]:parent():parent(), node[2] }

                local contexts_node = module.required["core.queries.native"].find_sibling_node(
                    parent_node,
                    "carryover_tag",
                    { where = { "child_name", "tag_name", "contexts" } }
                )
                if contexts_node[1] then
                    local tree = {
                        {
                            query = { "first", "tag_parameters" },
                            subtree = {
                                { query = { "all", "word" } },
                            },
                        },
                    }
                    local contextes = module.required["core.queries.native"].query_from_tree(
                        contexts_node[1],
                        tree,
                        contexts_node[2]
                    )
                    local extracted = module.required["core.queries.native"].extract_nodes(contextes)

                    for _, extracted_context in pairs(extracted) do
                        if not res[extracted_context] then
                            res[extracted_context] = {}
                        end

                        table.insert(res[extracted_context], node)
                    end
                else
                    if not res["_"] then
                        res["_"] = {}
                    end
                    table.insert(res["_"], node)
                end

            end

            if opts.extract == false then
                return res
            end

            res = vim.tbl_map(module.required["core.queries.native"].extract_nodes, res)

            return res
        end,
    }
end
