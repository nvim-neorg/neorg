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

        --- Get a table of all tasks in current workspace
        --- @param opts table
        ---   - opts.filename (string):         will restrict the search only for the filename provided
        ---   - opts.exclude_files (table):     will exclude files from workspace in querying information
        --- @return table
        get_tasks = function(opts)
            opts = opts or {}
            local bufnrs = {}
            local res = {}

            local tree = {
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
                vim.list_extend(res, nodes)
            end

            return res
        end,

        --- Add metadatas to a list of `task_nodes`
        --- @param task_nodes table
        --- @return table
        add_metadata = function(task_nodes)
            local res = {}

            for _, task_node in pairs(task_nodes) do
                local task = {}
                task.task_node = task_node[1]
                task.bufnr = task_node[2]

                task.content = module.private.get_task_content(task)
                task.project = module.private.get_task_project(task)
                task.contexts = module.private.get_task_tag("contexts", task)
                task.start = module.private.get_task_tag("time.start", task)
                task.due = module.private.get_task_tag("time.due", task)
                task.waiting_for = module.private.get_task_tag("waiting.for", task)
                task.state = module.private.get_task_state(task)

                table.insert(res, task)
            end

            return res
        end,

        --- Get task content from a task table
        --- @param task table
        --- @return string
        get_task_content = function(task)
            local tree = {
                { query = { "first", "paragraph" } },
            }
            local task_content = module.required["core.queries.native"].query_from_tree(
                task.task_node,
                tree,
                task.bufnr
            )

            if #task_content == 0 then
                return {}
            end

            local extracted = module.required["core.queries.native"].extract_nodes(task_content)
            return extracted[1]
        end,

        --- Get project from `task` if there is one
        --- @param task table
        --- @return string
        get_task_project = function(task)
            local project_node = module.required["core.queries.native"].find_parent_node(
                { task.task_node, task.bufnr },
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

            local extracted = module.required["core.queries.native"].extract_nodes(project_content_node)
            return extracted[1]
        end,

        --- Get a list of content for a specific `tag_name` in a `task` node
        --- @param tag_name string
        --- @param task table
        --- @return table
        get_task_tag = function(tag_name, task)
            if not vim.tbl_contains({ "time.due", "time.start", "contexts", "waiting.for" }, tag_name) then
                log.error("Please specify time.due|time.start|contexts|waiting.for in get_task_date function")
                return
            end

            local tags_node = module.required["core.queries.native"].find_parent_node(
                { task.task_node, task.bufnr },
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
            for _, node in pairs(tags_node) do
                local tag_content_nodes = module.required["core.queries.native"].query_from_tree(node[1], tree, node[2])

                if #tag_content_nodes == 0 then
                    return nil
                end

                local res = module.required["core.queries.native"].extract_nodes(tag_content_nodes)

                for _, res_tag in pairs(res) do
                    if not vim.tbl_contains(extracted, res_tag) then
                        table.insert(extracted, res_tag)
                    end
                end
            end

            return extracted
        end,

        --- Retrieve the state of the `task`
        --- @param task table
        --- @return string
        get_task_state = function(task)
            local tree = {
                { query = { "all", "todo_item_done" } },
                { query = { "all", "todo_item_undone" } },
                { query = { "all", "todo_item_pending" } },
            }

            local task_state_nodes = module.required["core.queries.native"].query_from_tree(
                task.task_node,
                tree,
                task.bufnr
            )

            if #task_state_nodes ~= 1 then
                log.error("This task does not contain any state !")
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
    }
end
