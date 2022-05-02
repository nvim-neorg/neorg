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
                file = {},
                -- directory = {},
            }
        },

        data = {
            tangle = {
                args = 1,

                subcommands = {
                    file = {
                        max_args = 1,
                        name = "core.tangle.file",
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

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.core.tangle.file" then
        local buffer = event.buffer

        if event.content[1] then
            buffer = vim.fn.bufadd(event.content[1])
            vim.fn.bufload(buffer)
        end

        local parsed_document_metadata = module.required["core.integrations.treesitter"].get_document_metadata(event.buffer)

        if vim.tbl_isempty(parsed_document_metadata) then
            log.error("Unable to tangle document - no document metadata present!")
            return
        end

        if not parsed_document_metadata.tangle then
            log.error("Unable to tangle document - no tangling information provided within metadata!")
            return
        end

        local document_root = module.required["core.integrations.treesitter"].get_document_root(buffer)

        local options = {
            files = parsed_document_metadata.tangle.files or { "" },
            languages = parsed_document_metadata.tangle.languages or "all",
            scope = parsed_document_metadata.tangle.scope or "all", -- "all" | "tagged" (unimplemented)
        }

        local bound_files = {}

        if type(parsed_document_metadata.tangle) == "string" then
            options.files[1] = parsed_document_metadata.tangle
            options.languages[1] = neorg.utils.get_filetype(parsed_document_metadata.tangle)
            bound_files[options.languages[1]] = options.files[1]
        else
            for _, file in ipairs(options.files) do
                local filetype = neorg.utils.get_filetype(file)

                if options.languages == "all" or vim.tbl_contains(options.languages, filetype) then
                    bound_files[filetype] = file
                end
            end
        end

        local tangles = {}

        for _, filetype in type(options.languages) ~= "table"
            and (function() -- This is fine
                local mem = { "" }
                local prev = nil

                return function()
                    prev = next(mem, prev)
                    return prev, ".*"
                end
            end)()
            or ipairs(options.languages) -- FIX: This errors out for some reason
            do

            local query = vim.treesitter.parse_query("norg", ([[
                    (ranged_tag
                        (tag_name) @_name
                        (tag_parameters
                            parameter: (tag_param) @_language
                            .
                        )
                        (#eq? @_name "code")
                        (#match? @_language "^%s$")
                    ) @code
                ]]):format(filetype))

            for id, node in query:iter_captures(document_root, buffer) do
                if query.captures[id] == "code" then
                    if node:parent():type() == "carryover_tag_set" then
                        for tag in node:parent():iter_children() do
                            if tag:type() == "carryover_tag" then
                                local carryover_tag_name = tag:named_child(0)
                                local carryover_tag_params = tag:named_child(1)

                                if vim.treesitter.get_node_text(carryover_tag_name, buffer) == "tangle" then
                                    log.warn('ok')
                                    if carryover_tag_params then
                                        local filepath = vim.trim(vim.treesitter.get_node_text(carryover_tag_params, buffer))

                                        tangles[filepath] = tangles[filepath] or {}
                                        table.insert(tangles[filepath], node)
                                    elseif bound_files[filetype] then
                                        -- Figure out which file to tangle to
                                        local file_to_tangle_to = bound_files[filetype]
                                        tangles[file_to_tangle_to] = tangles[file_to_tangle_to] or {}
                                        table.insert(tangles[file_to_tangle_to], node)
                                    end
                                end
                            end
                        end
                    elseif bound_files[filetype] then
                        -- Figure out which file to tangle to
                        local file_to_tangle_to = bound_files[filetype]
                        tangles[file_to_tangle_to] = tangles[file_to_tangle_to] or {}
                        table.insert(tangles[file_to_tangle_to], node)
                    elseif filetype == ".*" then
                        local language = vim.trim(vim.treesitter.get_node_text(node:named_child(1):named_child(0), buffer))

                        local file_to_tangle_to = bound_files[language]

                        if file_to_tangle_to then
                            tangles[file_to_tangle_to] = tangles[file_to_tangle_to] or {}
                            table.insert(tangles[file_to_tangle_to], node)
                        end
                    end
                end
            end
        end

        log.warn(tangles)
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["core.tangle.file"] = true,
        ["core.tangle.directory"] = true,
    }
}

return module
