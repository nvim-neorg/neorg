--[[
    file: Completion
    title: Get completions in Neorg files
    summary: A wrapper to interface with several different completion engines.
    ---

This module is an intermediary between Neorg and the completion engine of your choice. After setting up this
module (this usually just involves setting the `engine` field in the [configuration](#configuration) section),
please read the corresponding wiki page for the engine you selected ([`nvim-cmp`](@core.integrations.nvim-cmp)
[`coq_nvim`](@core.integrations.coq_nvim) or [`nvim-compe`](@core.integrations.nvim-compe)) to complete setup.

Completions are provided in the following cases (examples in (), `|` represents the cursor location):
- TODO items (`- (|`)
- @ tags (`@|`)
- \# tags (`#|`)
- file path links (`{:|`) provides workspace relative paths (`:$/workspace/relative/path:`)
- header links (`{*|`)
- fuzzy header links (`{#|`)
- footnotes (`{^|`)
- file path + header links (`{:path:*|`)
- file path + fuzzy header links (`{:path:#|`)
- file path + footnotes (`{:path:^|`)
- anchor names (`[|`)
- link names (`{<somelink>}[|`)

Header completions will show only valid headers at the current level in the current or specified file. All
link completions are smart about closing `:` and `}`.
--]]

local neorg = require("neorg.core")
local Path = require("pathlib")
local log, modules, utils = neorg.log, neorg.modules, neorg.utils
local dirutils, dirman, link_utils, ts

local module = modules.create("core.completion")

module.config.public = {
    -- The engine to use for completion.
    --
    -- Possible values:
    -- - [`"nvim-cmp"`](@core.integrations.nvim-cmp)
    -- - [`"coq_nvim"`](@core.integrations.coq_nvim)
    -- - [`"nvim-compe"`](@core.integrations.nvim-compe)
    -- - `{ module_name = "external.lsp-completion" }` this must be used with
    --   [neorg-interim-ls](https://github.com/benlubas/neorg-interim-ls) and can provide
    --   completions through a shim Language Server. This allows users without an auto complete
    --   plugin to still get Neorg completions
    engine = nil,

    -- The identifier for the Neorg source.
    name = "[Neorg]",
}

module.setup = function()
    return {
        success = true,
        requires = { "core.dirman", "core.dirman.utils", "core.integrations.treesitter", "core.links" },
    }
end

---@class neorg.completion_engine
---@field create_source function

module.private = {
    ---@type neorg.completion_engine
    engine = nil,

    --- Get a list of all norg files in current workspace. Returns { workspace_path, norg_files }
    --- @return { [1]: PathlibPath, [2]: PathlibPath[]|nil }|nil
    get_norg_files = function()
        local current_workspace = dirman.get_current_workspace()
        local norg_files = dirman.get_norg_files(current_workspace[1])
        return { current_workspace[2], norg_files }
    end,

    --- Get the closing characters for a link completion
    --- @param context table
    --- @param colon boolean should there be a closing colon?
    --- @return string "", ":", or ":}" depending on what's needed
    get_closing_chars = function(context, colon)
        local offset = 1
        local closing_colon = ""
        if colon then
            closing_colon = ":"
            if string.sub(context.full_line, context.char + offset, context.char + offset) == ":" then
                closing_colon = ""
                offset = 2
            end
        end

        local closing_brace = "}"
        if string.sub(context.full_line, context.char + offset, context.char + offset) == "}" then
            closing_brace = ""
        end

        return closing_colon .. closing_brace
    end,

    --- query all the linkable items in a given buffer/file for a given link type
    ---@param source number | string | PathlibPath bufnr or file path
    ---@param link_type "generic" | "definition" | "footnote" | string
    get_linkables = function(source, link_type)
        local query_str = link_utils.get_link_target_query_string(link_type)
        local norg_parser, iter_src = ts.get_ts_parser(source)
        if not norg_parser then
            return {}
        end
        local norg_tree = norg_parser:parse()[1]
        local query = vim.treesitter.query.parse("norg", query_str)
        local links = {}
        for id, node in query:iter_captures(norg_tree:root(), iter_src, 0, -1) do
            local capture = query.captures[id]
            if capture == "title" then
                local original_title = ts.get_node_text(node, iter_src)
                if original_title then
                    local title = original_title:gsub("\\", "")
                    title = title:gsub("%s+", " ")
                    title = title:gsub("^%s+", "")
                    table.insert(links, {
                        original_title = original_title,
                        title = title,
                        node = node,
                    })
                end
            end
        end
        return links
    end,

    generate_file_links = function(context, _prev, _saved, _match)
        local res = {}
        local files = module.private.get_norg_files()
        if not files or not files[2] then
            return {}
        end

        local closing_chars = module.private.get_closing_chars(context, true)
        for _, file in pairs(files[2]) do
            if not file:samefile(Path.new(vim.api.nvim_buf_get_name(0))) then
                local rel = file:relative_to(files[1], false)
                if rel and rel:len() > 0 then
                    local link = "$/" .. rel:with_suffix(""):tostring() .. closing_chars
                    table.insert(res, link)
                end
            end
        end

        return res
    end,

    --- Generate list of autocompletion suggestions for links
    --- @param context table
    --- @param source number | string | PathlibPath
    --- @param node_type string
    --- @return string[]
    suggestions = function(context, source, node_type)
        local leading_whitespace = " "
        if context.before_char == " " then
            leading_whitespace = ""
        end
        local links = module.private.get_linkables(source, node_type)
        local closing_chars = module.private.get_closing_chars(context, false)
        return vim.iter(links)
            :map(function(x)
                return leading_whitespace .. x.title .. closing_chars
            end)
            :totable()
    end,

    --- All the things that you can link to (`{#|}` completions)
    local_link_targets = function(context, _prev, _saved, _match)
        return module.private.suggestions(context, 0, "generic")
    end,

    local_heading_links = function(context, _prev, _saved, match)
        local heading_level = match[2] and #match[2]
        return module.private.suggestions(context, 0, ("heading%d"):format(heading_level))
    end,

    foreign_heading_links = function(context, _prev, _saved, match)
        local file = match[1]
        local heading_level = match[2] and #match[2]
        if file then
            file = dirutils.expand_pathlib(file)
            return module.private.suggestions(context, file, ("heading%d"):format(heading_level))
        end
        return {}
    end,

    foreign_generic_links = function(context, _prev, _saved, match)
        local file = match[1]
        if file then
            file = dirutils.expand_pathlib(file)
            return module.private.suggestions(context, file, "generic")
        end
        return {}
    end,

    local_footnote_links = function(context, _prev, _saved, _match)
        return module.private.suggestions(context, 0, "footnote")
    end,

    foreign_footnote_links = function(context, _prev, _saved, match)
        local file = match[2]
        if match[2] then
            file = dirutils.expand_pathlib(file)
            return module.private.suggestions(context, file, "footnote")
        end
        return {}
    end,

    --- The node context for normal norg (ie. not in a code block)
    normal_norg = function(current, previous, _, _)
        -- If no previous node exists then try verifying the current node instead
        if not previous then
            return current and (current:type() ~= "translation_unit" or current:type() == "document") or false
        end

        -- If the previous node is not tag parameters or the tag name
        -- (i.e. we are not inside of a tag) then show auto completions
        return previous:type() ~= "tag_parameters" and previous:type() ~= "tag_name"
    end,
}

---Suggest common link names for the given link. Suggests:
--- - target name if the link point to a heading/footer/etc.
--- - metadata `title` field
--- - file description
---@return string[]
module.private.foreign_link_names = function(_context, _prev, _saved, match)
    local file, target = match[2], match[3]
    local path = dirutils.expand_pathlib(file)
    local meta = ts.get_document_metadata(path)
    local suggestions = {}
    if meta then
        table.insert(suggestions, meta.title)
        table.insert(suggestions, meta.description)
    end
    if target ~= "" then
        table.insert(suggestions, target)
    end
    return suggestions
end

---provide suggestions for anchors that are already defined in the document
---@return string[]
module.private.anchor_suggestions = function(_context, _prev, _saved, _match)
    local suggestions = {}

    local anchor_query_string = [[
        (anchor_definition
            (link_description
              text: (paragraph) @anchor_name ))
    ]]

    ts.execute_query(anchor_query_string, function(query, id, node, _metadata)
        local capture_name = query.captures[id]
        if capture_name == "anchor_name" then
            table.insert(suggestions, ts.get_node_text(node, 0))
        end
    end, 0)
    return suggestions
end

--- suggest the link target name
---@return string[]
module.private.local_link_names = function(_context, _prev, _saved, match)
    local target = match[2]
    if target then
        target = target:gsub("^%s+", "")
        target = target:gsub("%s+$", "")
    end
    return { target }
end

module.load = function()
    -- If we have not defined an engine then bail
    if not module.config.public.engine then
        log.error("No engine specified, aborting...")
        return
    end

    -- check if a custom completion module is provided
    if type(module.config.public.engine) == "table" and module.config.public.engine["module_name"] then
        local completion_module = module.config.public.engine["module_name"]
        modules.load_module_as_dependency(completion_module, module.name, {})
        module.private.engine = modules.get_module(completion_module)
    elseif module.config.public.engine == "nvim-compe" and modules.load_module("core.integrations.nvim-compe") then
        -- If our engine is compe then attempt to load the integration module for nvim-compe
        modules.load_module_as_dependency("core.integrations.nvim-compe", module.name, {})
        module.private.engine = modules.get_module("core.integrations.nvim-compe")
    elseif module.config.public.engine == "nvim-cmp" and modules.load_module("core.integrations.nvim-cmp") then
        modules.load_module_as_dependency("core.integrations.nvim-cmp", module.name, {})
        module.private.engine = modules.get_module("core.integrations.nvim-cmp")
    elseif module.config.public.engine == "coq_nvim" and modules.load_module("core.integrations.coq_nvim") then
        modules.load_module_as_dependency("core.integrations.coq_nvim", module.name, {})
        module.private.engine = modules.get_module("core.integrations.coq_nvim")
    else
        log.error("Unable to load completion module -", module.config.public.engine, "is not a recognized engine.")
        return
    end

    dirutils = module.required["core.dirman.utils"]
    dirman = module.required["core.dirman"]
    link_utils = module.required["core.links"]
    ---@type core.integrations.treesitter
    ts = module.required["core.integrations.treesitter"]

    -- Set a special function in the integration module to allow it to communicate with us
    module.private.engine.invoke_completion_engine = function(context) ---@diagnostic disable-line
        return module.public.complete(context) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
    end

    -- Create the integration engine's source
    module.private.engine.create_source({
        completions = module.config.public.completions,
    })
end

---@class core.completion
module.public = {

    -- Define completions
    completions = {
        { -- Create a new completion (for `@|tags`)
            -- Define the regex that should match in order to proceed
            regex = "^%s*@(%w*)",

            -- If regex can be matched, this item then gets verified via TreeSitter's AST
            node = module.private.normal_norg,

            -- The actual elements to show if the above tests were true
            complete = {
                "table",
                "code",
                "image",
                "embed",
                "document",
            },

            -- Additional options to pass to the completion engine
            options = {
                type = "Tag",
                completion_start = "@",
            },

            -- We might have matched the top level item, but can we match it with any
            -- more precision? Descend down the rabbit hole and try to more accurately match
            -- the line.
            descend = {
                -- The cycle continues
                {
                    regex = "document%.%w*",

                    complete = {
                        "meta",
                    },

                    options = {
                        type = "Tag",
                    },

                    descend = {},
                },
                {
                    -- Define a regex (gets appended to parent's regex)
                    regex = "code%s+%w*",
                    -- No node variable, we don't need that sort of check here

                    complete = utils.get_language_list(true),

                    -- Extra options
                    options = {
                        type = "Language",
                    },

                    -- Don't descend any further, we've narrowed down our match
                    descend = {},
                },
                {
                    regex = "export%s+%w*",

                    complete = utils.get_language_list(true),

                    options = {
                        type = "Language",
                    },

                    descend = {},
                },
                {
                    regex = "tangle%s+%w*",

                    complete = {
                        "<none>",
                    },

                    options = {
                        type = "Property",
                    },
                },
                {
                    regex = "image%s+%w*",

                    complete = {
                        "jpeg",
                        "png",
                        "svg",
                        "jfif",
                        "exif",
                    },

                    options = {
                        type = "Format",
                    },
                },
                {
                    regex = "embed%s+%w*",

                    complete = {
                        "video",
                        "image",
                    },

                    options = {
                        type = "Embed",
                    },
                },
            },
        },
        { -- `#|tags`
            regex = "^%s*%#(%w*)",

            complete = {
                "comment",
                "ordered",
                "time.due",
                "time.start",
                "contexts",
                "waiting.for",
            },

            options = {
                type = "Tag",
            },

            descend = {},
        },
        { -- `@|end` tags
            regex = "^%s*@e?n?",
            node = function(_, previous)
                if not previous then
                    return false
                end

                return previous:type() == "tag_parameters" or previous:type() == "tag_name"
            end,

            complete = {
                "end",
            },

            options = {
                type = "Directive",
                completion_start = "@",
            },
        },
        { -- Detached Modifier Extensions `- (`, `* (`, etc.
            regex = "^%s*[%-*$~^]+%s+%(",

            complete = {
                { "( ) ", label = "( ) (undone)" },
                { "(-) ", label = "(-) (pending)" },
                { "(x) ", label = "(x) (done)" },
                { "(_) ", label = "(_) (cancelled)" },
                { "(!) ", label = "(!) (important)" },
                { "(+) ", label = "(+) (recurring)" },
                { "(=) ", label = "(=) (on hold)" },
                { "(?) ", label = "(?) (uncertain)" },
            },

            options = {
                type = "TODO",
                pre = function()
                    local sub = vim.api.nvim_get_current_line():gsub("^(%s*%-+%s+%(%s*)%)", "%1")

                    if sub then
                        vim.api.nvim_set_current_line(sub)
                    end
                end,

                completion_start = "-",
            },
        },
        { -- links for file paths `{:|`
            regex = "^.*{:([^:}]*)",

            node = module.private.normal_norg,

            complete = module.private.generate_file_links,

            options = {
                type = "File",
                completion_start = "{",
            },
        },
        { -- links that have a file path, suggest any heading from the file `{:...:#|}`
            regex = "^.*{:(.*):#[^}]*",

            complete = module.private.foreign_generic_links,

            node = module.private.normal_norg,

            options = {
                type = "Reference",
                completion_start = "#",
            },
        },
        { -- links that have a file path, suggest direct headings from the file `{:...:*|}`
            regex = "^.*{:(.*):(%*+)[^}]*",

            complete = module.private.foreign_heading_links,

            node = module.private.normal_norg,

            options = {
                type = "Reference",
                completion_start = "*",
            },
        },
        { -- # links to headings in the current file `{#|}`
            regex = "^.*{#[^}]*",

            -- complete = module.private.generate_local_heading_links,
            complete = module.private.local_link_targets,

            node = module.private.normal_norg,

            options = {
                type = "Reference",
                completion_start = "#",
            },
        },
        { -- * links to headings in current file `{*|}`
            regex = "^(.*){(%*+)[^}]*",
            -- the first capture group is a nothing group so that match[2] is reliably the heading
            -- level or nil if there's no heading level.

            complete = module.private.local_heading_links,

            node = module.private.normal_norg,

            options = {
                type = "Reference",
                completion_start = "*",
            },
        },
        { -- ^ footnote links in the current file `{^|}`
            regex = "^(.*){%^[^}]*",

            complete = module.private.local_footnote_links,

            node = module.private.normal_norg,

            options = {
                type = "Reference",
                completion_start = "^",
            },
        },
        { -- ^ footnote links in another file `{:path:^|}`
            regex = "^(.*){:(.*):%^[^}]*",

            complete = module.private.foreign_footnote_links,

            node = module.private.normal_norg,

            options = {
                type = "Reference",
                completion_start = "^",
            },
        },
        { -- foreign link name suggestions `{:path:target}[|]`
            regex = "^(.*){:([^:]*):[#$*%^]* ([^}]*)}%[",

            complete = module.private.foreign_link_names,

            node = module.private.normal_norg,

            options = {
                type = "Reference",
                completion_start = "[",
            },
        },
        { -- local link name suggestions `{target}[|]` for `#`, `$`, `^`, `*` link targets
            regex = "^(.*){[#$*%^]+ ([^}]*)}%[",

            complete = module.private.local_link_names,

            node = module.private.normal_norg,

            options = {
                type = "Reference",
                completion_start = "[",
            },
        },
        { -- complete anchor names that exist in the current buffer ` [|`
            regex = {
                "^(.*)[^}]%[",
                "^%[",
            },

            complete = module.private.anchor_suggestions,

            node = module.private.normal_norg,

            options = {
                type = "Reference",
                completion_start = "[",
            },
        },
    },

    --- Parses the public completion table and attempts to find all valid matches
    ---@param context table #The context provided by the integration engine
    ---@param prev table? #The previous table of completions - used for descent
    ---@param saved string? #The saved regex in the form of a string, used to concatenate children nodes with parent nodes' regexes
    complete = function(context, prev, saved)
        -- If the save variable wasn't passed then set it to an empty string
        saved = saved or ""

        -- If we haven't defined any explicit table to read then read the public completions table
        local completions = prev or module.public.completions

        -- Loop through every completion
        for _, completion_data in ipairs(completions) do
            -- If the completion data has a regex variable
            if completion_data.regex then
                local regexes

                if type(completion_data.regex) == "string" then
                    regexes = { completion_data.regex }
                elseif type(completion_data.regex) == "table" then
                    ---@diagnostic disable-next-line: cast-local-type
                    regexes = completion_data.regex
                else
                    break
                end

                local match = {}
                -- Attempt to match the current line before the cursor with any of the regex
                -- expressions in the list, first one to succeed is used
                ---@diagnostic disable-next-line: param-type-mismatch
                for _, regex in ipairs(regexes) do
                    match = { context.line:match(saved .. regex .. "$") }
                    if not vim.tbl_isempty(match) then
                        break
                    end
                end

                -- If our match was successful
                if not vim.tbl_isempty(match) then
                    -- Construct a variable that will be returned on a successful match
                    local items = type(completion_data.complete) == "table" and completion_data.complete
                        or completion_data.complete(context, prev, saved, match)
                    local ret_completions = { items = items, options = completion_data.options or {} }

                    -- Set the match variable for the integration module
                    ret_completions.match = match

                    -- If the completion data has a node variable then attempt to match the current node too!
                    if completion_data.node then
                        -- If the type of completion data we're dealing with is a string then attempt to parse it
                        if type(completion_data.node) == "string" then
                            -- Split the completion node string down every pipe character
                            local split = vim.split(completion_data.node --[[@as string]], "|")
                            -- Check whether the first character of the string is an exclamation mark
                            -- If this is present then it means we're looking for a node that *isn't* the one we specify
                            local negate = split[1]:sub(0, 1) == "!"

                            -- If we are negating then remove the leading exclamation mark so it doesn't interfere
                            if negate then
                                split[1] = split[1]:sub(2)
                            end

                            -- If we have a second split (i.e. in the string "tag_name|prev" this would be the "prev" string)
                            if split[2] then
                                -- Is our other value "prev"? If so, compare the current node in the syntax tree with the previous node
                                if split[2] == "prev" then
                                    -- Get the previous node
                                    local current_node = vim.treesitter.get_node()

                                    if not current_node then
                                        return { items = {}, options = {} }
                                    end

                                    local previous_node = ts.get_previous_node(current_node, true, true)

                                    -- If the previous node is nil
                                    if not previous_node then
                                        -- If we have specified a negation then that means our tag type doesn't match the previous tag's type,
                                        -- which is good! That means we can return our completions
                                        if negate then
                                            return ret_completions
                                        end

                                        -- Otherwise continue on with the loop
                                        goto continue
                                    end

                                    -- If we haven't negated and the previous node type is equal to the one we specified then return completions
                                    if not negate and previous_node:type() == split[1] then
                                        return ret_completions
                                        -- Otherwise, if we want to negate and if the current node type is not equal to the one we specified
                                        -- then also return completions - it means the match was successful
                                    elseif negate and previous_node:type() ~= split[1] then
                                        return ret_completions
                                    else -- Otherwise just continue with the loop
                                        goto continue
                                    end
                                    -- Else if our second split is equal to "next" then it's time to inspect the next node in the AST
                                elseif split[2] == "next" then
                                    -- Grab the next node
                                    local current_node = vim.treesitter.get_node()

                                    if not current_node then
                                        return { items = {}, options = {} }
                                    end

                                    local next_node = ts.get_next_node(current_node, true, true)

                                    -- If it's nil
                                    if not next_node then
                                        -- If we want to negate then return completions - the comparison was unsuccessful, which is what we wanted
                                        if negate then
                                            return ret_completions
                                        end

                                        -- Or just continue
                                        goto continue
                                    end

                                    -- If we are not negating and the node values match then return completions
                                    if not negate and next_node:type() == split[1] then
                                        return ret_completions
                                        -- If we are negating and then values don't match then also return completions
                                    elseif negate and next_node:type() ~= split[1] then
                                        return ret_completions
                                    else
                                        -- Else keep look through the completion table to see whether we can find another match
                                        goto continue
                                    end
                                end
                            else -- If we haven't defined a split (no pipe was found) then compare the current node
                                if vim.treesitter.get_node():type() == split[1] then
                                    -- If we're not negating then return completions
                                    if not negate then
                                        return ret_completions
                                    else -- Else continue
                                        goto continue
                                    end
                                end
                            end
                            -- If our completion data type is not a string but rather it is a function then
                        elseif type(completion_data.node) == "function" then
                            -- Grab all the necessary variables (current node, previous node, next node)
                            local current_node = vim.treesitter.get_node()

                            -- The file is blank, return completions
                            if not current_node then
                                return ret_completions
                            end

                            local next_node = ts.get_next_node(current_node, true, true)
                            local previous_node = ts.get_previous_node(current_node, true, true)

                            -- Execute the callback function with all of our parameters.
                            -- If it returns true then that means the match was successful, and so return completions
                            if completion_data.node(current_node, previous_node, next_node, ts) then
                                return ret_completions
                            end

                            -- If no completions were found, try looking whether we can descend any further down the syntax tree.
                            -- Maybe we can find something extra there?
                            if completion_data.descend then
                                -- Recursively call complete() with the nested table
                                local descent = module.public.complete(
                                    context,
                                    completion_data.descend,
                                    saved .. completion_data.regex
                                )

                                -- If the returned completion items actually hold some data (i.e. a match was found) then return those matches
                                if not vim.tbl_isempty(descent.items) then
                                    return descent
                                end
                            end

                            -- Else just don't bother and continue
                            goto continue
                        end
                    end

                    -- If none of the checks matched, then we can conclude that only the regex variable was defined,
                    -- and since that was matched properly, we can return all completions.
                    return ret_completions
                    -- If the regex for the current line wasn't matched then attempt to descend further down,
                    -- similarly to what we did earlier
                elseif completion_data.descend then
                    -- Recursively call function with new parameters
                    local descent =
                        module.public.complete(context, completion_data.descend, saved .. completion_data.regex)

                    -- If we had some completions from that function then return those completions
                    if not vim.tbl_isempty(descent.items) then
                        return descent
                    end
                end
            end
            ::continue::
        end

        -- If absolutely no matches were found return empty data (no completions)
        return { items = {}, options = {} }
    end,
}

return module
