return function(module)
    return {
        get_projects = function(filename)
            local tree = {
                {
                    query = { "first", "document_content" },
                    subtree = {
                        {
                            query = { "all", "heading1" },
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
