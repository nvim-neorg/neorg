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

module.config.public = {
    export_unknown_nodes_as_verbatim = false,
}

module.load = function()
    neorg.modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            definitions = {
                export = {},
            },
            data = {
                export = {
                    min_args = 1,
                    max_args = 2,
                    name = "export",
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

        local query_string = [[]]

        for node_name, data in pairs(converter.converters) do
            if data.named == nil then
                data.named = node_name:sub(1, 1) ~= "_"
            end

            query_string = query_string
                .. (
                    data.named and string.format("(%s) @%s\n", node_name, node_name)
                    or string.format('("%s") @unnamed_%s\n', node_name, node_name)
                )
        end

        -- TODO: Allow the user to configure whether they want undeclared nodes (without conversion functions)
        -- to be included verbatim vs ignoring them?
        local query = vim.treesitter.parse_query("norg", query_string)

        local output = {}

        for id, node in query:iter_captures(document_root, buffer) do
            local capture = query.captures[id]
            local converter_data = converter.converters[capture]
                or converter.converters[capture:sub(string.len("unnamed_") + 1)]

            local node_text = module.required["core.integrations.treesitter"].get_node_text(node)
            local converted_string = converter_data.convert and converter_data.convert(node_text, node)
                or (module.config.public.export_unknown_nodes_as_verbatim and node_text)

            if converted_string then
                local node_range = module.required["core.integrations.treesitter"].get_node_range(node)
                output[node_range.row_start] = output[node_range.row_start] or {}
                output[node_range.row_start][node_range.column_start] = converted_string
            end
        end

        return output
    end,

    build_file_from_export_data = function(export_data)
        local output = [[]]

        for _, line in pairs(neorg.lib.order_associative_array(export_data)) do
            for _, column in pairs(neorg.lib.order_associative_array(line)) do
                output = output .. column
            end

            output = output .. "\n"
        end

        return output
    end,
}

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.export" then
        local filetype = module.public.get_filetype(event.content[1], event.content[2])
        local exported = module.public.export(event.buffer, filetype)
        local rebuilt_file = module.public.build_file_from_export_data(exported)
        log.warn(rebuilt_file)
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        export = true,
    },
}

return module
