require("neorg.modules.base")

local module = neorg.modules.create("core.integrations.vim-vsnip")

module.load = function() end

module.public = {
    create_snippets = function()
        local snippets_base = module.public.get_snippets()
        local snippets_file = require("neorg.external.helpers").get_package_path() .. "/snippets/norg.json"
        local snippets = ""

        local make_snippet = function(snippet)
            local name = snippet.name or snippet.trigger
            local snip = '  "' .. name .. '": {\n    "prefix": "' .. snippet.trigger .. '",\n    "body": [\n'
            local converted = '      "'
            local insertions = 1
            for i, part in ipairs(snippet.body) do
                local line_end = (i ~= #snippet.body and ",\n" or "\n")
                if type(part) == "string" then
                    converted = converted .. part
                elseif type(part) == "table" then
                    if part.insert then
                        converted = converted .. "${" .. insertions .. ":" .. part.insert .. "}"
                        insertions = insertions + 1
                    elseif part.cursor then
                        converted = converted .. "$" .. insertions
                        insertions = insertions + 1
                    elseif part.ending then
                        converted = converted .. '$0"\n'
                    elseif part.newline then
                        if type(part.newline) == "string" then
                            converted = converted .. '"' .. line_end .. '      "' .. part.newline
                        else
                            converted = converted .. '"' .. line_end
                        end
                    end
                end
            end
            snip = snip .. converted
            snip = snip .. '    ],\n    "description": "' .. snippet.description .. '"\n  }'
            return snip
        end

        if not vim.loop.fs_access(snippets_file, "RW") then
            snippets = snippets .. "{\n"
            for i, snippet in ipairs(snippets_base) do
                snippets = snippets .. make_snippet(snippet)
                snippets = snippets .. (i ~= #snippets_base and ",\n" or "\n")
            end
            snippets = snippets .. "}"
            local file = io.open(snippets_file, "w")
            io.output(file)
            io.write(snippets)
            io.close(file)
        end
    end,
}

return module
