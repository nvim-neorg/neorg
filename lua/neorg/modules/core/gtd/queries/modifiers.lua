return function(module)
    return {
        public = {
            --- Modifies an `option` from `object` (the content must not be extracted!) with new `value`
            --- @param object table
            --- @param option string
            --- @param value string|table
            --- @param opts table
            ---   - opts.force_create (bool)    if true, will insert a new tag (to be used with opts.tag)
            ---   - opts.tag (string)           the tag to create if we use opts.force_create
            ---   - opts.index (number)         if object.option is a table, specify an index to select the node index to modify
            --                                  e.g contexts = { "home", "mac" }, replacing "mac" with opts.index = 2
            modify = function(object, option, value, opts)
                opts = opts or {}
                if not value then
                    return
                end

                -- Create the tag (opts.tag) with the values if opts.force_create and opts.tag
                if not object[option] then
                    if opts.force_create and opts.tag then
                        module.public.insert_tag({ object.node, object.bufnr }, value, opts.tag)
                    end
                    return
                end

                local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

                -- Select the node to modify
                local fetched_node
                if type(object[option]) == "table" then
                    if not opts.index then
                        log.error("Please specify an index if you modify one of the nodes!")
                        return
                    end
                    -- The node we modify will be the one at index: opts.index (if it's a table)
                    fetched_node = object[option][opts.index]
                else
                    fetched_node = object[option]
                end

                local start_row, start_col, end_row, end_col = ts_utils.get_node_range(fetched_node)

                if not end_row or not end_col then
                    return
                end

                -- Replacing old option with new one (The empty string is to prevent lines below to wrap)
                vim.api.nvim_buf_set_text(object.bufnr, start_row, start_col, end_row, end_col, { value, "" })
            end,

            --- Delete a node from an `object` with `option` key
            --- @param object table
            --- @param option string
            --- @param opts table
            ---   - opts.index (number)         if object.option is a table, specify an index to select the node index to modify
            delete = function(object, option, opts)
                opts = opts or {}

                local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

                local fetched_node
                if type(object[option]) == "table" then
                    if opts.index then
                        -- Deletes the node at index
                        fetched_node = object[option][opts.index]
                    else
                        -- Recursively deletes all objects
                        for i, _ in ipairs(object[option]) do
                            module.public.delete(object, option, { index = i })
                        end
                    end
                else
                    fetched_node = object[option]
                end

                local start_row, start_col, end_row, end_col = ts_utils.get_node_range(fetched_node)

                -- Deleting object

                vim.api.nvim_buf_set_text(object.bufnr, start_row, start_col, end_row, end_col, { "" })
            end,

            --- Update a specific `node` with `type`.
            --- Note: other nodes don't get updated ! If you want to update all nodes, just redo a get()
            --- Note2: will only work if the node.content is the same and if the task is at same location
            --- @param node table
            --- @param node_type string
            update = function(node, node_type)
                if not vim.tbl_contains({ "task", "project" }, node_type) then
                    log.error("Incorrect node_type")
                    return
                end

                -- If the node is not extracted, extract it in order to get a diff
                local originally_extracted = true
                if type(node.content) == "userdata" then
                    node = module.public.add_metadata({ { node.node, node.bufnr } }, node_type)[1]
                    originally_extracted = false
                end

                -- Get all nodes from same bufnr
                local nodes = module.public.get(node_type .. "s", { bufnr = node.bufnr })
                local nodes_extracted = module.public.add_metadata(nodes, node_type, { extract = true })

                -- Compare nodes by their contents
                -- NOTE: Find a better way
                local new_node = vim.tbl_filter(function(n)
                    return n.content == node.content
                end, nodes_extracted)

                if #new_node == 0 then
                    log.error("Not updated")
                    return
                end

                -- Get first node
                new_node = new_node[1]

                if originally_extracted then
                    return new_node
                else
                    new_node = vim.tbl_filter(function(n)
                        return new_node.node == n[1]
                    end, nodes)[1]
                    new_node = module.public.add_metadata({ new_node }, node_type, { extract = false })[1]
                    return new_node
                end
            end,
        },
    }
end
