--[[
    File: Exporting-Files
    Title: Converting Neorg Files to other Filetypes with `core.export`
    Summary: Exports Neorg documents into any other supported filetype.
    ---
All export functionality is provided by the `:Neorg export` command.

To export the currently opened buffer to another file format, you should use the `:Neorg export to-file` command.
The command takes the following arguments:
- `path` - the path to export to. Examples are: `my-file.md`, `~/output.md`.
  If the second argument is not provided Neorg will try to infer the filetype to convert to through
  the file extension.
- `filetype` (optional) - the filetype to export to. Useful if you want to use a non-standard extension, or
  if the filetype you're using cannot be inferred automatically. Note that this filetype *must* be a filetype
  that Neovim itself provides and/or understands, i.e. `md` or `markd` is not a valid filetype, however `markdown` is.

Neorg also supports exporting a directory of files: this is where the `:Neorg export directory` command comes into play.
It takes 3 arguments:
- `directory` - the directory to export
- `filetype` - the filetype to export to
- `output-dir` (optional) - a custom output directory to use. If not provided will fall back to `config.public.export_dir`
  (see [configuration](#configuration)).
--]]

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
            export = {
                args = 1,
                condition = "norg",

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
        })
    end)
end

module.config.public = {
    --- The directory to export to when running `:Neorg export directory`.
    -- The string can be formatted with the special keys: `<export-dir>` and `<language>`.
    export_dir = "<export-dir>/<language>-export",
}

module.public = {
    --- Returns a module that can handle conversion from `.norg` to the target filetype
    ---@param ftype string #The filetype to export to (as returned by e.g. `get_filetype()`)
    ---@return table,table #The export module and its configuration, else nil
    get_converter = function(ftype)
        if not neorg.modules.is_module_loaded("core.export." .. ftype) then
            if not neorg.modules.load_module("core.export." .. ftype) then
                return
            end
        end

        return neorg.modules.get_module("core.export." .. ftype),
            neorg.modules.get_module_config("core.export." .. ftype)
    end,

    --- Takes a buffer and exports it to a specific file
    ---@param buffer number #The buffer ID to read the contents from
    ---@param filetype string #A Neovim filetype to specify which language to export to
    ---@return string #The entire buffer parsed, converted and returned as a string.
    export = function(buffer, filetype)
        local converter, converter_config = module.public.get_converter(filetype)

        if not converter then
            log.error("Unable to export file - did not find exporter for filetype '" .. filetype .. "'.")
            return
        end

        -- Each converter must have a `extension` field in its public config
        -- This is done to do a backwards lookup, e.g. `markdown` uses the `.md` file extension.
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

        -- Initialize the state. The state is a table that exists throughout the entire duration
        -- of the export, and can be used to e.g. retain indent levels and/or keep references.
        local state = converter.export.init_state and converter.export.init_state() or {}
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        --- Descends down a node and its children
        ---@param start userdata #The TS node to begin at
        ---@return string #The exported/converted node as a string
        local function descend(start)
            -- We do not want to parse erroneous nodes, so we skip them instead
            if start:type() == "ERROR" then
                return ""
            end

            local output = {}

            for node in start:iter_children() do
                -- See if there is a conversion function for the specific node type we're dealing with
                local exporter = converter.export.functions[node:type()]

                if exporter then
                    -- The value of `exporter` can be of 3 different types:
                    --  a function, in which case it should be executed
                    --  a boolean (true), which signifies to use the content of the node as-is without changing anything
                    --  a string, in which case every time the node is encountered it will always be converted to a static value
                    if type(exporter) == "function" then
                        -- An exporter function can return output string or table with 3 values:
                        --  `output` - the converted text
                        --  `keep_descending`  - if true will continue to recurse down the current node's children despite the current
                        --                      node already being parsed
                        --  `state`   - a modified version of the state that then gets merged into the main state table
                        local result = exporter(vim.treesitter.get_node_text(node, buffer), node, state, ts_utils)

                        if type(result) == "table" then
                            state = result.state and vim.tbl_extend("force", state, result.state) or state

                            if result.output then
                                table.insert(output, result.output)
                            end

                            if result.keep_descending then
                                if state.parse_as then
                                    node = module.required["core.integrations.treesitter"].get_document_root(
                                        "\n" .. vim.treesitter.get_node_text(node, buffer),
                                        state.parse_as
                                    )
                                    state.parse_as = nil
                                end

                                local ret = descend(node)

                                if ret then
                                    table.insert(output, ret)
                                end
                            end
                        elseif type(result) == "string" then
                            table.insert(output, result)
                        end
                    elseif exporter == true then
                        table.insert(
                            output,
                            module.required["core.integrations.treesitter"].get_node_text(node, buffer)
                        )
                    else
                        table.insert(output, exporter)
                    end
                else -- If no exporter exists for the current node then keep descending
                    local ret = descend(node)

                    if ret then
                        table.insert(output, ret)
                    end
                end
            end

            -- Recollectors exist to collect all the converted children nodes of a parent node
            -- and to optionally rearrange them into a new layout. Consider the following Neorg markup:
            --  $ Term
            --    Definition
            -- The markdown version looks like this:
            --  Term
            --  : Definition
            -- Without a recollector such a conversion wouldn't be possible, as by simply converting each
            -- node individually you'd end up with:
            --  : Term
            --    Definition
            --
            -- The recollector can encounter a `definition` node, see the nodes it is made up of ({ ": ", "Term", "Definition" })
            -- and rearrange its components to { "Term", ": ", "Definition" } to then achieve the desired result.
            local recollector = converter.export.recollectors[start:type()]

            return recollector and table.concat(recollector(output, state, start, ts_utils) or {})
                or (not vim.tbl_isempty(output) and table.concat(output))
        end

        local output = descend(document_root)

        -- Every converter can also come with a `cleanup` function that performs some final tweaks to the output string
        return converter.export.cleanup and converter.export.cleanup(output) or output, converter_config.extension
    end,
}

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.export.to-file" then
        -- Syntax: Neorg export to-file file.extension forced-filetype?
        -- Example: Neorg export to-file my-custom-file markdown

        local filepath = vim.fn.expand(event.content[1])
        local filetype = neorg.utils.get_filetype(filepath, event.content[2])
        local exported = module.public.export(event.buffer, filetype)

        vim.loop.fs_open(filepath, "w", 438, function(err, fd)
            assert(not err, neorg.lib.lazy_string_concat("Failed to open file '", filepath, "' for export: ", err))

            vim.loop.fs_write(fd, exported, 0, function(werr)
                assert(
                    not werr,
                    neorg.lib.lazy_string_concat("Failed to write to file '", filepath, "' for export: ", werr)
                )
            end)

            vim.schedule(neorg.lib.wrap(vim.notify, "Successfully exported 1 file!"))
        end)
    elseif event.type == "core.neorgcmd.events.export.directory" then
        local path = event.content[3] and vim.fn.expand(event.content[3])
            or module.config.public.export_dir
                :gsub("<language>", event.content[2])
                :gsub("<export%-dir>", event.content[1])
        vim.fn.mkdir(path, "p")

        -- The old value of `eventignore` is stored here. This is done because the eventignore
        -- value is set to ignore BufEnter events before loading all the Neorg buffers, as they can mistakenly
        -- activate the concealer, which not only slows down performance notably but also causes errors.
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
                        local filepath = vim.fn.expand(event.content[1]) .. "/" .. name

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

                            vim.loop.fs_write(fd, exported, 0, function(werr)
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
