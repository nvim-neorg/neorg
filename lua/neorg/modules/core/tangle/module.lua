--[[
    File: Tangling
    Summary: An Advanced Code Block Exporter.
    ---
The goal of this module is to allow users to spit out the contents of code blocks into
many different files. This is the primary component required for a literate configuration in Neorg.

## Commands
- `:Neorg tangle current-file` - performs all possible tangling operations on the current file

## Mini-Tutorial
By default, *zero* code blocks are tangled. You must provide where you'd like to tangle each code block manually (we'll get to global configuration later).
To do so, add a `#tangle <output-file>` tag above the code block you'd wish to export. For example:

```norg
#tangle init.lua
@code lua
print("Hello World!")
@end
```
The above snippet will *only* tangle that single code block to the desired output file: `init.lua`.

### Global Tangling for Single Files
Apart from tangling a single or a set of code blocks, you can declare a global output file in the document's metadata:
```norg
@document.meta
tangle: ./init.lua
@end
```

This will tangle all `lua` code blocks to `init.lua`, *unless* the code block has an explicit `#tangle` tag associated with it, in which case
the `#tangle` tag takes precedence.

### Global Tangling for Multiple Files
Apart from a single filepath, you can provide many in an array:
```norg
@document.meta
tangle: [
    ./init.lua
    ./output.hs
]
@end
```

The above snippet tells the Neorg tangling engine to tangle all `lua` code blocks to `./init.lua` and all `haskell` code blocks to `./output.hs`.
As always if any of the code blocks have a `#tangle` tag then that takes precedence.

### Ignoring Code Blocks
Sometimes when tangling you may want to omit some code blocks. For this you may use the `#tangle.none` tag:
```norg
#tangle.none
@code lua
print("I won't be tangled!")
@end
```

### Global Tangling with Extra Options
But wait, it doesn't stop there! You can supply a string to `tangle`, an array to `tangle`, but also an object!
It looks like this:
```norg
@document.meta
tangle: {
    languages: {
        lua: ./output.lua
        haskell: my-haskell-file
    }
    scope: all
}
@end
```

The `scope` option is discussed in a [later section](#tangling-scopes), what we want to focus on is the `languages` object.
It's a simple language-filepath mapping, but it's especially useful when the output file's language type cannot be inferred from the name.
So far we've been using `init.lua`, `output.hs` - but what if we wanted to export all `haskell` code blocks into `my-file-without-an-extension`?
The only way to do that is through the `languages` object, where we explicitly define the language to tangle. Neat!

### Tangling Scopes
What you've seen so far is the tangler operating in `all` mode. This means it captures all code blocks of a certain type unless that code block is tagged
with `#tangle.none`. There are two other types: `tagged` and `main`.

#### The `tagged` Scope
When in this mode, the tangler will only tangle code blocks that have been `tagged` with a `#tangle` tag.
Note that you don't have to always provide a filetype, and that:
```norg
#tangle
@code lua
@end
```
Will use the global output file for that language as defined in the metadata. I.e., if I do:
```norg
@document.meta
tangle: {
    languages: {
        lua: ./output.lua
    }
    scope: tagged
}
@end

@code lua
print("Hello")
@end

#tangle
@code lua
print("Sup")
@end

#tangle other-file.lua
@code lua
print("Ayo")
@end
```
The first code block will not be touched, the second code block will be tangled to `./output.lua` and the third code block will be tangled to `other-file.lua`. You
can probably see that this system can get expressive pretty quick.

#### The `main` scope
This mode is the opposite of the `tagged` one in that it will only tangle code blocks to files that are defined in the document metadata. I.e. in this case:
```norg
@document.meta
tangle: {
    languages: {
        lua: ./output.lua
    }
    scope: main
}
@end

@code lua
print("Hello")
@end

#tangle
@code lua
print("Sup")
@end

#tangle other-file.lua
@code lua
print("Ayo")
@end
```
The first code block will be tangled to `./output.lua`, the second code block will also be tangled to `./output.lua` and the third code block will be ignored.
--]]

local module = neorg.modules.create("core.tangle")

module.setup = function()
    return {
        requires = {
            "core.integrations.treesitter",
            "core.neorgcmd",
        },
    }
end

module.load = function()
    module.required["core.neorgcmd"].add_commands_from_table({
        tangle = {
            args = 1,
            condition = "norg",

            subcommands = {
                ["current-file"] = {
                    args = 0,
                    name = "core.tangle.current-file",
                },
                -- directory = {
                --     max_args = 1,
                --     name = "core.tangle.directory",
                -- }
            },
        },
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
            options.languages[neorg.utils.get_filetype(parsed_document_metadata.tangle)] =
                parsed_document_metadata.tangle
        end

        local tangles = {
            -- filename = { content }
        }

        local query_str = neorg.lib.match(options.scope)({
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
        })

        local query = vim.treesitter.parse_query("norg", query_str)

        for id, node in query:iter_captures(document_root, buffer, 0, -1) do
            local capture = query.captures[id]

            if capture == "tag" then
                local parsed_tag = module.required["core.integrations.treesitter"].get_tag_info(node)

                if parsed_tag then
                    local file_to_tangle_to = options.languages[parsed_tag.parameters[1]]
                    local content = parsed_tag.content

                    if parsed_tag.parameters[1] == "norg" then
                        for i, line in ipairs(content) do
                            -- remove escape char
                            local new_line, _ = line:gsub("\\(.?)", "%1")
                            content[i] = new_line or ""
                        end
                    end

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
                        vim.list_extend(tangles[file_to_tangle_to], content)
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

        local file_count = vim.tbl_count(tangles)
        local tangled_count = 0

        for file, content in pairs(tangles) do
            vim.loop.fs_open(vim.fn.expand(file), "w", 438, function(err, fd)
                file_count = file_count - 1
                assert(not err, neorg.lib.lazy_string_concat("Failed to open file '", file, "' for tangling: ", err))

                vim.loop.fs_write(fd, table.concat(content, "\n"), 0, function(werr)
                    assert(
                        not werr,
                        neorg.lib.lazy_string_concat("Failed to write to file '", file, "' for tangling: ", werr)
                    )
                end)

                tangled_count = tangled_count + 1
                if file_count == 0 then
                    vim.schedule(
                        neorg.lib.wrap(
                            vim.notify,
                            string.format(
                                "Successfully tangled %d file%s!",
                                tangled_count,
                                tangled_count == 1 and "" or "s"
                            )
                        )
                    )
                end
            end)
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["core.tangle.current-file"] = true,
        ["core.tangle.directory"] = true,
    },
}

return module
