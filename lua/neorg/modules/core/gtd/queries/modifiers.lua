local module = neorg.modules.extend("core.gtd.queries.modifiers")

module.public = {
    --- Modifies an `option` from `object` (the content must not be extracted!) with new `value`
    --- @param object table
    --- @param node_type string
    --- @param option string
    --- @param value string|table
    --- @param opts table
    ---   - opts.tag (string)           the tag to create if we use opts.force_create
    modify = function(object, node_type, option, value, opts)
        vim.validate({
            object = { object, "table" },
            node_type = {
                node_type,
                function(n)
                    return vim.tbl_contains({ "project", "task" }, n)
                end,
                "project|task",
            },
            option = { option, "string" },
            value = {
                value,
                function(v)
                    return vim.tbl_contains({ "string", "table", "nil" }, type(v))
                end,
                "string|table",
            },
            opts = { opts, "table", true },
        })
        opts = opts or {}

        if not value then
            return object
        end

        -- Create the tag (opts.tag) with the values if opts.tag
        if not object[option] then
            if not opts.tag then
                log.error("Please specify a tag with opts.tag")
                return
            end
            module.private.insert_tag({ object.node, object.bufnr }, value, opts.tag)
            return module.public.update(object, node_type)
        end

        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        -- Select the node to modify
        local fetched_node
        if type(object[option]) == "table" then
            if opts.tag then
                -- Delete the tag and recreate it with new values
                local line_nr
                object, line_nr = module.public.delete(object, node_type, option)
                module.private.insert_tag({ object.node, object.bufnr }, value, opts.tag, { line = line_nr })
                return module.public.update(object, node_type)
            else
                log.error("Only tags and content are supported for modification")
                return
            end
        else
            -- Easy, modify the content
            fetched_node = object[option]
        end

        -- Get the position of the node to modify
        local start_row, start_col, end_row, end_col = ts_utils.get_node_range(fetched_node)

        if not end_row or not end_col then
            return module.public.update(object, node_type)
        end

        -- Replacing old option with new one (The empty string is to prevent lines below to wrap)
        vim.api.nvim_buf_set_text(object.bufnr, start_row, start_col, end_row, end_col, { value, "" })

        return module.public.update(object, node_type)
    end,

    --- Delete a node from an `object` with `option` key
    --- @param object table
    --- @param option string
    delete = function(object, node_type, option)
        vim.validate({
            object = { object, "table" },
            node_type = {
                node_type,
                function(n)
                    return vim.tbl_contains({ "project", "task" }, n)
                end,
                "task|project",
            },
            option = { option, "string" },
        })

        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        local fetched_node
        if type(object[option]) == "table" then
            local carryover_tags = vim.tbl_map(function(n)
                local carryover_tag = module.required["core.queries.native"].find_parent_node(
                    { n, object.bufnr },
                    "carryover_tag"
                )
                return carryover_tag[1]
            end, object[option])

            -- If they are not from the same carryover_tag, error
            local same_tags = vim.tbl_filter(function(t)
                return t == carryover_tags[1]
            end, carryover_tags)
            if #same_tags < #carryover_tags then
                log.error("All tags from " .. option .. " must have the same carryover_tag")
                return
            end

            fetched_node = carryover_tags[1]
        else
            fetched_node = object[option]
        end

        local start_row, start_col, end_row, end_col = ts_utils.get_node_range(fetched_node)

        -- Deleting object
        vim.api.nvim_buf_set_text(object.bufnr, start_row, start_col, end_row, end_col, { "" })

        return module.public.update(object, node_type), start_row
    end,

    --- Update a specific `node` with `type`.
    --- Note: other nodes don't get updated ! If you want to update all nodes, just redo a module.required["core.gtd.queries"].get
    --- @param node table #A task/project with metadatas
    --- @param node_type string
    update = function(node, node_type)
        vim.validate({
            node = { node, "table" },
            node_type = {
                node_type,
                function(n)
                    return vim.tbl_contains({ "project", "task" }, n)
                end,
                "task|project",
            },
        })

        -- Get all nodes from same bufnr
        local nodes = module.public.get(node_type .. "s", { bufnr = node.bufnr })
        local originally_extracted = type(node.content) == "string"
        nodes = module.public.add_metadata(nodes, node_type, { extract = originally_extracted })

        local found_node = vim.tbl_filter(function(n)
            return n.position == node.position
        end, nodes)

        if #found_node == 0 then
            log.error("An error occured in updating node")
            return
        end

        return found_node[1]
    end,
}

return module
