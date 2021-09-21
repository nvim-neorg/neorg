return function(module)
    return {
        public = {
            --- Modifies an `option` from `object` (the content must not be extracted!) with new `value`
            --- @param object table
            --- @param option string
            --- @param value string|table
            --- @param index number
            modify = function(object, option, value, index)
                if not object[option] then
                    -- TODO: when the object does not contain the option, add new content to object
                    return
                end

                if type(value) == "table" then
                    -- Modify all values in the table
                    for i, v in ipairs(value) do
                        module.public.modify(object, option, v, i)
                    end
                else
                    local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()
                    local start_row, start_col, end_row, end_col = ts_utils.get_node_range(object[option])

                    -- Replacing old option with new one (The empty string is to prevent lines below to wrap)
                    vim.api.nvim_buf_set_text(object.bufnr, start_row, start_col, end_row, end_col, { value, "" })
                end
            end,
        },
    }
end
