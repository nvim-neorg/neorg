return function(module)
    return {
        --- Get a table of all projects in workspace
        --- @param opts table
        ---   - opts.filename (string):     will restrict the search only for the filename provided
        ---   - opts.extract (bool):        if false will return the nodes instead of the extracted content
        ---   - opts.exclude_files (table):     will exclude files from workspace in querying information
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

                if opts.exclude_files then
                    for _, excluded_file in pairs(opts.exclude_files) do
                        files = module.private.remove_from_table(files, excluded_file)
                    end
                end

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
        ---   - opts.filename (string):         will restrict the search only for the filename provided
        ---   - opts.recursive (bool):          if true will search todos recursively in the AST
        ---   - opts.extract (bool):            if false will return the nodes instead of the extracted content
        ---   - opts.exclude_files (table):     will exclude files from workspace in querying information
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

                if opts.exclude_files then
                    for _, excluded_file in pairs(opts.exclude_files) do
                        files = module.private.remove_from_table(files, excluded_file)
                    end
                end

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

        remove_from_table = function(t, el)
            for i, v in ipairs(t) do
                if v == el then
                    local removed = table.remove(t, i)
                    break
                end
            end
            return t
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
                    local tree = {
                        { query = { "all", "paragraph_segment" } },
                    }
                    local project_content = module.required["core.queries.native"].query_from_tree(
                        project[1],
                        tree,
                        project[2]
                    )
                    local extracted = module.required["core.queries.native"].extract_nodes(project_content)
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
            local insert_node_at_void = function(node, t)
                if not t["_"] then
                    t["_"] = {}
                end
                table.insert(t["_"], node)
                return t
            end

            for _, node in pairs(nodes) do
                -- Find the first parent node that match carryover_tag_set
                local tags_node = module.required["core.queries.native"].find_parent_node(node, "carryover_tag_set")

                -- There's no tag in one of parent's node of the current node
                if not tags_node[1] then
                    insert_node_at_void(node, res)
                else
                    local tree = {
                        {
                            query = { "all", "carryover_tag" },
                            where = { "child_content", "tag_name", "contexts" },
                            subtree = {
                                {
                                    query = { "all", "tag_parameters" },
                                    subtree = {
                                        { query = { "all", "word" } },
                                    },
                                },
                            },
                        },
                    }

                    local contexts = module.required["core.queries.native"].query_from_tree(
                        tags_node[1],
                        tree,
                        tags_node[2]
                    )

                    if #contexts == 0 then
                        insert_node_at_void(node, res)
                    else
                        local extracted = module.required["core.queries.native"].extract_nodes(contexts)

                        for _, extracted_context in pairs(extracted) do
                            if not res[extracted_context] then
                                res[extracted_context] = {}
                            end

                            table.insert(res[extracted_context], node)
                        end
                    end
                end
            end

            if opts.extract == false then
                return res
            end

            res = vim.tbl_map(module.required["core.queries.native"].extract_nodes, res)

            return res
        end,

        --- Filter `nodes` by today tasks
        --- @param nodes userdata
        --- @param opts table
        ---   - opts.extract (bool):        if false will return the nodes instead of the extracted content
        --- @return table
        filter_today = function(nodes, opts)
            opts = opts or {}
            local today_tag = "today"
            local nodes_by_context = module.private.sort_by_context(nodes, { extract = false })

            if not nodes_by_context[today_tag] then
                nodes_by_context[today_tag] = {}
            end

            if opts.extract == false then
                return nodes_by_context[today_tag]
            end

            local today_tasks = module.required["core.queries.native"].extract_nodes(nodes_by_context[today_tag])
            return today_tasks
        end,

        --- Filter tasks `nodes` with `tag_name`
        --- @param nodes table
        --- @param opts table
        ---   - opts.extract (bool):        if false will return the nodes instead of the extracted content
        --- @return table
        filter_tags = function(nodes, tag_name, opts)
            opts = opts or {}
            local res = {}

            for _, node in pairs(nodes) do
                -- Find the first parent node that match carryover_tag_set
                local tags_node = module.required["core.queries.native"].find_parent_node(node, "carryover_tag_set")

                local tree = {
                    {
                        query = { "all", "carryover_tag" },
                        where = { "child_content", "tag_name", tag_name },
                        subtree = {
                            {
                                query = { "all", "tag_parameters" },
                                subtree = {
                                    { query = { "all", "word" } },
                                },
                            },
                        },
                    },
                }

                local found_tags = module.required["core.queries.native"].query_from_tree(
                    tags_node[1],
                    tree,
                    tags_node[2]
                )

                if #found_tags ~= 0 then
                    local extracted = module.required["core.queries.native"].extract_nodes(found_tags)

                    for _, extracted_context in pairs(extracted) do
                        if not res[extracted_context] then
                            res[extracted_context] = {}
                        end

                        table.insert(res[extracted_context], node)
                    end
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
