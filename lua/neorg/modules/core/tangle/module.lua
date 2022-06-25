--[[ TODO ]]

local module = neorg.modules.create("core.tangle")

module.setup = function()
    return {
        requires = {
            "core.integrations.treesitter",
            "core.neorgcmd"
        }
    }
end

module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        definitions = {
            tangle = {
                ["current-file"] = {},
                -- directory = {},
            }
        },

        data = {
            tangle = {
                args = 1,

                subcommands = {
                    ["current-file"] = {
                        args = 0,
                        name = "core.tangle.current-file",
                    },
                    -- directory = {
                    --     max_args = 1,
                    --     name = "core.tangle.directory",
                    -- }
                }
            }
        }
    })
end

module.public = {
    tangle = function(buffer)
        local parsed_document_metadata = module.required["core.integrations.treesitter"].get_document_metadata(buffer)

        if vim.tbl_isempty(parsed_document_metadata) or not parsed_document_metadata.tangle then
            parsed_document_metadata = {
                tangle = {},
            }
        end

        local document_root = module.required["core.integrations.treesitter"].get_document_root(buffer)

        local options = {
            languages = {},
            scope = parsed_document_metadata.tangle.scope or "all", -- "all" | "tagged" | "main"
        }

        if type(parsed_document_metadata.tangle) == "table" then
            if vim.tbl_islist(parsed_document_metadata.tangle) then
                for _, file in ipairs(parsed_document_metadata.tangle) do
                    options.languages[neorg.utils.get_filetype(file)] = file
                end
            elseif parsed_document_metadata.tangle.languages then
                for language, file in pairs(parsed_document_metadata.tangle.languages) do
                    options.languages[language] = file
                end
            end
        elseif type(parsed_document_metadata.tangle) == "string" then
            options.languages[neorg.utils.get_filetype(parsed_document_metadata.tangle)] = parsed_document_metadata.tangle
        end

        local tangles = {
            -- filename = { content }
        }

        local query_str = neorg.lib.match(options.scope) {
            _ = [[
                (ranged_tag
                    name: (tag_name) @_name
                    (#eq? @_name "code")
                    (tag_parameters
                        .
                        parameter: (tag_param) @_language)) @tag
            ]],
            tagged = [[
                (carryover_tag_set
                    (carryover_tag
                        name: (tag_name) @_carryover_tag_name
                        (#eq? @_carryover_tag_name "tangle"))
                    (ranged_tag
                        name: (tag_name) @_name
                        (#eq? @_name "code")
                        (tag_parameters
                            .
                            parameter: (tag_param) @_language)) @tag)
            ]],
        }

        local query = vim.treesitter.parse_query("norg", query_str)

        for id, node in query:iter_captures(document_root, buffer, 0, -1) do
            local capture = query.captures[id]

            if capture == "tag" then
                local parsed_tag = module.required["core.integrations.treesitter"].get_tag_info(node)

                if parsed_tag then
                    local file_to_tangle_to = options.languages[parsed_tag.parameters[1]]

                    for _, attribute in ipairs(parsed_tag.attributes) do
                        if attribute.name == "tangle.none" then
                            goto skip_tag
                        elseif attribute.name == "tangle" and attribute.parameters[1] then
                            if options.scope == "main" then
                                goto skip_tag
                            end

                            file_to_tangle_to = table.concat(attribute.parameters)
                        end
                    end

                    if file_to_tangle_to then
                        tangles[file_to_tangle_to] = tangles[file_to_tangle_to] or {}
                        vim.list_extend(tangles[file_to_tangle_to], parsed_tag.content)
                    end

                    ::skip_tag::
                end
            end
        end

        return tangles
    end,
}

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.core.tangle.current-file" then
        local tangles = module.public.tangle(event.buffer)

        if not tangles or vim.tbl_isempty(tangles) then
            vim.notify("Nothing to tangle!")
            return
        end

        for file, content in pairs(tangles) do
            vim.loop.fs_open(file, "w", 438, function(err, fd)
                assert(
                    not err,
                    neorg.lib.lazy_string_concat("Failed to open file '", file, "' for tangling: ", err)
                )

                vim.loop.fs_write(fd, table.concat(content, "\n"), 0, function(werr)
                    assert(
                        not werr,
                        neorg.lib.lazy_string_concat("Failed to write to file '", file, "' for tangling: ", werr)
                    )
                end)

                vim.schedule(neorg.lib.wrap(vim.notify, "Successfully tangled 1 file!"))
            end)
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["core.tangle.current-file"] = true,
        ["core.tangle.directory"] = true,
    }
}

return module
