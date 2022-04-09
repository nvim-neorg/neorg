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
                    ["directory"] = {},
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
                        ["directory"] = {
                            min_args = 2,
                            max_args = 3,
                            name = "export.directory",
                        },
                    },
                },
            },
        })
    end)
end

module.config.public = {
    export_dir = "<export-dir>/<language>-export",
}

module.public = {
    get_converter = function(ftype)
        if not neorg.modules.is_module_loaded("core.export." .. ftype) then
            return
        end

        return neorg.modules.get_module("core.export." .. ftype),
            neorg.modules.get_module_config("core.export." .. ftype)
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
        local converter, converter_config = module.public.get_converter(filetype)

        if not converter then
            log.error("Unable to export file - did not find exporter for filetype '" .. filetype .. "'.")
            return
        end

        if not converter_config.extension then
            log.error(
                "Unable to export file - exporter for filetype '"
                    .. filetype
                    .. "' did not return a preferred extension. The exporter is unable to infer extensions."
            )
            return
        end

        local document_root = module.required["core.integrations.treesitter"].get_document_root(buffer)

        if not document_root then
            return
        end

        local state = converter.export.init_state and converter.export.init_state() or {}
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        local function descend(start)
            if start:type() == "ERROR" then
                return ""
            end

            local output = {}

            for node in start:iter_children() do
                local exporter = converter.export.functions[node:type()]

                if exporter then
                    if type(exporter) == "function" then
                        local resulting_string, keep_descending, returned_state = exporter(
                            module.required["core.integrations.treesitter"].get_node_text(node, buffer),
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
                        table.insert(
                            output,
                            module.required["core.integrations.treesitter"].get_node_text(node, buffer)
                        )
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

            return recollector and table.concat(recollector(output, state) or {})
                or (not vim.tbl_isempty(output) and table.concat(output))
        end

        local output = descend(document_root)
        return converter.export.cleanup and converter.export.cleanup(output) or output, converter_config.extension
    end,
}

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.export.to-file" then
        local filetype = module.public.get_filetype(event.content[1], event.content[2])
        local exported = module.public.export(event.buffer, filetype)

        vim.loop.fs_open(event.content[1], "w", 438, function(err, fd)
            assert(
                not err,
                neorg.lib.lazy_string_concat("Failed to open file '", event.content[1], "' for export: ", err)
            )

            vim.loop.fs_write(fd, exported, function(werr)
                assert(
                    not werr,
                    neorg.lib.lazy_string_concat("Failed to write to file '", event.content[1], "' for export: ", werr)
                )
            end)

            vim.schedule(neorg.lib.wrap(vim.notify, "Successfully exported 1 file!"))
        end)
    elseif event.type == "core.neorgcmd.events.export.directory" then
        local path = event.content[3]
            or module.config.public.export_dir
                :gsub("<language>", event.content[2])
                :gsub("<export%-dir>", event.content[1])
        vim.fn.mkdir(path, "p")

        local old_event_ignore = table.concat(vim.opt.eventignore:get(), ",")

        vim.loop.fs_scandir(event.content[1], function(err, handle)
            assert(not err, neorg.lib.lazy_string_concat("Failed to scan directory '", event.content[1], "': ", err))

            local file_counter, parsed_counter = 0, 0

            while true do
                local name, type = vim.loop.fs_scandir_next(handle)

                if not name then
                    break
                end

                if type == "file" and vim.endswith(name, ".norg") then
                    file_counter = file_counter + 1

                    local function check_counters()
                        parsed_counter = parsed_counter + 1

                        if parsed_counter >= file_counter then
                            vim.schedule(
                                neorg.lib.wrap(
                                    vim.notify,
                                    string.format("Successfully exported %d files!", file_counter)
                                )
                            )
                        end
                    end

                    vim.schedule(function()
                        local filepath = event.content[1] .. "/" .. name

                        vim.opt.eventignore = "BufEnter"

                        local buffer = vim.fn.bufadd(filepath)
                        vim.fn.bufload(buffer)

                        vim.opt.eventignore = old_event_ignore

                        local exported, extension = module.public.export(buffer, event.content[2])

                        vim.api.nvim_buf_delete(buffer, { force = true })

                        if not exported then
                            check_counters()
                            return
                        end

                        local write_path = path .. "/" .. name:gsub("%.%a+$", "." .. extension)

                        vim.loop.fs_open(write_path, "w+", 438, function(fs_err, fd)
                            assert(
                                not fs_err,
                                neorg.lib.lazy_string_concat(
                                    "Failed to open file '",
                                    write_path,
                                    "' for export: ",
                                    fs_err
                                )
                            )

                            vim.loop.fs_write(fd, exported, function(werr)
                                assert(
                                    not werr,
                                    neorg.lib.lazy_string_concat(
                                        "Failed to write to file '",
                                        write_path,
                                        "' for export: ",
                                        werr
                                    )
                                )

                                check_counters()
                            end)
                        end)
                    end)
                end
            end
        end)
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["export.to-file"] = true,
        ["export.directory"] = true,
    },
}

return module
