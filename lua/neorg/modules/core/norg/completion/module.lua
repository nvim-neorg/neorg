--[[
    File: Completion
    Title: Get completions in Neorg files
    Summary: A wrapper to interface with several different completion engines.
    ---

This module is an intermediary between Neorg and the completion engine of your
choice. After setting up this module, please read the corresponding neorg wiki
page for the engine you selected ([`nvim-cmp`](@core.integrations.nvim-cmp) or
[`nvim-compe`](@core.integrations.nvim-compe)) to complete setup.
--]]

require("neorg.modules.base")
require("neorg.modules")

local module = neorg.modules.create("core.norg.completion")

module.config.public = {
    -- The engine to use for completion.
    --
    -- Possible values:
    -- - [`nvim-cmp`](@core.integrations.nvim-cmp)
    -- - [`nvim-compe`](@core.integrations.nvim-compe)
    engine = nil,
    name = "[Neorg]",
}

module.setup = function()
    return { success = true, requires = { "core.integrations.treesitter" } }
end

module.private = {
    engine = nil,
}

module.load = function()
    -- If we have not defined an engine then bail
    if not module.config.public.engine then
        log.error("No engine specified, aborting...")
        return
    end

    -- If our engine is compe then attempt to load the integration module for nvim-compe
    if module.config.public.engine == "nvim-compe" and neorg.modules.load_module("core.integrations.nvim-compe") then
        module.private.engine = neorg.modules.get_module("core.integrations.nvim-compe")
    elseif module.config.public.engine == "nvim-cmp" and neorg.modules.load_module("core.integrations.nvim-cmp") then
        module.private.engine = neorg.modules.get_module("core.integrations.nvim-cmp")
    else
        log.error("Unable to load completion module -", module.config.public.engine, "is not a recognized engine.")
        return
    end

    -- Set a special function in the integration module to allow it to communicate with us
    module.private.engine.invoke_completion_engine = function(context)
        return module.public.complete(context)
    end

    -- Create the integration engine's source
    module.private.engine.create_source({
        completions = module.config.public.completions,
    })
end

---@class core.norg.completion
module.public = {

    -- Define completions
    completions = {
        { -- Create a new completion
            -- Define the regex that should match in order to proceed
            regex = "^%s*@(%w*)",

            -- If regex can be matched, this item then gets verified via TreeSitter's AST
            node = function(current, previous)
                -- If no previous node exists then try verifying the current node instead
                if not previous then
                    return current and (current:type() ~= "translation_unit" or current:type() == "document") or false
                end

                -- If the previous node is not tag parameters or the tag name
                -- (i.e. we are not inside of a tag) then show autocompletions
                return previous:type() ~= "tag_parameters" and previous:type() ~= "tag_name"
            end,

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

                    complete = require("neorg.external.helpers").get_language_list(true),

                    -- Extra options
                    options = {
                        type = "Language",
                    },

                    -- Don't descend any further, we've narrowed down our match
                    descend = {},
                },
                {
                    regex = "export%s+%w*",

                    complete = require("neorg.external.helpers").get_language_list(true),

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
        {
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
        {
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
        {
            regex = "^%s*%-+%s+%[([x%*%s]?)",

            complete = {
                { "[ ] ", label = "[ ] (undone)" },
                { "[-] ", label = "[-] (pending)" },
                { "[x] ", label = "[x] (done)" },
                { "[_] ", label = "[_] (cancelled)" },
                { "[!] ", label = "[!] (important)" },
                { "[+] ", label = "[+] (recurring)" },
                { "[=] ", label = "[=] (on hold)" },
                { "[?] ", label = "[?] (uncertain)" },
            },

            options = {
                type = "TODO",
                pre = function()
                    local sub = vim.api.nvim_get_current_line():gsub("^(%s*%-+%s+%[%s*)%]", "%1")

                    if sub then
                        vim.api.nvim_set_current_line(sub)
                    end
                end,

                completion_start = "-",
            },
        },
    },

    --- Parses the public completion table and attempts to find all valid matches
    ---@param context table #The context provided by the integration engine
    ---@param prev table #The previous table of completions - used for descent
    ---@param saved string #The saved regex in the form of a string, used to concatenate children nodes with parent nodes' regexes
    complete = function(context, prev, saved)
        -- If the save variable wasn't passed then set it to an empty string
        saved = saved or ""

        -- If we haven't defined any explicit table to read then read the public completions table
        local completions = prev or module.public.completions

        -- Loop through every completion
        for _, completion_data in ipairs(completions) do
            -- If the completion data has a regex variable
            if completion_data.regex then
                -- Attempt to match the current line before the cursor with that regex
                local match = context.line:match(saved .. completion_data.regex .. "$")

                -- If our match was successful
                if match then
                    -- Construct a variable that will be returned on a successful match
                    local items = type(completion_data.complete) == "table" and completion_data.complete
                        or completion_data.complete(context, prev, saved)
                    local ret_completions = { items = items, options = completion_data.options or {} }

                    -- Set the match variable for the integration module
                    ret_completions.match = match

                    -- If the completion data has a node variable then attempt to match the current node too!
                    if completion_data.node then
                        -- Grab the treesitter utilities
                        local ts = module.required["core.integrations.treesitter"].get_ts_utils()

                        -- If the type of completion data we're dealing with is a string then attempt to parse it
                        if type(completion_data.node) == "string" then
                            -- Split the completion node string down every pipe character
                            local split = vim.split(completion_data.node, "|")
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
                                    local current_node = ts.get_node_at_cursor()

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
                                    local current_node = ts.get_node_at_cursor()

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
                                if ts.get_node_at_cursor():type() == split[1] then
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
                            local current_node = ts.get_node_at_cursor()

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
