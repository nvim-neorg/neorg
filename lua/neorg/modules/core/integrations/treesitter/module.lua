--[[
	A module designed to integrate TreeSitter into Neorg.

	If it seems that I don't know what I'm doing at times it's because I have no clue what I'm doing.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.integrations.treesitter")

module.setup = function()
    return { success = true, requires = { "core.highlights", "core.mode", "core.keybinds" } }
end

module.config.public = {
    highlights = {
        tag = {
            -- The + tells neorg to link to an existing hl
            begin = "+TSKeyword",

            -- Supply any arguments you would to :highlight here
            -- Example: ["end"] = "guifg=#93042b",
            ["end"] = "+TSKeyword",

            name = {
                [""] = "+Normal",
                word = "+TSKeyword",
            },

            parameter = "+TSType",
            content = "+Normal",
        },

        carryovertag = {
            begin = "+TSLabel",

            name = {
                [""] = "+Normal",
                word = "+TSLabel",
            },

            parameter = "+TSString",
        },

        heading = {
            ["1"] = {
                title = "+TSAttribute",
                prefix = "+TSAttribute",
            },
            ["2"] = {
                title = "+TSLabel",
                prefix = "+TSLabel",
            },
            ["3"] = {
                title = "+TSMath",
                prefix = "+TSMath",
            },
            ["4"] = {
                title = "+TSString",
                prefix = "+TSString",
            },
            ["5"] = {
                title = "+TSLabel",
                prefix = "+TSLabel",
            },
            ["6"] = {
                title = "+TSMath",
                prefix = "+TSMath",
            },
        },

        error = "+TSError",

        marker = {
            [""] = "+TSLabel",
            title = "+Normal",
        },

        drawer = {
            [""] = "+TSPunctDelimiter",
            ["end"] = "+TSPunctDelimiter",

            title = "+TSMath",
            content = "+Normal",
        },

        escapesequence = "+TSType",

        todoitem = {
            ["1"] = {
                [""] = "+NeorgUnorderedList1",

                bracket = "+TSString",

                pending = "+TSNamespace",
                done = "+TSMethod",
            },
            ["2"] = {
                [""] = "+NeorgUnorderedList2",

                bracket = "+TSString",

                pending = "+TSNamespace",
                done = "+TSMethod",
            },
            ["3"] = {
                [""] = "+NeorgUnorderedList3",

                bracket = "+TSString",

                pending = "+TSNamespace",
                done = "+TSMethod",
            },
            ["4"] = {
                [""] = "+NeorgUnorderedList4",

                bracket = "+TSString",

                pending = "+TSNamespace",
                done = "+TSMethod",
            },
            ["5"] = {
                [""] = "+NeorgUnorderedList5",

                bracket = "+TSString",

                pending = "+TSNamespace",
                done = "+TSMethod",
            },
            ["6"] = {
                [""] = "+NeorgUnorderedList6",

                bracket = "+TSString",

                pending = "+TSNamespace",
                done = "+TSMethod",
            },
        },

        unordered = {
            list = {
                ["1"] = {
                    [""] = "+TSPunctDelimiter",
                },
                ["2"] = {
                    [""] = "+TSPunctDelimiter",
                },
                ["3"] = {
                    [""] = "+TSPunctDelimiter",
                },
                ["4"] = {
                    [""] = "+TSPunctDelimiter",
                },
                ["5"] = {
                    [""] = "+TSPunctDelimiter",
                },
                ["6"] = {
                    [""] = "+TSPunctDelimiter",
                },
            },

            link = {
                ["1"] = {
                    [""] = "+NeorgUnorderedList1",
                },
                ["2"] = {
                    [""] = "+NeorgUnorderedList2",
                },
                ["3"] = {
                    [""] = "+NeorgUnorderedList3",
                },
                ["4"] = {
                    [""] = "+NeorgUnorderedList4",
                },
                ["5"] = {
                    [""] = "+NeorgUnorderedList5",
                },
                ["6"] = {
                    [""] = "+NeorgUnorderedList6",
                },
            },
        },

        quote = {
            ["1"] = {
                [""] = "+TSPunctDelimiter",
                content = "+TSPunctDelimiter",
            },
            ["2"] = {
                [""] = "+TSPunctDelimiter",
                content = "+TSPunctDelimiter",
            },
            ["3"] = {
                [""] = "+TSPunctDelimiter",
                content = "+TSPunctDelimiter",
            },
            ["4"] = {
                [""] = "+TSPunctDelimiter",
                content = "+TSPunctDelimiter",
            },
            ["5"] = {
                [""] = "+TSPunctDelimiter",
                content = "+TSPunctDelimiter",
            },
            ["6"] = {
                [""] = "+TSPunctDelimiter",
                content = "+TSPunctDelimiter",
            },
        },

        insertion = {
            [""] = "cterm=bold gui=bold",
            prefix = "+TSPunctDelimiter",
            item = "+TSNamespace",
            parameters = "+TSPunctDelimiter",
        },

        strongparagraphdelimiter = "+TSPunctDelimiter",
        weakparagraphdelimiter = "+TSPunctDelimiter",
    },

    dim = {
        codeblock = {
            reference = "Normal",
            percentage = 15,
            affect = "background",
        },
    },

    generate_shorthands = true,
}

module.load = function()
    module.required["core.mode"].add_mode("traverse-heading")
    module.required["core.keybinds"].register_keybinds(module.name, { "next.heading", "previous.heading" })

    module.required["core.highlights"].add_highlights(module.config.public.highlights)
    module.required["core.highlights"].add_dim(module.config.public.dim)

    --[[
		The below code snippet collects all language shorthands and links them to
		their parent language, e.g.:
		"hs" links to the "haskell" TreeSitter parser
		"c++" links to the "cpp" TreeSitter parser

		And so on.
		Injections are generated dynamically
	--]]

    if module.config.public.generate_shorthands then
        local injections = {}

        local langs = require("neorg.external.helpers").get_language_shorthands(false)

        for language, shorthands in pairs(langs) do
            for _, shorthand in ipairs(shorthands) do
                table.insert(
                    injections,
                    (
                        [[(ranged_tag (tag_name) @_tagname (tag_parameters (word) @%s) (ranged_tag_content) @content (#eq? @_tagname "code") (#eq? @%s "%s"))]]
                    ):format(language, language, shorthand)
                )
            end
        end

        table.insert(
            injections,
            [[(ranged_tag (tag_name) @_tagname (tag_parameters (word) @language) (ranged_tag_content) @content (#eq? @_tagname "code") (#not-eq? @language "norg"))]]
        )

        vim.treesitter.set_query("norg", "injections", table.concat(injections, "\n"))
    end
end

module.public = {
    goto_next_heading = function()
        -- Currently we have this crappy solution because I don't know enough treesitter
        -- If you do know how to hop between TS nodes then please make a PR <3 (or at least tell me)

        local line_number = vim.api.nvim_win_get_cursor(0)[1]

        local lines = vim.api.nvim_buf_get_lines(0, line_number, -1, true)

        for relative_line_number, line in ipairs(lines) do
            local match = line:match("^%s*%*+%s+")

            if match then
                vim.api.nvim_win_set_cursor(0, { line_number + relative_line_number, match:len() })
                break
            end
        end
    end,

    goto_previous_heading = function()
        -- Similar to the previous function I have no clue how to do this in TS lmao
        local line_number = vim.api.nvim_win_get_cursor(0)[1]

        local lines = vim.fn.reverse(vim.api.nvim_buf_get_lines(0, 0, line_number - 1, true))

        for relative_line_number, line in ipairs(lines) do
            local match = line:match("^%s*%*+%s+")

            if match then
                vim.api.nvim_win_set_cursor(0, { line_number - relative_line_number, match:len() })
                break
            end
        end
    end,

    -- @Summary Gets all nodes of a given type from the AST
    -- @Description Retrieves all nodes in the form of a list
    -- @Param  type (string) - the type of node to filter out
    get_all_nodes = function(type)
        local result = {}

        -- Do we need to go through each tree? lol
        vim.treesitter.get_parser(0, "norg"):for_each_tree(function(tree)
            -- Get the root for that tree
            local root = tree:root()

            -- @Summary Function to recursively descend down the syntax tree
            -- @Description Recursively searches for a node of a given type
            -- @Param  node (userdata/treesitter node) - the starting point for the search
            local function descend(node)
                -- Iterate over all children of the node and try to match their type
                for child, _ in node:iter_children() do
                    if child:type() == type then
                        table.insert(result, child)
                    else
                        -- If no match is found try descending further down the syntax tree
                        for _, child_node in ipairs(descend(child) or {}) do
                            table.insert(result, child_node)
                        end
                    end
                end
            end

            descend(root)
        end)

        return result
    end,

    -- @Summary Returns the first occurence of a node in the AST
    -- @Description Returns the first node of given type if present
    -- @Param  type (string) - the type of node to search for
    get_first_node = function(type)
        local ret = nil

        -- I'm starting to doubt that we need to loop through each tree
        -- Core Devs plz help
        vim.treesitter.get_parser(0, "norg"):for_each_tree(function(tree)
            -- Iterate over all top-level children and attempt to find a match
            for child, _ in tree:root():iter_children() do
                if child:type() == type then
                    ret = child
                    return
                end
            end
        end)

        return ret
    end,

    get_first_node_recursive = function(type)
        local result

        -- Do we need to go through each tree? lol
        vim.treesitter.get_parser(0, "norg"):for_each_tree(function(tree)
            -- Get the root for that tree
            local root = tree:root()

            -- @Summary Function to recursively descend down the syntax tree
            -- @Description Recursively searches for a node of a given type
            -- @Param  node (userdata/treesitter node) - the starting point for the search
            local function descend(node)
                -- Iterate over all children of the node and try to match their type
                for child, _ in node:iter_children() do
                    if child:type() == type then
                        return child
                    else
                        -- If no match is found try descending further down the syntax tree
                        local descent = descend(child)
                        if descent then
                            return descent
                        end
                    end
                end

                return nil
            end

            result = result or descend(root)
        end)

        return result
    end,

    -- @Summary Returns metadata for a tag
    -- @Description Given a node this function will break down the AST elements and return the corresponding text for certain nodes
    -- @Param  tag_node (userdata/treesitter node) - a node of type tag/carryover_tag
    get_tag_info = function(tag_node, check_parent)
        if not tag_node or (tag_node:type() ~= "tag" and tag_node:type() ~= "carryover_tag") then
            return nil
        end

        -- Grab the TreeSitter utils
        local ts_utils = require("nvim-treesitter.ts_utils")

        local attributes = {}
        local leading_whitespace, resulting_name, params, content = 0, {}, {}, {}

        if check_parent == true or check_parent == nil then
            local parent = tag_node:parent()

            while parent:type() == "carryover_tag" do
                local meta = module.public.get_tag_info(parent, false)

                if
                    vim.tbl_isempty(vim.tbl_filter(function(attribute)
                        return attribute.name == meta.name
                    end, attributes))
                then
                    table.insert(attributes, meta)
                else
                    log.warn("Two carryover tags with the same name detected, the top level tag will take precedence")
                end
                parent = parent:parent()
            end
        end

        -- Iterate over all children of the tag node
        for child, _ in tag_node:iter_children() do
            -- If we're dealing with the tag name then append the text of the tag_name node to this table
            if child:type() == "tag_name" then
                table.insert(resulting_name, ts_utils.get_node_text(child)[1])
            elseif child:type() == "tag_parameters" then
                table.insert(params, ts_utils.get_node_text(child)[1])
            elseif child:type() == "leading_whitespace" then
                leading_whitespace = ts_utils.get_node_text(child)[1]:len()
            elseif child:type() == "tag_content" then
                -- If we're dealing with tag content then retrieve that content
                content = ts_utils.get_node_text(child)
            end
        end

        content = table.concat(content, "\n")

        local start_row, start_column, end_row, end_column = tag_node:range()

        return {
            name = table.concat(resulting_name, "."),
            parameters = params,
            content = content:sub(2, content:len() - 1),
            indent_amount = leading_whitespace,
            attributes = vim.fn.reverse(attributes),
            start = { row = start_row, column = start_column },
            ["end"] = { row = end_row, column = end_column },
        }
    end,

    -- @Summary Parses data from an @ tag
    -- @Description Used to extract data from e.g. document.meta
    -- @Param  tag_content (string) - the content of the tag (without the beginning and end declarations)
    parse_tag = function(tag_content)
        local result = {}

        tag_content = tag_content:gsub("([^%s])~\n%s*", "%1 ")

        for name, content in tag_content:gmatch("%s*(%w+):%s+([^\n]*)") do
            result[name] = content
        end

        return result
    end,

    -- @Summary Invokes a callback for every element of the current tree
    -- @Param  callback (function(node)) - the callback to invoke
    -- TODO: docs
    tree_map = function(callback, ts_tree)
        local tree = ts_tree or vim.treesitter.get_parser(0, "norg"):parse()[1]

        local root = tree:root()

        for child, _ in root:iter_children() do
            callback(child)
        end
    end,

    tree_map_rec = function(callback, ts_tree)
        local tree = ts_tree or vim.treesitter.get_parser(0, "norg"):parse()[1]

        local root = tree:root()

        local descend

        descend = function(start)
            for child, _ in start:iter_children() do
                callback(child)
                descend(child)
            end
        end

        descend(root)
    end,

    get_link_info = function()
        local ts = require("nvim-treesitter.ts_utils")
        local node = ts.get_node_at_cursor(0)

        if not node then
            return nil
        end

        local parent = node:parent()

        if not parent then
            return nil
        end

        if parent:type() == "link" and parent:named_child_count() > 1 then
            return {
                text = ts.get_node_text(parent:named_child(0))[1],
                location = ts.get_node_text(parent:named_child(1))[1],
                type = parent:named_child(1):type(),
                range = module.public.get_node_range(parent),
            }
        end
    end,

    -- Gets the range of a given node
    get_node_range = function(node)
        local rs, cs, re, ce = node:range()
        return {
            row_start = rs,
            column_start = cs,
            row_end = re,
            column_end = ce,
        }
    end,
}

module.on_event = function(event)
    if event.split_type[1] == "core.keybinds" then
        if event.split_type[2] == "core.integrations.treesitter.next.heading" then
            module.public.goto_next_heading()
        elseif event.split_type[2] == "core.integrations.treesitter.previous.heading" then
            module.public.goto_previous_heading()
        end
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.integrations.treesitter.next.heading"] = true,
        ["core.integrations.treesitter.previous.heading"] = true,
    },
}

return module
