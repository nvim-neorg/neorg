--[[
    file: Tangling
    title: From Code Blocks to Files
    description: The `core.tangle` module exports code blocks within a `.norg` file straight to a file of your choice.
    summary: An Advanced Code Block Exporter.
    ---
The goal of this module is to allow users to spit out the contents of code blocks into
many different files. This is the primary component required for a literate configuration in Neorg,
where the configuration is annotated and described in a `.norg` document, and the actual code itself
is thrown out into a file that can then be normally consumed by e.g. an application.

The `tangle` module currently provides a single command:
- `:Neorg tangle current-file` - performs all possible tangling operations on the current file

### Usage Tutorial
By default, *zero* code blocks are tangled. You must provide where you'd like to tangle each code block manually (global configuration will be discussed later).
To do so, add a `#tangle <output-file>` tag above the code block you'd wish to export. For example:

```norg
#tangle init.lua
@code lua
print("Hello World!")
@end
```
The above snippet will *only* tangle that single code block to the desired output file: `init.lua`.

#### Global Tangling for Single Files
Apart from tangling a single or a set of code blocks, you can declare a global output file in the document's metadata:
```norg
@document.meta
tangle: ./init.lua
@end
```

This will tangle all `lua` code blocks to `init.lua`, *unless* the code block has an explicit `#tangle` tag associated with it, in which case
the `#tangle` tag takes precedence.

#### Global Tangling for Multiple Files
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

#### Ignoring Code Blocks
Sometimes when tangling you may want to omit some code blocks. For this you may use the `#tangle.none` tag:
```norg
#tangle.none
@code lua
print("I won't be tangled!")
@end
```

#### Global Tangling with Extra Options
But wait, it doesn't stop there! You can supply a string to `tangle`, an array to `tangle`, but also an object!
It looks like this:
```norg
@document.meta
tangle: {
    languages: {
        lua: ./output.lua
        haskell: my-haskell-file
    }
    delimiter: heading
    scope: all
}
@end
```

The `language` option determines which filetype should go into which file.
It's a simple language-filepath mapping, but it's especially useful when the output file's language type cannot be inferred from the name or shebang.
It is also possible to use the name `_` as a catch all to direct output for all files not otherwise listed.

The `delimiter` option determines how to delimit code blocks that exports to the same file.
The following alternatives are allowed:

* `heading` -- Try to determine the filetype of the code block and insert the current heading as a comment as a delimiter.
  If filetype detection fails, `newline` will be used instead.
* `newline` -- Use an extra newline between blocks.
* `none` -- Do not add delimiter. This implies that the code blocks are inserted into the tangle target as-is.

The `scope` option is discussed below.

#### Tangling Scopes
What you've seen so far is the tangler operating in `all` mode. This means it captures all code blocks of a certain type unless that code block is tagged
with `#tangle.none`. There are two other types: `tagged` and `main`.

##### The `tagged` Scope
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

##### The `main` scope
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

local neorg = require("neorg.core")
local lib, modules, utils = neorg.lib, neorg.modules, neorg.utils

local module = modules.create("core.tangle")

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


local function get_comment_string(language)
    local cur_buf = vim.api.nvim_get_current_buf()
    local tmp_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(tmp_buf)
    vim.bo.filetype = language
    local commentstring = vim.bo.commentstring
    vim.api.nvim_set_current_buf(cur_buf)
    vim.api.nvim_buf_delete(tmp_buf, { force = true })
    return commentstring
end


module.public = {
    tangle = function(buffer)
        local treesitter = module.required["core.integrations.treesitter"]
        local parsed_document_metadata = treesitter.get_document_metadata(buffer) or {}
        local tangle_settings = parsed_document_metadata.tangle or {}
        local options = {
            languages = tangle_settings.languages or tangle_settings,
            scope = tangle_settings.scope or "all", -- "all" | "tagged" | "main"
            delimiter = tangle_settings.delimiter or "newline", -- "newline" | "heading" | "none"
        }
        if vim.tbl_islist(options.languages) then
            options.filenames_only = options.languages
            options.languages = {}
        elseif type(options.languages) == string then
            options.languages = {_ = options.languages}
        end

        local document_root = treesitter.get_document_root(buffer)
        local filename_to_languages = {}
        local tangles = {
            -- filename = { content }
        }

        local query_str = lib.match(options.scope)({
            _ = [[
                (ranged_verbatim_tag
                    name: (tag_name) @_name
                    (#eq? @_name "code")
                    (tag_parameters
                       .
                       (tag_param) @_language)) @tag
            ]],
            tagged = [[
                (ranged_verbatim_tag
                    [(strong_carryover_set
                        (strong_carryover
                          name: (tag_name) @_strong_carryover_tag_name
                          (#eq? @_strong_carryover_tag_name "tangle")))
                     (weak_carryover_set
                        (weak_carryover
                          name: (tag_name) @_weak_carryover_tag_name
                          (#eq? @_weak_carryover_tag_name "tangle")))]
                  name: (tag_name) @_name
                  (#eq? @_name "code")
                  (tag_parameters
                    .
                    (tag_param) @_language)) @tag
            ]],
        })

        local query = utils.ts_parse_query("norg", query_str)
        local previous_headings = {}
        local commentstrings = {}

        for id, node in query:iter_captures(document_root, buffer, 0, -1) do
            local capture = query.captures[id]

            if capture == "tag" then
                local parsed_tag = treesitter.get_tag_info(node)

                if parsed_tag then
                    local declared_filetype = parsed_tag.parameters[1]
                    local content = parsed_tag.content

                    if parsed_tag.parameters[1] == "norg" then
                        for i, line in ipairs(content) do
                            -- remove escape char
                            local new_line, _ = line:gsub("\\(.?)", "%1")
                            content[i] = new_line or ""
                        end
                    end

                    local file_to_tangle_to
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

                    -- determine tangle file target
                    if not file_to_tangle_to then
                        if declared_filetype and options.languages[declared_filetype] then
                            file_to_tangle_to = options.languages[declared_filetype]
                        else
                            if options.filenames_only then
                                for _, filename in ipairs(options.filenames_only) do
                                    if declared_filetype == vim.filetype.match({ filename=filename, contents=content }) then
                                        file_to_tangle_to = filename
                                        break
                                    end
                                end
                            end
                            if not file_to_tangle_to then
                                file_to_tangle_to = options.languages["_"]
                            end
                            if declared_filetype then
                                options.languages[declared_filetype] = file_to_tangle_to
                            end
                        end
                    end
                    if not file_to_tangle_to then
                        goto skip_tag
                    end

                    if options.delimiter == "heading" then
                        local language
                        if filename_to_languages[file_to_tangle_to] then
                            language = filename_to_languages[file_to_tangle_to]
                        else
                            language = vim.filetype.match({filename = file_to_tangle_to, contents = content})
                            if not language and declared_filetype then
                                language = vim.filetype.match({ filename="___." .. declared_filetype, contents=content })
                            end
                            filename_to_languages[file_to_tangle_to] = language
                        end

                        -- get current heading
                        local heading_string
                        local heading = treesitter.find_parent(node, "heading%d+")
                        if heading and heading:named_child(1) then
                            local srow, scol, erow, ecol = heading:named_child(1):range()
                            heading_string = vim.api.nvim_buf_get_text(0, srow, scol, erow, ecol, {})[1]
                        end

                        -- don't reuse the same header more than once
                        if heading_string and language and previous_headings[language] ~= heading then

                            -- Get commentstring from vim scratch buffer
                            if not commentstrings[language] then
                                commentstrings[language] = get_comment_string(language)
                            end
                            if commentstrings[language] ~= "" then
                                table.insert(content, 1, "")
                                table.insert(content, 1, commentstrings[language]:format(heading_string))
                                previous_headings[language] = heading
                            end
                        end
                    end

                    if not tangles[file_to_tangle_to] then
                        tangles[file_to_tangle_to] = {}
                    elseif options.delimiter ~= "none" then
                        table.insert(content, 1, "")
                    end

                    vim.list_extend(tangles[file_to_tangle_to], content)

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
            utils.notify("Nothing to tangle!", vim.log.levels.WARN)
            return
        end

        local file_count = vim.tbl_count(tangles)
        local tangled_count = 0

        for file, content in pairs(tangles) do
            vim.loop.fs_open(vim.fn.expand(file), "w", 438, function(err, fd)
                file_count = file_count - 1
                assert(not err, lib.lazy_string_concat("Failed to open file '", file, "' for tangling: ", err))

                vim.loop.fs_write(fd, table.concat(content, "\n"), 0, function(werr)
                    assert(
                        not werr,
                        lib.lazy_string_concat("Failed to write to file '", file, "' for tangling: ", werr)
                    )
                end)

                tangled_count = tangled_count + 1
                if file_count == 0 then
                    vim.schedule(
                        lib.wrap(
                            utils.notify,
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
