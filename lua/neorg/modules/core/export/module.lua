--[[]]

local module = neorg.modules.create("core.export")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
        },
    }
end

module.load = function()
    neorg.modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            definitions = {
                export = {
                    ["to-file"] = {},
                },
            },
            data = {
                export = {
                    args = 1,

                    subcommands = {
                        ["to-file"] = {
                            min_args = 1,
                            max_args = 2,
                            name = "export.to-file",
                        },
                    },
                },
            },
        })
    end)
end

module.public = {
    get_converter = function(ftype)
        if not neorg.modules.is_module_loaded("core.export." .. ftype) then
            return
        end

        return neorg.modules.get_module("core.export." .. ftype)
    end,

    get_filetype = function(file, force_filetype)
        local filetype = force_filetype

        -- Getting an extension properly is... difficult
        -- This is why we leverage Neovim instead.
        -- We create a dummy buffer with the filepath the user wanted to export to
        -- and query the filetype from there.
        if not filetype then
            local dummy_buffer = vim.uri_to_bufnr("file://" .. file)
            vim.fn.bufload(dummy_buffer)
            filetype = vim.api.nvim_buf_get_option(dummy_buffer, "filetype")
            vim.api.nvim_buf_delete(dummy_buffer, { force = true })
        end

        return filetype
    end,

    export = function(buffer, filetype)
        local converter = module.public.get_converter(filetype)

        if not converter then
            log.error("Unable to export file - did not find exporter for filetype '" .. filetype .. "'.")
            return
        end

        local document_root = module.required["core.integrations.treesitter"].get_document_root(buffer)

        if not document_root then
            return
        end

        local state = converter.export.init_state and converter.export.init_state() or {}
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        local function descend(start)
            local output = {}

            for node in start:iter_children() do
                local exporter = converter.export.functions[node:type()]

                if exporter then
                    if type(exporter) == "function" then
                        local resulting_string, keep_descending, returned_state = exporter(
                            module.required["core.integrations.treesitter"].get_node_text(node),
                            node,
                            state,
                            ts_utils
                        )

                        state = returned_state and vim.tbl_extend("force", state, returned_state) or state

                        if resulting_string then
                            table.insert(output, resulting_string)
                        end

                        if keep_descending then
                            local ret = descend(node)

                            if ret then
                                table.insert(output, ret)
                            end
                        end
                    elseif exporter == true then
                        table.insert(output, module.required["core.integrations.treesitter"].get_node_text(node))
                    else
                        table.insert(output, exporter)
                    end
                else
                    local ret = descend(node)

                    if ret then
                        table.insert(output, ret)
                    end
                end
            end

            local recollector = converter.export.recollectors[start:type()]

            return recollector and table.concat(recollector(output) or {})
                or (not vim.tbl_isempty(output) and table.concat(output))
        end

        local output = descend(document_root)
        return converter.export.cleanup and converter.export.cleanup(output) or output
    end,
}

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.export.to-file" then
        local filetype = module.public.get_filetype(event.content[1], event.content[2])
        local exported = module.public.export(event.buffer, filetype)
        log.warn(exported)
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["export.to-file"] = true,
    },
}

return module
