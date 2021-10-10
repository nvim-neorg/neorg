--[[
    CONCEALER MODULE FOR NEORG.
    This module is supposed to enhance the neorg editing experience
    by abstracting away certain bits of text and concealing it into one easy-to-recognize
    icon. Icons can be easily changed and every element can be disabled.

USAGE: (TODO: update)
    This module does not come bundled by default with the core.defaults metamodule.
    Make sure to manually enable it in neorg's setup function.

    The module comes with several config options, and they are listed here:
    icons = {
        todo = {
            enabled = true, -- Conceal TODO items

            done = {
                enabled = true, -- Conceal whenever an item is marked as done
                icon = ""
            },
            pending = {
                enabled = true, -- Conceal whenever an item is marked as pending
                icon = ""
            },
            undone = {
                enabled = true, -- Conceal whenever an item is marked as undone
                icon = "×"
            }
        },
        quote = {
            enabled = true, -- Conceal quotes
            icon = "│"
        },
        heading = {
            enabled = true, -- Enable beautified headings

            -- Define icons for all the different heading levels
            level_1 = {
                enabled = true,
                icon = "◉",
            },

            level_2 = {
                enabled = true,
                icon = "○",
            },

            level_3 = {
                enabled = true,
                icon = "✿",
            },

            level_4 = {
                enabled = true,
                icon = "•",
            },
        },

        marker = {
            enabled = true, -- Enable the beautification of markers
            icon = "",
        },
    }

    You can also add your own custom conceals with their own custom icons, however this is a tad more complex.

    Note that those are probably the configuration options that you are *going* to use.
    There are a lot more configuration options per element than that, however.

    Here are the more advanced parameters you may be interested in:

    pattern - the pattern to match. If this pattern isn't matched then the conceal isn't applied.

    whitespace_index - this one is a bit funny to explain. Basically, this is the index of a capture from
    the "pattern" variable representing the leading whitespace. This whitespace is then used to calculate
    where to place the icon. If your pattern specifies only one capture, set this to 1

    highlight - the highlight to apply to the icon

    padding_before - the amount of padding (in the form of spaces) to apply before the icon

NOTE: When defining your own icons be sure to set *all* the above variables plus the "icon" and "enabled" variables.
      If you don't you will get errors.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.concealer")

module.setup = function()
    return { success = true, requires = { "core.autocommands", "core.integrations.treesitter" } }
end

module.private = {
    namespace = vim.api.nvim_create_namespace("neorg_conceals"),
    extmarks = {},
    icons = {},
}

module.public = {

    -- @Summary Activates icons for the current window
    -- @Description Parses the user configuration and enables concealing for the current window.
    -- @Param from (number) - the line number that we should start at (defaults to 0)
    trigger_icons = function(from)
        -- Clear all the conceals beforehand (so no overlaps occur)
        module.public.clear_icons(from)

        -- The next block of code will be responsible for dimming code blocks accordingly
        local tree = vim.treesitter.get_parser(0, "norg"):parse()[1]

        -- If the tree is valid then attempt to perform the query
        if tree then
            do
                -- Query all code blocks
                local ok, query = pcall(
                    vim.treesitter.parse_query,
                    "norg",
                    [[(
                        (ranged_tag (tag_name) @_name) @tag
                        (#eq? @_name "code")
                    )]]
                )

                -- If something went wrong then go bye bye
                if not ok or not query then
                    return
                end

                -- Go through every found capture
                for id, node in query:iter_captures(tree:root(), 0, from or 0, -1) do
                    local id_name = query.captures[id]

                    -- If the capture name is "tag" then that means we're dealing with our ranged_tag;
                    if id_name == "tag" then
                        -- Get the range of the code block
                        local range = module.required["core.integrations.treesitter"].get_node_range(node)

                        -- Go through every line in the code block and give it a magical highlight
                        for i = range.row_start, range.row_end >= vim.api.nvim_buf_line_count(0) and 0 or range.row_end, 1 do
                            local line = vim.api.nvim_buf_get_lines(0, i, i + 1, true)[1]

                            -- If our buffer is modifiable or if our line is too short then try to fill in the line
                            -- (this fixes broken syntax highlights automatically)
                            if vim.bo.modifiable and line:len() < range.column_start then
                                vim.api.nvim_buf_set_lines(0, i, i + 1, true, { string.rep(" ", range.column_start) })
                            end

                            -- If our line is valid and it's not too short then apply the dimmed highlight
                            if line and line:len() >= range.column_start then
                                module.public._set_extmark(
                                    nil,
                                    "NeorgCodeBlock",
                                    i,
                                    i + 1,
                                    range.column_start,
                                    nil,
                                    true,
                                    "blend"
                                )
                            end
                        end
                    end
                end
            end
        end

        -- Get the root node of the document (required to iterate over query captures)
        local document_root = module.required["core.integrations.treesitter"].get_document_root()

        -- Loop through all icons that the user has enabled
        for _, icon_data in ipairs(module.private.icons) do
            if icon_data.query then
                -- Attempt to parse the query provided by `icon_data.query`
                -- A query must have at least one capture, e.g. "(test_node) @icon"
                local query = vim.treesitter.parse_query("norg", icon_data.query)

                -- Go through every found node and try to apply an icon to it
                for id, node in query:iter_captures(document_root, 0) do
                    local capture = query.captures[id]

                    if capture == "icon" then
                        -- Extract both the text and the range of the node
                        local text = module.required["core.integrations.treesitter"].get_node_text(node)
                        local range = module.required["core.integrations.treesitter"].get_node_range(node)

                        -- Set the offset to 0 here. The offset is a special value that, well, offsets
                        -- the location of the icon column-wise
                        -- It's used in scenarios where the node spans more than what we want to iconify.
                        -- A prime example of this is the todo item, whose content looks like this: "[x]".
                        -- We obviously don't want to iconify the entire thing, this is why we will tell Neorg
                        -- to use an offset of 1 to start the icon at the "x"
                        local offset = 0

                        -- The extract function is used exactly to calculate this offset
                        -- If that function is present then run it and grab the return value
                        if icon_data.extract then
                            offset = icon_data.extract(text) or 0
                        end

                        -- Every icon can also implement a custom "render" function that can allow for things like multicoloured icons
                        -- This is primarily used in nested quotes
                        -- The "render" function must return a table of this structure: { { "text", "highlightgroup1" }, { "optionally more text", "higlightgroup2" } }
                        if not icon_data.render then
                            module.public._set_extmark(
                                icon_data.icon,
                                icon_data.highlight,
                                range.row_start,
                                range.row_end,
                                range.column_start + offset,
                                range.column_end,
                                false,
                                "combine"
                            )
                        else
                            module.public._set_extmark(
                                icon_data:render(text, node),
                                icon_data.highlight,
                                range.row_start,
                                range.row_end,
                                range.column_start + offset,
                                range.column_end,
                                false,
                                "combine"
                            )
                        end
                    end
                end
            end
        end
    end,

    -- @Summary Sets an extmark in the buffer
    -- @Description Mostly a wrapper around vim.api.nvim_buf_set_extmark in order to make it more safe
    -- @Param  text (string|table) - the virtual text to overlay (usually the icon)
    -- @Param  highlight (string) - the name of a highlight to use for the icon
    -- @Param  line_number (number) - the line number to apply the extmark in
    -- @Param  end_line (number) - the last line number to apply the extmark to (useful if you want an extmark to exist for more than one line)
    -- @Param  start_column (number) - the start column of the conceal
    -- @Param  end_column (number) - the end column of the conceal
    -- @Param  whole_line (boolean) - if true will highlight the whole line (like in diffs)
    -- @Param  mode (string: "replace"/"combine"/"blend") - the highlight mode for the extmark
    _set_extmark = function(text, highlight, line_number, end_line, start_column, end_column, whole_line, mode)
        -- If the text type is a string then convert it into something that Neovim's extmark API can understand
        if type(text) == "string" then
            text = { { text, highlight } }
        end

        -- Attempt to call vim.api.nvim_buf_set_extmark with all the parameters
        local ok, result = pcall(vim.api.nvim_buf_set_extmark, 0, module.private.namespace, line_number, start_column, {
            end_col = end_column,
            hl_group = highlight,
            end_line = end_line,
            virt_text = text or nil,
            virt_text_pos = "overlay",
            hl_mode = mode,
            hl_eol = whole_line,
        })

        -- If we have encountered an error then log it
        if not ok then
            log.error("Unable to create custom conceal for highlight:", highlight, "-", result)
        end
    end,

    -- @Summary Clears all the conceals that neorg has defined
    -- @Description Simply clears the Neorg extmark namespace
    -- @Param from (number) - the line number to start clearing from
    clear_icons = function(from)
        vim.api.nvim_buf_clear_namespace(0, module.private.namespace, from or 0, -1)
    end,

    -- @Summary Triggers conceals for the current buffer
    -- @Description Reads through the user configuration and enables concealing for the current buffer
    trigger_conceals = function()
        local conceals = module.config.public.conceals

        if conceals.url then
            vim.schedule(function()
                vim.cmd(
                    'syn region NeorgConcealURLValue matchgroup=mkdDelimiter start="(" end=")" contained oneline conceal'
                )
                vim.cmd(
                    'syn region NeorgConcealURL matchgroup=mkdDelimiter start="\\([^\\\\]\\|\\_^\\)\\@<=\\[\\%\\(\\%\\(\\\\\\=[^\\]]\\)\\+\\](\\)\\@=" end="[^\\\\]\\@<=\\]" nextgroup=NeorgConcealURLValue oneline skipwhite concealends'
                )
            end)
        end

        if conceals.bold then
            vim.schedule(function()
                vim.cmd([[
                syn region NeorgConcealBold matchgroup=Normal start="\([?!:;,.<>()\[\]{}'"/#%&$£€\-_\~`\W \t\n]\&[^\\]\|^\)\@<=\*\%\([^ \t\n\*]\)\@=" end="[^ \t\n\\]\@<=\*\%\([?!:;,.<>()\[\]{}\*'"/#%&$£\-_\~`\W \t\n]\)\@=" oneline concealends
                ]])
            end)
        end

        if conceals.italic then
            vim.schedule(function()
                vim.cmd([[
                syn region NeorgConcealItalic matchgroup=Normal start="\([?!:;,.<>()\[\]{}\*'"#%&$£€\-_\~`\W \t\n]\&[^\\]\|^\)\@<=/\%\([^ \t\n/]\)\@=" end="[^ \t\n\\]\@<=/\%\([?!:;,.<>()\[\]{}\*'"/#%&$£\-_\~`\W \t\n]\)\@=" oneline concealends
                ]])
            end)
        end

        if conceals.underline then
            vim.schedule(function()
                vim.cmd([[
                syn region NeorgConcealUnderline matchgroup=Normal start="\([?!:;,.<>()\[\]{}\*'"/#%&$£€\-\~`\W \t\n]\&[^\\]\|^\)\@<=_\%\([^ \t\n_]\)\@=" end="[^ \t\n\\]\@<=_\%\([?!:;,.<>()\[\]{}\*'"/#%&$£\-_\~`\W \t\n]\)\@=" oneline concealends
                ]])
            end)
        end

        if conceals.strikethrough then
            vim.schedule(function()
                vim.cmd([[
                syn region NeorgConcealStrikethrough matchgroup=Normal start="\([?!:;,.<>()\[\]{}\*'"/#%&$£€\-_\~`\W \t\n]\&[^\\]\|^\)\@<=\-\%\([^ \t\n\-]\)\@=" end="[^ \t\n\\]\@<=\-\%\([?!:;,.<>()\[\]{}\*'"/#%&$£\-_\~`\W \t\n]\)\@=" oneline concealends
                ]])
            end)
        end

        if conceals.verbatim then
            vim.schedule(function()
                vim.cmd([[
                syn region NeorgConcealMonospace matchgroup=Normal start="\([?!:;,.<>()\[\]{}\*'"/#%&$£€\-_\~\W \t\n]\&[^\\]\|^\)\@<=`\%\([^ \t\n`]\)\@=" end="[^ \t\n\\]\@<=`\%\([?!:;,.<>()\[\]{}\*'"/#%&$£\-_\~`\W \t\n]\)\@=" oneline concealends
                ]])
            end)
        end

        if conceals.trailing then
            vim.schedule(function()
                vim.cmd([[
                syn match NeorgConcealTrailing /[^\s]\@=\~$/ conceal
                ]])
            end)
        end

        if conceals.link then
            vim.schedule(function()
                vim.cmd([[
                syn region NeorgConcealLink matchgroup=Normal start=":[\*/_\-`]\@=" end="[\*/_\-`]\@<=:" contains=NeorgConcealBold,NeorgConcealItalic,NeorgConcealUnderline,NeorgConcealStrikethrough,NeorgConcealMonospace oneline concealends
                ]])
            end)
        end
    end,

    -- @Summary Clears conceals for the current buffer
    -- @Description Clears all highlight groups related to the Neorg conceal higlight groups
    clear_conceals = function()
        vim.cmd([[
        silent! syn clear NeorgConcealURL
        silent! syn clear NeorgConcealURLValue
        silent! syn clear NeorgConcealItalic
        silent! syn clear NeorgConcealBold
        silent! syn clear NeorgConcealUnderline
        silent! syn clear NeorgConcealMonospace
        silent! syn clear NeorgConcealStrikethrough
        silent! syn clear NeorgConcealTrailing
        silent! syn clear NeorgConcealLink
        ]])
    end,

    concealing = {
        ordered = {
            get_index = function(node, level)
                local sibling = node:parent():prev_named_sibling()
                local count = 1
                while sibling and sibling:type() == level do
                    sibling = sibling:prev_named_sibling()
                    count = count + 1
                end
                return count
            end,

            enumerator = {
                numeric = function(count)
                    return tostring(count)
                end,

                latin_lowercase = function(count)
                    return string.char(96 + count)
                end,

                latin_uppercase = function(count)
                    return string.char(64 + count)
                end,
            },

            punctuation = {
                dot = function(renderer)
                    return function(count)
                        return renderer(count) .. "."
                    end
                end,

                parenthesis = function(renderer)
                    return function(count)
                        return renderer(count) .. ")"
                    end
                end,

                double_parenthesis = function(renderer)
                    return function(count)
                        return "(" .. renderer(count) .. ")"
                    end
                end,
            },
        },
    },
}

module.config.public = {
    icons = {
        todo = {
            enabled = true,

            done = {
                enabled = true,
                icon = "",
                highlight = "NeorgTodoItemDoneMark",
                query = "(todo_item_done) @icon",
                extract = function(content)
                    local column = content:find("x")
                    return column and column - 1
                end,
            },

            pending = {
                enabled = true,
                icon = "",
                highlight = "NeorgTodoItemPendingMark",
                query = "(todo_item_pending) @icon",
                extract = function(content)
                    local column = content:find("*")
                    return column and column - 1
                end,
            },

            undone = {
                enabled = true,
                icon = "×",
                highlight = "NeorgTodoItemUndoneMark",
                query = "(todo_item_undone) @icon",
                extract = function(content)
                    local match = content:match("%s+")
                    return match and math.floor((match:len() + 1) / 2)
                end,
            },
        },

        list = {
            enabled = true,

            level_1 = {
                enabled = true,
                icon = "•",
                highlight = "NeorgUnorderedList1",
                query = "(unordered_list1_prefix) @icon",
            },

            level_2 = {
                enabled = true,
                icon = " •",
                highlight = "NeorgUnorderedList2",
                query = "(unordered_list2_prefix) @icon",
            },

            level_3 = {
                enabled = true,
                icon = "  •",
                highlight = "NeorgUnorderedList3",
                query = "(unordered_list3_prefix) @icon",
            },

            level_4 = {
                enabled = true,
                icon = "   •",
                highlight = "NeorgUnorderedList4",
                query = "(unordered_list4_prefix) @icon",
            },

            level_5 = {
                enabled = true,
                icon = "    •",
                highlight = "NeorgUnorderedList5",
                query = "(unordered_list5_prefix) @icon",
            },

            level_6 = {
                enabled = true,
                icon = "     •",
                highlight = "NeorgUnorderedList6",
                query = "(unordered_list6_prefix) @icon",
            },
        },

        ordered = {
            enabled = true,

            --[[
                Once anticonceal (https://github.com/neovim/neovim/pull/9496) is
                a thing, punctuation can be added (without removing the whitespace
                between the icon and actual text) like so:

                ```lua
                    icon = module.private.ordered_concealing.punctuation.dot(
                        module.private.ordered_concealing.icon_renderer.numeric
                    ),
                ```

                Note: this will produce icons like `1.`, `2.`, etc.

                You can even chain multiple punctuation wrappers like so:

                ```lua
                icon = module.private.ordered_concealing.punctuation.parenthesis(
                    module.private.ordered_concealing.punctuation.dot(
                        module.private.ordered_concealing.icon_renderer.numeric
                    )
                ),
                ```

                Note: this will produce icons like `1.)`, `2.)`, etc.
            --]]

            level_1 = {
                enabled = true,
                icon = module.public.concealing.ordered.enumerator.numeric,
                highlight = "NeorgOrderedList1",
                query = "(ordered_list1_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_list1")
                    return {
                        { self.icon(count), self.highlight },
                    }
                end,
            },

            level_2 = {
                enabled = true,
                icon = module.public.concealing.ordered.enumerator.latin_uppercase,
                highlight = "NeorgOrderedList2",
                query = "(ordered_list2_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_list2")
                    return {
                        { " " .. self.icon(count), self.highlight },
                    }
                end,
            },

            level_3 = {
                enabled = true,
                icon = module.public.concealing.ordered.enumerator.latin_lowercase,
                highlight = "NeorgOrderedList3",
                query = "(ordered_list3_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_list3")
                    return {
                        { "  " .. self.icon(count), self.highlight },
                    }
                end,
            },

            level_4 = {
                enabled = true,
                icon = module.public.concealing.ordered.enumerator.numeric,
                highlight = "NeorgOrderedList4",
                query = "(ordered_list4_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_list4")
                    return {
                        { "   " .. self.icon(count), self.highlight },
                    }
                end,
            },

            level_5 = {
                enabled = true,
                icon = module.public.concealing.ordered.enumerator.latin_uppercase,
                highlight = "NeorgOrderedList5",
                query = "(ordered_list5_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_list5")
                    return {
                        { "    " .. self.icon(count), self.highlight },
                    }
                end,
            },

            level_6 = {
                enabled = true,
                icon = module.public.concealing.ordered.enumerator.latin_lowercase,
                highlight = "NeorgOrderedList6",
                query = "(ordered_list6_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_list6")
                    return {
                        { "     " .. self.icon(count), self.highlight },
                    }
                end,
            },
        },

        quote = {
            enabled = true,

            level_1 = {
                enabled = true,
                icon = "│",
                highlight = "NeorgQuote1",
                query = "(quote1_prefix) @icon",
            },

            level_2 = {
                enabled = true,
                icon = "│",
                highlight = "NeorgQuote2",
                query = "(quote2_prefix) @icon",
                render = function(self)
                    return {
                        { self.icon, module.config.public.icons.quote.level_1.highlight },
                        { self.icon, self.highlight },
                    }
                end,
            },

            level_3 = {
                enabled = true,
                icon = "│",
                highlight = "NeorgQuote3",
                query = "(quote3_prefix) @icon",
                render = function(self)
                    return {
                        { self.icon, module.config.public.icons.quote.level_1.highlight },
                        { self.icon, module.config.public.icons.quote.level_2.highlight },
                        { self.icon, self.highlight },
                    }
                end,
            },

            level_4 = {
                enabled = true,
                icon = "│",
                highlight = "NeorgQuote4",
                query = "(quote4_prefix) @icon",
                render = function(self)
                    return {
                        { self.icon, module.config.public.icons.quote.level_1.highlight },
                        { self.icon, module.config.public.icons.quote.level_2.highlight },
                        { self.icon, module.config.public.icons.quote.level_3.highlight },
                        { self.icon, self.highlight },
                    }
                end,
            },

            level_5 = {
                enabled = true,
                icon = "│",
                highlight = "NeorgQuote5",
                query = "(quote5_prefix) @icon",
                render = function(self)
                    return {
                        { self.icon, module.config.public.icons.quote.level_1.highlight },
                        { self.icon, module.config.public.icons.quote.level_2.highlight },
                        { self.icon, module.config.public.icons.quote.level_3.highlight },
                        { self.icon, module.config.public.icons.quote.level_4.highlight },
                        { self.icon, self.highlight },
                    }
                end,
            },

            level_6 = {
                enabled = true,
                icon = "│",
                highlight = "NeorgQuote6",
                query = "(quote6_prefix) @icon",
                render = function(self)
                    return {
                        { self.icon, module.config.public.icons.quote.level_1.highlight },
                        { self.icon, module.config.public.icons.quote.level_2.highlight },
                        { self.icon, module.config.public.icons.quote.level_3.highlight },
                        { self.icon, module.config.public.icons.quote.level_4.highlight },
                        { self.icon, module.config.public.icons.quote.level_5.highlight },
                        { self.icon, self.highlight },
                    }
                end,
            },
        },

        heading = {
            enabled = true,

            level_1 = {
                enabled = true,
                icon = "◉",
                highlight = "NeorgHeading1",
                query = "(heading1_prefix) @icon",
            },

            level_2 = {
                enabled = true,
                icon = " ○",
                highlight = "NeorgHeading2",
                query = "(heading2_prefix) @icon",
            },

            level_3 = {
                enabled = true,
                icon = "  ✿",
                highlight = "NeorgHeading3",
                query = "(heading3_prefix) @icon",
            },

            level_4 = {
                enabled = true,
                icon = "   ▶",
                highlight = "NeorgHeading4",
                query = "(heading4_prefix) @icon",
            },

            level_5 = {
                enabled = true,
                icon = "    •",
                highlight = "NeorgHeading5",
                query = "(heading5_prefix) @icon",
            },

            level_6 = {
                enabled = true,
                icon = "     ⤷",
                highlight = "NeorgHeading6",
                query = "(heading6_prefix) @icon",
            },
        },

        marker = {
            enabled = true,
            icon = "",
            highlight = "NeorgMarker",
            query = "(marker_prefix) @icon",
        },

        definition = {
            enabled = true,

            single = {
                enabled = true,
                icon = "≡",
                highlight = "NeorgDefinition",
                query = "(single_definition_prefix) @icon",
            },
            multi_prefix = {
                enabled = true,
                icon = "⋙ ",
                highlight = "NeorgDefinition",
                query = "(multi_definition_prefix) @icon",
            },
            multi_suffix = {
                enabled = true,
                icon = "⋘ ",
                highlight = "NeorgDefinition",
                query = "(multi_definition_suffix) @icon",
            },
        },

        delimiter = {
            enabled = true,

            weak = {
                enabled = true,
                icon = "⟨",
                highlight = "NeorgWeakParagraphDelimiter",
                query = "(weak_paragraph_delimiter) @icon",
                render = function(self, text)
                    return {
                        { string.rep(self.icon, text:len()), self.highlight },
                    }
                end,
            },

            strong = {
                enabled = true,
                icon = "⟪",
                highlight = "NeorgStrongParagraphDelimiter",
                query = "(strong_paragraph_delimiter) @icon",
                render = function(self, text)
                    return {
                        { string.rep(self.icon, text:len()), self.highlight },
                    }
                end,
            },

            horizontal_line = {
                enabled = true,
                icon = "─",
                highlight = "NeorgHorizontalLine",
                query = "(horizontal_line) @icon",
                render = function(self)
                    return {
                        { string.rep(self.icon, vim.api.nvim_win_get_width(0)), self.highlight },
                    }
                end,
            },
        },
    },

    conceals = {
        url = true,
        bold = true,
        italic = true,
        underline = true,
        strikethrough = true,
        verbatim = true,
        trailing = true,
        link = true,
    },
}

module.load = function()
    -- @Summary Returns all the enabled icons from a table
    -- @Param  tbl (table) - the table to parse
    -- @Param rec_name (string) - should not be set manually. Is used for Neorg to have information about all other previous recursions
    local function get_enabled_icons(tbl, rec_name)
        rec_name = rec_name or ""

        -- Create a result that we will return at the end of the function
        local result = {}

        -- If the current table isn't enabled then don't parser any further - simply return the empty result
        if vim.tbl_isempty(tbl) or (tbl.enabled ~= nil and tbl.enabled == false) then
            return result
        end

        -- Go through every icon
        for name, icons in pairs(tbl) do
            -- If we're dealing with a table (which we should be) and if the current icon set is enabled then
            if type(icons) == "table" and icons.enabled then
                -- If we have defined an icon value then add that icon to the result
                if icons.icon then
                    result[rec_name .. name] = icons
                else
                    -- If we don't have an icon variable then we need to descend further down the lua table.
                    -- To do this we recursively call this very function and merge the results into the result table
                    result = vim.tbl_deep_extend("force", result, get_enabled_icons(icons, rec_name .. name))
                end
            end
        end

        return result
    end

    -- Set the module.private.icons variable to the values of the enabled icons
    module.private.icons = vim.tbl_values(get_enabled_icons(module.config.public.icons))

    -- Enable the required autocommands (these will be used to determine when to update conceals in the buffer)
    module.required["core.autocommands"].enable_autocommand("BufEnter")

    module.required["core.autocommands"].enable_autocommand("TextChanged")
    module.required["core.autocommands"].enable_autocommand("InsertEnter")
    module.required["core.autocommands"].enable_autocommand("InsertLeave")
end

module.on_event = function(event)
    -- If we have just entered a .norg buffer then apply all conceals
    if event.type == "core.autocommands.events.bufenter" and event.content.norg then
        if module.config.public.conceals then
            module.public.trigger_conceals()
        end

        module.public.trigger_icons()
    elseif event.type == "core.autocommands.events.textchanged" then
        -- If the content of a line has changed in normal mode then reparse the file
        module.public.trigger_icons()
    elseif event.type == "core.autocommands.events.insertenter" then
        vim.api.nvim_buf_clear_namespace(
            0,
            module.private.namespace,
            event.cursor_position[1] - 1,
            event.cursor_position[1]
        )
    elseif event.type == "core.autocommands.events.insertleave" then
        module.public.trigger_icons(event.cursor_position[1])
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
        textchanged = true,
        insertenter = true,
        insertleave = true,
    },
}

return module
