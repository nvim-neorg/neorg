return function(module)
    return {
        get_projects = function(filename)
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
            local bufnr = module.required["core.norg.dirman"].get_file_bufnr(filename, module.config.public.workspace)
            local res = module.required["core.queries.native"].query_nodes_from_buf(tree, bufnr)
            local extracted = module.required["core.queries.native"].extract_nodes(res, bufnr)
            return extracted
        end,

        get_tasks = function(filename, opts)
            opts = opts or {}
            local where_statement = {}

            if opts.state then
                where_statement = { "child_exists", "todo_item_" .. opts.state }
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
            local bufnr = module.required["core.norg.dirman"].get_file_bufnr(filename, module.config.public.workspace)
            local res = module.required["core.queries.native"].query_nodes_from_buf(tree, bufnr)
            local extracted = module.required["core.queries.native"].extract_nodes(res, bufnr)
            return extracted
        end,
    }
end
