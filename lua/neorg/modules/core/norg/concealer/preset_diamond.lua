local module = neorg.modules.extend("core.norg.concealer.preset_diamond", "core.norg.concealer")

module.config.private.icon_preset_diamond = {
    todo = {
        enabled = true,

        done = {
            enabled = true,
            icon = "",
            highlight = "NeorgTodoItemDoneMark",
            query = "(todo_item_done) @icon",
            extract = function()
                return 1
            end,
        },

        pending = {
            enabled = true,
            icon = "",
            highlight = "NeorgTodoItemPendingMark",
            query = "(todo_item_pending) @icon",
            extract = function()
                return 1
            end,
        },

        undone = {
            enabled = true,
            icon = "×",
            highlight = "NeorgTodoItemUndoneMark",
            query = "(todo_item_undone) @icon",
            extract = function()
                return 1
            end,
        },

        uncertain = {
            enabled = true,
            icon = "",
            highlight = "NeorgTodoItemUncertainMark",
            query = "(todo_item_uncertain) @icon",
            extract = function()
                return 1
            end,
        },

        on_hold = {
            enabled = true,
            icon = "",
            highlight = "NeorgTodoItemOnHoldMark",
            query = "(todo_item_on_hold) @icon",
            extract = function()
                return 1
            end,
        },

        cancelled = {
            enabled = true,
            icon = "",
            highlight = "NeorgTodoItemCancelledMark",
            query = "(todo_item_cancelled) @icon",
            extract = function()
                return 1
            end,
        },

        recurring = {
            enabled = true,
            icon = "⟳",
            highlight = "NeorgTodoItemRecurringMark",
            query = "(todo_item_recurring) @icon",
            extract = function()
                return 1
            end,
        },

        urgent = {
            enabled = true,
            icon = "⚠",
            highlight = "NeorgTodoItemUrgentMark",
            query = "(todo_item_urgent) @icon",
            extract = function()
                return 1
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

    link = {
        enabled = true,
        level_1 = {
            enabled = true,
            icon = " ",
            highlight = "NeorgUnorderedLink1",
            query = "(unordered_link1_prefix) @icon",
        },
        level_2 = {
            enabled = true,
            icon = "  ",
            highlight = "NeorgUnorderedLink2",
            query = "(unordered_link2_prefix) @icon",
        },
        level_3 = {
            enabled = true,
            icon = "   ",
            highlight = "NeorgUnorderedLink3",
            query = "(unordered_link3_prefix) @icon",
        },
        level_4 = {
            enabled = true,
            icon = "    ",
            highlight = "NeorgUnorderedLink4",
            query = "(unordered_link4_prefix) @icon",
        },
        level_5 = {
            enabled = true,
            icon = "     ",
            highlight = "NeorgUnorderedLink5",
            query = "(unordered_link5_prefix) @icon",
        },
        level_6 = {
            enabled = true,
            icon = "      ",
            highlight = "NeorgUnorderedLink6",
            query = "(unordered_link6_prefix) @icon",
        },
    },

    ordered = {
        enabled = require("neorg.external.helpers").is_minimum_version(0, 6, 0),

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
            icon = module.public.concealing.ordered.punctuation.unicode_dot(
                module.public.concealing.ordered.enumerator.numeric
            ),
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
            icon = module.public.concealing.ordered.punctuation.unicode_double_parenthesis(
                module.public.concealing.ordered.enumerator.numeric
            ),
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
            icon = module.public.concealing.ordered.punctuation.unicode_double_parenthesis(
                module.public.concealing.ordered.enumerator.latin_lowercase
            ),
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

    ordered_link = {
        enabled = true,
        level_1 = {
            enabled = true,
            icon = module.public.concealing.ordered.punctuation.unicode_circle(
                module.public.concealing.ordered.enumerator.numeric
            ),
            highlight = "NeorgOrderedLink1",
            query = "(ordered_link1_prefix) @icon",
            render = function(self, _, node)
                local count = module.public.concealing.ordered.get_index(node, "ordered_link1")
                return {
                    { " " .. self.icon(count), self.highlight },
                }
            end,
        },
        level_2 = {
            enabled = true,
            icon = module.public.concealing.ordered.punctuation.unicode_circle(
                module.public.concealing.ordered.enumerator.latin_uppercase
            ),
            highlight = "NeorgOrderedLink2",
            query = "(ordered_link2_prefix) @icon",
            render = function(self, _, node)
                local count = module.public.concealing.ordered.get_index(node, "ordered_link2")
                return {
                    { "  " .. self.icon(count), self.highlight },
                }
            end,
        },
        level_3 = {
            enabled = true,
            icon = module.public.concealing.ordered.punctuation.unicode_circle(
                module.public.concealing.ordered.enumerator.latin_lowercase
            ),
            highlight = "NeorgOrderedLink3",
            query = "(ordered_link3_prefix) @icon",
            render = function(self, _, node)
                local count = module.public.concealing.ordered.get_index(node, "ordered_link3")
                return {
                    { "   " .. self.icon(count), self.highlight },
                }
            end,
        },
        level_4 = {
            enabled = true,
            icon = module.public.concealing.ordered.punctuation.unicode_circle(
                module.public.concealing.ordered.enumerator.numeric
            ),
            highlight = "NeorgOrderedLink4",
            query = "(ordered_link4_prefix) @icon",
            render = function(self, _, node)
                local count = module.public.concealing.ordered.get_index(node, "ordered_link4")
                return {
                    { "    " .. self.icon(count), self.highlight },
                }
            end,
        },
        level_5 = {
            enabled = true,
            icon = module.public.concealing.ordered.punctuation.unicode_circle(
                module.public.concealing.ordered.enumerator.latin_uppercase
            ),
            highlight = "NeorgOrderedLink5",
            query = "(ordered_link5_prefix) @icon",
            render = function(self, _, node)
                local count = module.public.concealing.ordered.get_index(node, "ordered_link5")
                return {
                    { "     " .. self.icon(count), self.highlight },
                }
            end,
        },
        level_6 = {
            enabled = true,
            icon = module.public.concealing.ordered.punctuation.unicode_circle(
                module.public.concealing.ordered.enumerator.latin_lowercase
            ),
            highlight = "NeorgOrderedLink6",
            query = "(ordered_link6_prefix) @icon",
            render = function(self, _, node)
                local count = module.public.concealing.ordered.get_index(node, "ordered_link6")
                return {
                    { "      " .. self.icon(count), self.highlight },
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
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_1.highlight },
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
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_1.highlight },
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_2.highlight },
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
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_1.highlight },
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_2.highlight },
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_3.highlight },
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
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_1.highlight },
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_2.highlight },
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_3.highlight },
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_4.highlight },
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
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_1.highlight },
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_2.highlight },
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_3.highlight },
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_4.highlight },
                    { self.icon, module.config.private.icon_preset_diamond.quote.level_5.highlight },
                    { self.icon, self.highlight },
                }
            end,
        },
    },

    heading = {
        enabled = true,

        level_1 = {
            enabled = true,
            icon = "◈",
            highlight = "NeorgHeading1",
            query = "(heading1_prefix) @icon",
        },

        level_2 = {
            enabled = true,
            icon = " ◇",
            highlight = "NeorgHeading2",
            query = "(heading2_prefix) @icon",
        },

        level_3 = {
            enabled = true,
            icon = "  ◆",
            highlight = "NeorgHeading3",
            query = "(heading3_prefix) @icon",
        },

        level_4 = {
            enabled = true,
            icon = "   ⋄",
            highlight = "NeorgHeading4",
            query = "(heading4_prefix) @icon",
        },

        level_5 = {
            enabled = true,
            icon = "    ❖",
            highlight = "NeorgHeading5",
            query = "(heading5_prefix) @icon",
        },

        level_6 = {
            enabled = true,
            icon = "⟡",
            highlight = "NeorgHeading6",
            query = "(heading6_prefix) @icon",
            render = function(self, text)
                return {
                    {
                        string.rep(" ", text:len() - 2) .. self.icon,
                        self.highlight,
                    },
                }
            end,
        },
    },

    marker = {
        enabled = true,
        icon = "",
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
            render = function(self, _, node)
                -- Get the length of the Neovim window (used to render to the edge of the screen)
                local resulting_length = vim.api.nvim_win_get_width(0)

                -- If we are running at least 0.6 (which has the prev_sibling() function) then
                if require("neorg.external.helpers").is_minimum_version(0, 6, 0) then
                    -- Grab the sibling before our current node in order to later
                    -- determine how much space it occupies in the buffer vertically
                    local prev_sibling = node:prev_sibling()
                    local double_prev_sibling = prev_sibling:prev_sibling()
                    local ts = module.required["core.integrations.treesitter"].get_ts_utils()

                    if prev_sibling then
                        -- Get the text of the previous sibling and store its longest line width-wise
                        local text = ts.get_node_text(prev_sibling)
                        local longest = 3

                        if
                            prev_sibling:parent()
                            and double_prev_sibling
                            and double_prev_sibling:type() == "marker_prefix"
                        then
                            local range_of_prefix = module.required["core.integrations.treesitter"].get_node_range(
                                double_prev_sibling
                            )
                            local range_of_title = module.required["core.integrations.treesitter"].get_node_range(
                                prev_sibling
                            )
                            resulting_length = (range_of_prefix.column_end - range_of_prefix.column_start)
                                + (range_of_title.column_end - range_of_title.column_start)
                        else
                            -- Go through each line and remove its surrounding whitespace,
                            -- we do this because some inconsistencies tend to occur with
                            -- the way whitespace is handled.
                            for _, line in ipairs(text) do
                                line = vim.trim(line)

                                -- If the line even has any "normal" characters
                                -- and its length is a new record then update the
                                -- `longest` variable
                                if line:match("%w") and line:len() > longest then
                                    longest = line:len()
                                end
                            end
                        end

                        -- If we've set a longest value then override the resulting length
                        -- with that longest value (to make it render only up until that point)
                        if longest > 0 then
                            resulting_length = longest
                        end
                    end
                end

                return {
                    {
                        string.rep(self.icon, resulting_length),
                        self.highlight,
                    },
                }
            end,
        },
    },

    markup = {
        enabled = true,

        bold = {
            enabled = true,
            icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
            highlight = "NeorgMarkupBold",
            query = '(bold (["_open" "_close"]) @icon)',
        },

        italic = {
            enabled = true,
            icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
            highlight = "NeorgMarkupItalic",
            query = '(italic (["_open" "_close"]) @icon)',
        },

        underline = {
            enabled = true,
            icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
            highlight = "NeorgMarkupUnderline",
            query = '(underline (["_open" "_close"]) @icon)',
        },

        strikethrough = {
            enabled = true,
            icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
            highlight = "NeorgMarkupStrikethrough",
            query = '(strikethrough (["_open" "_close"]) @icon)',
        },

        subscript = {
            enabled = true,
            icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
            highlight = "NeorgMarkupSubscript",
            query = '(subscript (["_open" "_close"]) @icon)',
        },

        superscript = {
            enabled = true,
            icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
            highlight = "NeorgMarkupSuperscript",
            query = '(superscript (["_open" "_close"]) @icon)',
        },

        verbatim = {
            enabled = true,
            icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
            highlight = "NeorgMarkupVerbatim",
            query = '(verbatim (["_open" "_close"]) @icon)',
        },

        comment = {
            enabled = true,
            icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
            highlight = "NeorgMarkupInlineComment",
            query = '(inline_comment (["_open" "_close"]) @icon)',
        },

        math = {
            enabled = true,
            icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
            highlight = "NeorgMarkupInlineMath",
            query = '(inline_math (["_open" "_close"]) @icon)',
        },

        variable = {
            enabled = true,
            icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
            highlight = "NeorgMarkupVariable",
            query = '(variable (["_open" "_close"]) @icon)',
        },

        spoiler = {
            enabled = true,
            icon = "●",
            highlight = "NeorgSpoiler",
            query = "(spoiler) @icon",
            render = function(self, text, node)
                return {
                    { string.rep(self.icon, #text), self.highlight },
                }
            end,
        },

        link_modifier = {
            enabled = true,
            icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
            highlight = "NeorgLinkModifier",
            query = "(link_modifier) @icon",
            render = function(self)
                return {
                    { self.icon, self.highlight },
                }
            end,
        },

        trailing_modifier = {
            enabled = true,
            icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
            highlight = "NeorgTrailingModifier",
            query = '("_trailing_modifier") @icon',
            render = function(self)
                return {
                    { self.icon, self.highlight },
                }
            end,
        },

        url = {
            enabled = true,

            link = {
                enabled = true,
                icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
                highlight = "NeorgLinkText",
                query = "(link) @icon",
                render = function(self, text, node)
                    local concealed_chars = 0
                    local ts = module.required["core.integrations.treesitter"]
                    local location = nil
                    local description = nil
                    local file = node:named_child(0)

                    if file:type() == "link_file" then
                        location = node:named_child(1)
                        description = node:named_child(2)
                    else
                        location = file
                        file = nil
                        description = node:named_child(1)
                    end

                    if location ~= nil and location:type() == "link_description" then
                        description = location
                        location = nil
                    end

                    if description ~= nil then
                        local description_text = ts.get_node_text(description:named_child(0))
                        concealed_chars = #description_text
                        return {
                            { description_text, self.highlight },
                            { string.rep(self.icon, #text - concealed_chars), "" },
                        }
                    end

                    local extmark_text = {}

                    if file ~= nil then
                        local file_text = ts.get_node_text(file)
                        concealed_chars = #file_text
                        table.insert(extmark_text, { file_text, "NeorgLinkFile" })
                    end

                    if location ~= nil then
                        local location_type = location:named_child(0)
                        local location_text = location:named_child(1)

                        local type = ts.get_node_text(location_type)
                        local text = ts.get_node_text(location_text)

                        local type_name = location_type:type()
                        type_name = vim.fn.substitute(type_name, [[\(_\|^\)\(\w\)]], [[\u\2]], "g")

                        concealed_chars = concealed_chars + #type + #text

                        table.insert(extmark_text, { type, "Neorg" .. type_name .. "Prefix" })
                        table.insert(extmark_text, { text, "Neorg" .. type_name })
                    end

                    table.insert(extmark_text, { string.rep(self.icon, #text - concealed_chars), "" })
                    return extmark_text
                end,
            },

            anchor = {
                enabled = true,
                icon = "⁠", -- not an empty string but the word joiner unicode (U+2060)
                highlight = "NeorgAnchorDeclerationText",
                query = "(anchor_declaration) @icon",
                render = function(self, text, node)
                    local ts = module.required["core.integrations.treesitter"]
                    local addon = ""
                    if node:parent():type() == "anchor_definition" then
                        addon = string.rep(self.icon, 2 + #ts.get_node_text(node:parent():named_child(1)))
                    end
                    return {
                        { text:gsub("%[(.+)%]", self.icon .. "%1" .. self.icon) .. addon, highlight },
                    }
                end,
            },
        },
    },
}

return module
