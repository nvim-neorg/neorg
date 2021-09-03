return function(module)
    return {
        --- Get a table of all projects in workspace
        --- @param opts table
        ---   - opts.filename (string):   will restrict the search only for the filename provided
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
                local extracted = module.required["core.queries.native"].extract_nodes(nodes, bufnr)
                vim.list_extend(res, extracted)
            end

            return res
        end,

        get_bufnr_from_file = function(file)
            local bufnr = module.required["core.norg.dirman"].get_file_bufnr(
                module.private.workspace_full_path .. "/" .. file
            )
            return bufnr
        end,

        --- Get a table of all tasks in current `state` in workspace
        --- @param state string
        --- @param opts table
        ---   - opts.filename (string):   will restrict the search only for the filename provided
        ---   - opts.recursive (bool):   if true will search todos recursively in the AST
        --- @return table
        get_tasks = function(state, opts)
            opts = opts or {}
            local where_statement = {}
            local bufnrs = {}
            local res = {}

            if opts.state then
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
                local extracted = module.required["core.queries.native"].extract_nodes(nodes, bufnr)
                vim.list_extend(res, extracted)
            end

            return res
        end,
    }
end
