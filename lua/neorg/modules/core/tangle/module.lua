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
                file= {},
                directory = {},
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
                    directory = {
                        max_args = 1,
                        name = "core.tangle.directory",
                    }
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
            files = { "" },
            languages = {},
            scope = "all", -- "all" | "tagged" (unimplemented)
        }

        if type(parsed_document_metadata.tangle) == "string" then
            options.files[1] = parsed_document_metadata.tangle
        end

        local filetype = neorg.utils.get_filetype(parsed_document_metadata.tangle)

        local query = vim.treesitter.parse_query("norg", ([[
                (ranged_tag
                    (tag_name) @_name
                    (tag_parameters
                        parameter: (tag_param) @_language
                        .
                    )
                    (#eq? @_name "code")
                    (#eq? @_language "%s")
                ) @code
            ]]):format(filetype))

        for id, node in query:iter_captures(document_root, buffer) do
            if query.captures[id] == "code" then

            end
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["core.tangle.file"] = true,
        ["core.tangle.directory"] = true,
    }
}

return module
