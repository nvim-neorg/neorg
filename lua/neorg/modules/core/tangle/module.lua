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

module.public = {
    tangle = function(buffer)
        local parsed_document_metadata = module.required["core.integrations.treesitter"].get_document_metadata(buffer)

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
        end

        local tangles = {
            -- filename = { content }
        }

        local query_str = neorg.lib.match(options.scope) {
            all = [[
                (ranged_tag
                    name: (tag_name) @_name
                    (#eq? @_name "code")
                    (tag_parameters
                        .
                        parameter: (tag_param) @_language)
                        (#any-of? @_language "%s")) @tag
            ]],
            tagged = [[
                (carryover_tag
                    name: (tag_name) @_carryover_tag_name
                    (#eq? @_carryover_tag_name "tangle"))
                .
                (ranged_tag
                    name: (tag_name) @_name
                    (#eq? @_name "code")
                    (tag_parameters
                        .
                        parameter: (tag_param) @_language)
                        (#any-of? @_language "%s")) @tag
            ]],
        }

        local query = vim.treesitter.parse_query("norg", string.format(query_str, table.concat(vim.tbl_keys(options.languages), "\" \"")))

        for id, node in query:iter_captures(document_root, buffer, 0, -1) do
            local capture = query.captures[id]

            if capture == "tag" then
                local parsed_tag = module.required["core.integrations.treesitter"].get_tag_info(node)

                if parsed_tag then
                    local file_to_tangle_to = options.languages[parsed_tag.parameters[1]]

                    for _, attribute in ipairs(parsed_tag.attributes) do
                        if attribute.name == "tangle" and attribute.parameters[1] then
                            file_to_tangle_to = table.concat(attribute.parameters)
                        end
                    end

                    tangles[file_to_tangle_to] = tangles[file_to_tangle_to] or {}
                    vim.list_extend(tangles[file_to_tangle_to], parsed_tag.content)
                end
            end
        end

        return tangles
    end,
}

module.on_event = function(event)
    if event.type == "core.neorgcmd.events.core.tangle.file" then
        local tangles = module.public.tangle(event.buffer)
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
