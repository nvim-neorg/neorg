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
        },
    }
end
