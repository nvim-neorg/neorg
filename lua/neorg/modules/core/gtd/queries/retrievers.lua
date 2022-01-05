local module = neorg.modules.extend("core.gtd.queries.retrievers")

---@class core.gtd.queries.task.internal
---@field bufnr number
---@field node userdata
---@field position number
---@field project_node? userdata

---@class core.gtd.queries.project.internal
---@field bufnr number
---@field node userdata
---@field position number

---@class core.gtd.queries.task
---@field content string
---@field project? string
---@field state string
---@field contexts? string[]
---@field waiting.for? string[]
---@field time.start? string[]
---@field time.due? string[]
---@field area_of_focus? string
---@field internal? core.gtd.queries.task.internal

---@class core.gtd.queries.project
---@field content string
---@field area_of_focus? string
---@field contexts? string[]
---@field waiting.for? string[]
---@field time.start? string[]
---@field time.due? string[]
---@field internal? core.gtd.queries.project.internal

---@class core.gtd.queries
module.public = {
    --- Get a table of all `type` in workspace
    --- @param type string
    --- @param opts table
    ---   - opts.filename (string):     will restrict the search only for the filename provided
    ---   - opts.exclude_files (table):     will exclude files from workspace in querying information. Can exclude entire directories
    ---   - opts.bufnr (number):        will use this bufnr to search nodes from
    --- @return table
    get = function(type, opts)
        vim.validate({
            type = {
                type,
                function(t)
                    return vim.tbl_contains({ "projects", "tasks" }, t)
                end,
                "projects|tasks",
            },
            opts = { opts, "table", true },
        })

        opts = opts or {}
        local bufnrs = {}
        local res = {}
        local tree
        if type == "projects" then
            tree = {
                {
                    query = { "all", "heading1" },
                    recursive = true,
                },
            }
        elseif type == "tasks" then
            tree = {
                {
                    query = { "all", "generic_list" },
                    recursive = true,
                    subtree = {
                        {
                            query = { "all", "todo_item1" },
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

            if vim.tbl_isempty(files) then
                log.error("No files found in " .. configs.workspace .. " workspace.")
                return
            end

            if opts.exclude_files then
                for _, excluded_file in pairs(opts.exclude_files) do
                    files = module.private.remove_from_table(files, excluded_file)
                end
                log.info("files being parsed for GTD: ", files)
            end

            for _, file in pairs(files) do
                local bufnr = module.private.get_bufnr_from_file(file)
                table.insert(bufnrs, bufnr)
            end
        end

        for _, bufnr in pairs(bufnrs) do
            ---@type core.queries.native
            local queries = module.required["core.queries.native"]
            local nodes = queries.query_nodes_from_buf(tree, bufnr)
            vim.list_extend(res, nodes)
        end

        return res
    end,

    --- Get the node `type` at cursor
    --- @param type string #Either project|task
    --- @return table #A table of type { node, bufnr }
    get_at_cursor = function(type)
        vim.validate({
            type = {
                type,
                function(t)
                    return vim.tbl_contains({ "project", "task" }, t)
                end,
                "project|task",
            },
        })

        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        -- NOTE: copied part from https://github.com/nvim-treesitter/nvim-treesitter/blob/fa2a6b68aaa6df0187b5bbebe6cbadc120d4a65a/lua/nvim-treesitter/ts_utils.lua#L124
        local cursor = vim.api.nvim_win_get_cursor(0)
        local cursor_range = { cursor[1] - 1, cursor[2] }

        local queries = module.required["core.queries.native"]
        local buf = vim.api.nvim_win_get_buf(0)
        local temp_buf = queries.get_temp_buf(buf)
        local root_lang_tree = vim.treesitter.get_parser(temp_buf, "norg")

        if not root_lang_tree then
            return
        end

        local root = ts_utils.get_root_for_position(cursor_range[1], cursor_range[2], root_lang_tree)

        if not root then
            return
        end

        local current_node = root:named_descendant_for_range(
            cursor_range[1],
            cursor_range[2],
            cursor_range[1],
            cursor_range[2]
        )

        local node_type = type == "project" and "heading1" or "todo_item1"
        local parent = module.required["core.queries.native"].find_parent_node({ current_node, buf }, node_type)

        if #parent == 0 then
            return
        end

        return parent
    end,

    --- Add metadatas to a list of `nodes`
    --- @param nodes table
    --- @param type string
    --- @param opts table
    ---   - opts.extract (bool):   if false does not extract the content from the nodes
    ---   - opts.same_node (bool): if true, will only fetch metadatas from the node and not parent ones.
    ---   It will not fetch metadatas that group tasks or projects
    ---   - opts.keys (table):     a table of keys to add to the node (e.g state, waiting.for, ...)
    --- @return core.gtd.queries.project|core.gtd.queries.task
    add_metadata = function(nodes, type, opts)
        vim.validate({
            nodes = { nodes, "table" },
            type = {
                type,
                function(t)
                    return vim.tbl_contains({ "project", "task" }, t)
                end,
                "project|task",
            },
            opts = { opts, "table", true },
        })

        local res = {}
        opts = vim.tbl_extend("force", { extract = true }, opts or {})

        local function get_key(key, cb, ...)
            if opts.keys and not vim.tbl_contains(opts.keys, key) then
                return
            end

            return cb(...)
        end

        local previous_bufnr_tbl = {}
        for _, node in ipairs(nodes) do
            ---@type core.gtd.queries.project|core.gtd.queries.task
            local exported = {}
            exported.internal = {
                node = node[1],
                bufnr = node[2],
            }
            exported.uuid = exported.internal.node:id()

            exported.content = get_key("content", module.private.get_content, exported, type, opts)

            if type == "task" then
                exported.project_uuid = get_key(
                    "project_uuid",
                    module.private.get_task_project,
                    exported,
                    { project_node = true }
                )
                if exported.project_uuid then
                    exported.project_uuid = exported.project_uuid:id()
                end
                exported.state = get_key("state", module.private.get_task_state, exported, opts)
            end

            ---@type core.gtd.base.config
            local config = neorg.modules.get_module_config("core.gtd.base")
            local syntax = config.syntax

            exported.contexts = get_key(
                "contexts",
                module.public.get_tag,
                string.sub(syntax.context, 2),
                exported,
                type,
                opts
            )
            exported["time.start"] = get_key(
                "time.start",
                module.public.get_tag,
                string.sub(syntax.start, 2),
                exported,
                type,
                opts
            )
            exported["time.due"] = get_key(
                "time.due",
                module.public.get_tag,
                string.sub(syntax.due, 2),
                exported,
                type,
                opts
            )
            exported["waiting.for"] = get_key(
                "waiting.for",
                module.public.get_tag,
                string.sub(syntax.waiting, 2),
                exported,
                type,
                opts
            )
            exported["area_of_focus"] = get_key("area_of_focus", module.private.get_aof, exported, opts)

            -- Add position in file for each node
            if not previous_bufnr_tbl[exported.internal.bufnr] then
                previous_bufnr_tbl[exported.internal.bufnr] = 1
                exported.internal.position = 1
            else
                previous_bufnr_tbl[exported.internal.bufnr] = previous_bufnr_tbl[exported.internal.bufnr] + 1
                exported.internal.position = previous_bufnr_tbl[exported.internal.bufnr]
            end

            table.insert(res, exported)
        end

        return res
    end,

    --- Ensure t[k] is a table and then add v to the end of t[k]
    --- @param t table
    --- @param k any key
    --- @param v any value
    insert = function(t, k, v)
        if not t[k] then
            t[k] = {}
        end
        table.insert(t[k], v)
    end,

    --- Sort `nodes` list by specified `sorter`.
    --- @param sorter string
    --- @param nodes core.gtd.queries.project|core.gtd.queries.task
    --- @return table
    sort_by = function(sorter, nodes)
        vim.validate({
            sorter = {
                sorter,
                function(s)
                    return vim.tbl_contains({ "waiting.for", "contexts", "project_uuid", "area_of_focus" }, s)
                end,
                "waiting.for|contexts|project_uuid|area_of_focus",
            },
            tasks = { nodes, "table" },
        })

        local res = {}

        for _, t in pairs(nodes) do
            if not t[sorter] then
                module.public.insert(res, "_", t)
            else
                if type(t[sorter]) == "table" then
                    for _, s in pairs(t[sorter]) do
                        module.public.insert(res, s, t)
                    end
                elseif type(t[sorter]) == "string" then
                    module.public.insert(res, t[sorter], t)
                elseif type(t[sorter]) == "userdata" then
                    module.public.insert(res, t[sorter]:id(), t)
                end
            end
        end

        return res
    end,

    --- Get a list of content for a specific `tag_name` in a `node`.
    --- @param tag_name string
    --- @param node core.gtd.queries.task|core.gtd.queries.project
    --- @param type string #The current node type (task / project)
    --- @param opts table #Options from add_metadata
    --- @param extra_tag_names type string additional elements that tag_name can be
    --- @return table
    get_tag = function(tag_name, node, type, opts, extra_tag_names)
        local allowed_tag_names = { "time.due", "time.start", "contexts", "waiting.for" }
        if extra_tag_names ~= nil then
            for _, _tag_name in pairs(extra_tag_names) do
                table.insert(allowed_tag_names, _tag_name)
            end
        end

        local allowed_string = allowed_tag_names[1]
        for _, _tag_name in pairs(allowed_tag_names) do
            allowed_string = allowed_string .. "|" .. _tag_name
        end

        vim.validate({
            tag_name = {
                tag_name,
                function(t)
                    return vim.tbl_contains(allowed_tag_names, t)
                end,
                allowed_string,
            },
            node = { node, "table" },
            type = {
                type,
                function(t)
                    return vim.tbl_contains({ "project", "task" }, t)
                end,
                "task|project",
            },
            opts = { opts, "table", true },
        })

        opts = opts or {}

        -- Will fetch multiple parent tag sets if we did not explicitly add same_node.
        -- Else, it'll only get the first upper tag_set from the current node
        local fetch_multiple_sets = not opts.same_node

        local tags_node = module.required["core.queries.native"].find_parent_node(
            { node.internal.node, node.internal.bufnr },
            "carryover_tag_set",
            { multiple = fetch_multiple_sets }
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
                            { query = { "all", "tag_param" } },
                        },
                    },
                },
            },
        }

        local extract = function(_node, extracted)
            local tag_content_nodes = module.required["core.queries.native"].query_from_tree(_node[1], tree, _node[2])

            if #tag_content_nodes == 0 then
                return nil
            end

            if not opts.extract then
                -- Only keep the nodes and add them to the results
                tag_content_nodes = vim.tbl_map(function(n)
                    return n[1]
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

        local extracted = {}

        if not fetch_multiple_sets then
            -- If i don't fetch multiple sets, i only have one, so i cannot iterate
            extract(tags_node, extracted)
        else
            for _, _node in pairs(tags_node) do
                extract(_node, extracted)
            end
        end

        if #extracted == 0 then
            return nil
        end

        return extracted
    end,
}

module.private = {
    --- Gets a bufnr from a relative `file` path
    --- @param file string
    --- @return number
    get_bufnr_from_file = function(file)
        vim.validate({ file = { file, "string" } })
        local configs = neorg.modules.get_module_config("core.gtd.base")
        local workspace = module.required["core.norg.dirman"].get_workspace(configs.workspace)
        local bufnr = module.required["core.norg.dirman"].get_file_bufnr(workspace .. "/" .. file)
        return bufnr
    end,

    --- Gets content from a `node` table. If `extract`, extracts the content of the node
    --- @param node core.gtd.queries.project|core.gtd.queries.task
    --- @param type string
    --- @param opts table #Options from add_metadata
    --- @return string
    get_content = function(node, type, opts)
        vim.validate({
            node = { node, "table" },
            type = {
                type,
                function(t)
                    return vim.tbl_contains({ "project", "task" }, t)
                end,
                "project|task",
            },
            opts = { opts, "table", true },
        })

        opts = opts or {}
        local tree = {}
        if type == "project" then
            table.insert(tree, { query = { "first", "paragraph_segment" } })
        elseif type == "task" then
            table.insert(tree, { query = { "first", "paragraph" } })
        end

        local content = module.required["core.queries.native"].query_from_tree(
            node.internal.node,
            tree,
            node.internal.bufnr
        )

        if #content == 0 then
            return {}
        end

        if not opts.extract then
            return content[1][1]
        end

        local extracted = module.required["core.queries.native"].extract_nodes(content)
        return extracted[1]
    end,

    --- Get project from `task` if there is one. If `extract`, extracts the content of the node
    --- @param task core.gtd.queries.task
    --- @param opts table #Options from add_metadata
    --- @return string
    get_task_project = function(task, opts)
        vim.validate({
            task = { task, "table" },
            opts = { opts, "table", true },
        })
        opts = opts or {}
        local project_node = module.required["core.queries.native"].find_parent_node(
            { task.internal.node, task.internal.bufnr },
            "heading1"
        )

        if not project_node[1] then
            return nil
        end

        if not opts.extract and opts.project_node then
            return project_node[1]
        end

        local tree = {
            { query = { "all", "paragraph_segment" } },
        }

        local project_content_node = module.required["core.queries.native"].query_from_tree(
            project_node[1],
            tree,
            project_node[2]
        )

        if not opts.extract then
            return project_content_node[1][1]
        end

        local extracted = module.required["core.queries.native"].extract_nodes(project_content_node)
        return extracted[1]
    end,

    --- Retrieve the state of the `task`. If `extract`, extracts the content of the node
    --- @param task core.gtd.queries.task
    --- @param opts table #Options from add_metadata
    --- @return string
    get_task_state = function(task, opts)
        vim.validate({
            task = { task, "table" },
            opts = { opts, "table", true },
        })

        opts = opts or {}
        local tree = {
            { query = { "first", "todo_item_done" } },
            { query = { "first", "todo_item_undone" } },
            { query = { "first", "todo_item_pending" } },
            { query = { "first", "todo_item_on_hold" } },
            { query = { "first", "todo_item_cancelled" } },
            { query = { "first", "todo_item_urgent" } },
            { query = { "first", "todo_item_uncertain" } },
            { query = { "first", "todo_item_recurring" } },
        }

        local task_state_nodes = module.required["core.queries.native"].query_from_tree(
            task.internal.node,
            tree,
            task.internal.bufnr
        )

        if not task_state_nodes then
            log.error("This task does not contain any state !")
        end

        if not opts.extract then
            return task_state_nodes[1][1]
        end

        local state = task_state_nodes[1][1]:type()
        return string.gsub(state, "todo_item_", "")
    end,

    --- Get the area_of_focus for a task, or project
    --- @param node core.gtd.queries.task|core.gtd.queries.project
    --- @param opts table #opts from add_metadata
    --- @return string
    get_aof = function(node, opts)
        vim.validate({
            node = { node, "table" },
        })

        local marker_node = module.required["core.queries.native"].find_parent_node(
            { node.internal.node, node.internal.bufnr },
            "marker"
        )

        if #marker_node == 0 then
            return nil
        end

        local tree = {
            { query = { "first", "paragraph_segment" } },
        }

        marker_node = module.required["core.queries.native"].query_from_tree(marker_node[1], tree, node.internal.bufnr)

        if vim.tbl_isempty(marker_node) then
            log.error("Error in fetching marker")
            return
        end

        if not opts.extract then
            return marker_node[1][1]
        end

        marker_node = module.required["core.queries.native"].extract_nodes(marker_node)

        if vim.tbl_isempty(marker_node) then
            log.error("Error in extracting area of focus")
            return
        end

        return marker_node[1]
    end,

    --- Remove `el` from table `t`
    --- @param t table
    --- @param el any
    --- @return table
    remove_from_table = function(t, el)
        vim.validate({ t = { t, "table" } })
        local result = {}

        -- This is possibly a directory, so we remove every file inside this directory
        if not vim.endswith(el, ".norg") then
            for _, v in ipairs(t) do
                if not vim.startswith(v, el) then
                    table.insert(result, v)
                end
            end
        else
            for _, v in ipairs(t) do
                if v ~= el then
                    table.insert(result, v)
                end
            end
        end

        return result
    end,
}

return module
