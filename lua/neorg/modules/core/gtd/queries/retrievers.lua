return function(module)
    return {
        public = {
            --- Get a table of all `type` in workspace
            --- @param type string
            --- @param opts table
            ---   - opts.filename (string):     will restrict the search only for the filename provided
            ---   - opts.exclude_files (table):     will exclude files from workspace in querying information
            ---   - opts.bufnr (number):        will use this bufnr to search nodes from
            --- @return table
            get = function(type, opts)
                if not vim.tbl_contains({ "projects", "tasks" }, type) then
                    log.error("You can only retrieve projects and tasks. Asked: " .. type)
                    return
                end

                opts = opts or {}
                local bufnrs = {}
                local res = {}
                local tree
                if type == "projects" then
                    tree = {
                        {
                            query = { "first", "document_content" },
                            subtree = {
                                {
                                    query = { "all", "heading1" },
                                    recursive = true,
                                },
                            },
                        },
                    }
                elseif type == "tasks" then
                    tree = {
                        {
                            query = { "first", "document_content" },
                            subtree = {
                                {
                                    query = { "all", "generic_list" },
                                    recursive = true,
                                    subtree = {
                                        {
                                            query = { "all", "todo_item1" },
                                        },
                                    },
                                },
                            },
                        },
                    }
                end

                if opts.filename then
                    local bufnr = module.private.get_bufnr_from_file(opts.filename)
                    table.insert(bufnrs, bufnr)
                elseif opts.bufnr then
                    local bufnr = opts.bufnr
                    table.insert(bufnrs, bufnr)
                else
                    local configs = neorg.modules.get_module_config("core.gtd.base")
                    local files = module.required["core.norg.dirman"].get_norg_files(configs.workspace)

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
                    vim.list_extend(res, nodes)
                end

                return res
            end,

            --- Get the node `type` at cursor
            --- @param type string #Either project|task
            --- @return table #A table of type { node, bufnr }
            get_at_cursor = function(type)
                vim.validate({
                    type = { type, "string" },
                })

                local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()
                local current_node = ts_utils.get_node_at_cursor(0)

                local node_type = type == "project" and "heading1" or "todo_item1"
                local parent = module.required["core.queries.native"].find_parent_node({ current_node, 0 }, node_type)

                return parent
            end,

            --- Add metadatas to a list of `nodes`
            --- @param nodes table
            --- @param type string
            --- @param opts table
            ---   - opts.extract (bool):   if false does not extract the content from the nodes
            --- @return table
            add_metadata = function(nodes, type, opts)
                local res = {}
                opts = opts or {
                    extract = true,
                }

                if not vim.tbl_contains({ "task", "project" }, type) then
                    log.error("Unknown type")
                    return
                end

                local previous_bufnr_tbl = {}
                for _, node in ipairs(nodes) do
                    local exported = {}
                    exported.node = node[1]
                    exported.bufnr = node[2]

                    exported.content = module.private.get_content(exported, type, opts.extract)

                    if type == "task" then
                        exported.project = module.private.get_task_project(exported, opts.extract)
                        exported.state = module.private.get_task_state(exported, opts.extract)
                    end

                    exported.contexts = module.private.get_tag("contexts", exported, opts.extract)
                    exported.start = module.private.get_tag("time.start", exported, opts.extract)
                    exported.due = module.private.get_tag("time.due", exported, opts.extract)
                    exported.waiting_for = module.private.get_tag("waiting.for", exported, opts.extract)

                    -- Add position in file for each node
                    if not previous_bufnr_tbl[exported.bufnr] then
                        previous_bufnr_tbl[exported.bufnr] = 1
                        exported.position = 1
                    else
                        previous_bufnr_tbl[exported.bufnr] = previous_bufnr_tbl[exported.bufnr] + 1
                        exported.position = previous_bufnr_tbl[exported.bufnr]
                    end

                    table.insert(res, exported)
                end

                return res
            end,

            --- Sort `tasks` list by specified `sorter`
            --- Current sorters: waiting_for, contexts, project
            --- @param sorter string
            --- @param tasks table
            --- @return table
            sort_by = function(sorter, tasks, opts)
                opts = opts or {}
                if not vim.tbl_contains({ "waiting_for", "contexts", "project" }, sorter) then
                    log.error("Please provide a correct sorter.")
                    return
                end
                local res = {}

                local insert = function(t, k, v)
                    if not t[k] then
                        t[k] = {}
                    end
                    table.insert(t[k], v)
                end

                for _, t in pairs(tasks) do
                    if not t[sorter] then
                        insert(res, "_", t)
                    else
                        if type(t[sorter]) == "table" then
                            for _, s in pairs(t[sorter]) do
                                insert(res, s, t)
                            end
                        elseif type(t[sorter]) == "string" then
                            insert(res, t[sorter], t)
                        end
                    end
                end

                return res
            end,
        },

        private = {
            --- Gets a bufnr from a relative `file` path
            --- @param file string
            --- @return number
            get_bufnr_from_file = function(file)
                local configs = neorg.modules.get_module_config("core.gtd.base")
                local workspace = module.required["core.norg.dirman"].get_workspace(configs.workspace)
                local bufnr = module.required["core.norg.dirman"].get_file_bufnr(workspace .. "/" .. file)
                return bufnr
            end,

            --- Gets content from a `node` table. If `extract`, extracts the content of the node
            --- @param node table
            --- @param type string
            --- @param extract boolean
            --- @return string
            get_content = function(node, type, extract)
                local tree = {}
                if type == "project" then
                    table.insert(tree, { query = { "first", "paragraph_segment" } })
                elseif type == "task" then
                    table.insert(tree, { query = { "first", "paragraph" } })
                else
                    log.error("Unknown type")
                    return
                end

                local content = module.required["core.queries.native"].query_from_tree(node.node, tree, node.bufnr)

                if #content == 0 then
                    return {}
                end

                if not extract then
                    return content[1][1]
                end

                local extracted = module.required["core.queries.native"].extract_nodes(content)
                return extracted[1]
            end,

            --- Get project from `task` if there is one. If `extract`, extracts the content of the node
            --- @param task table
            --- @param extract boolean
            --- @return string
            get_task_project = function(task, extract)
                local project_node = module.required["core.queries.native"].find_parent_node(
                    { task.node, task.bufnr },
                    "heading1"
                )

                if not project_node[1] then
                    return nil
                end

                local tree = {
                    { query = { "all", "paragraph_segment" } },
                }

                local project_content_node = module.required["core.queries.native"].query_from_tree(
                    project_node[1],
                    tree,
                    project_node[2]
                )

                if not extract then
                    return project_content_node[1][1]
                end

                local extracted = module.required["core.queries.native"].extract_nodes(project_content_node)
                return extracted[1]
            end,

            --- Get a list of content for a specific `tag_name` in a `node`. If `extract`, extracts the content of the node
            --- @param tag_name string
            --- @param node table
            --- @param extract boolean
            --- @return table
            get_tag = function(tag_name, node, extract)
                if not vim.tbl_contains({ "uuid", "time.due", "time.start", "contexts", "waiting.for" }, tag_name) then
                    log.error("Please specify uuid|time.due|time.start|contexts|waiting.for in get_task_date function")
                    return
                end

                local tags_node = module.required["core.queries.native"].find_parent_node(
                    { node.node, node.bufnr },
                    "carryover_tag_set",
                    { multiple = true }
                )
                if #tags_node == 0 then
                    return nil
                end

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

                local extracted = {}
                for _, _node in pairs(tags_node) do
                    local tag_content_nodes = module.required["core.queries.native"].query_from_tree(
                        _node[1],
                        tree,
                        _node[2]
                    )

                    if #tag_content_nodes == 0 then
                        return nil
                    end

                    if not extract then
                        -- Only keep the nodes and add them to the results
                        tag_content_nodes = vim.tbl_map(function(node)
                            return node[1]
                        end, tag_content_nodes)
                        vim.list_extend(extracted, tag_content_nodes)
                    else
                        local res = module.required["core.queries.native"].extract_nodes(tag_content_nodes)

                        for _, res_tag in pairs(res) do
                            if not vim.tbl_contains(extracted, res_tag) then
                                table.insert(extracted, res_tag)
                            end
                        end
                    end
                end

                return extracted
            end,

            --- Retrieve the state of the `task`. If `extract`, extracts the content of the node
            --- @param task table
            --- @param extract boolean
            --- @return string
            get_task_state = function(task, extract)
                local tree = {
                    { query = { "all", "todo_item_done" } },
                    { query = { "all", "todo_item_undone" } },
                    { query = { "all", "todo_item_pending" } },
                }

                local task_state_nodes = module.required["core.queries.native"].query_from_tree(
                    task.node,
                    tree,
                    task.bufnr
                )

                if #task_state_nodes ~= 1 then
                    log.error("This task does not contain any state !")
                end

                if not extract then
                    return task_state_nodes[1][1]
                end

                local state = task_state_nodes[1][1]:type()
                return string.gsub(state, "todo_item_", "")
            end,

            --- Remove `el` from table `t`
            --- @param t table
            --- @param el any
            --- @return table
            remove_from_table = function(t, el)
                for i, v in ipairs(t) do
                    if v == el then
                        table.remove(t, i)
                        break
                    end
                end
                return t
            end,
        },
    }
end
