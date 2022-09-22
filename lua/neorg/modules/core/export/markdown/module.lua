--[[
    File: Markdown-Export
    Title: Neorg's Markdown Exporter
    Summary: Interface for `core.export` to allow exporting to markdown.
    ---
This module exists as an interface for `core.export` to export `.norg` files to MD.
As a user the only reason you would ever have to touch this module is to configure *how* you'd
like your markdown to be exported (i.e. do you want to support certain extensions during the export).
--]]

-- TODO: One day this module will need to be restructured or maybe even rewritten.
-- It's not atrocious, but there are a lot of moving parts that make it difficult to understand
-- from another person's perspective. Some cleanup and rethinking of certain implementation
-- details will be necessary.

local module = neorg.modules.create("core.export.markdown")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
        },
    }
end

local last_parsed_link_location = ""

--> Generic Utility Functions

local function unordered_list_prefix(level)
    return function()
        return {
            output = string.rep(" ", (level - 1) * 4) .. "- ",
            keep_descending = true,
            state = {
                weak_indent = ((level - 1) * 4) + 2,
            },
        }
    end
end

local function ordered_list_prefix(level)
    return function(_, _, state)
        state.ordered_list_level[level] = state.ordered_list_level[level] + 1
        state.weak_indent = ((level - 1) * 4) + 3 + (tostring(state.ordered_list_level[level]):len() - 1)

        for i = level + 1, 6 do
            state.ordered_list_level[i] = 0
        end

        return {
            output = string.rep(" ", (level - 1) * 4) .. tostring(state.ordered_list_level[level]) .. ". ",
            keep_descending = true,
            state = state,
        }
    end
end

local function todo_item_extended(replace_text)
    return function(_, _, state)
        return {
            output = module.config.public.extensions["todo-items-extended"] and replace_text or nil,
            state = {
                weak_indent = state.weak_indent + replace_text:len(),
            },
        }
    end
end

--> Recollector Utility Functions

local function todo_item_recollector()
    return function(output)
        return output[2] ~= "[_] " and output
    end
end

local function handle_heading_newlines()
    return function(output, _, node, ts_utils)
        local prev = ts_utils.get_previous_node(node, true, true)

        if
            prev
            and not vim.tbl_contains({ "_line_break", "_paragraph_break" }, prev:type())
            and ((prev:end_()) + 1) ~= (node:start())
        then
            output[1] = "\n" .. output[1]
        end

        if output[3] then
            output[3] = output[3] .. "\n"
        end

        return output
    end
end

---

module.load = function()
    if module.config.public.extensions == "all" then
        module.config.public.extensions = {
            "todo-items-basic",
            "todo-items-pending",
            "todo-items-extended",
            "definition-lists",
            "mathematics",
            "metadata",
        }
    end

    module.config.public.extensions = neorg.lib.to_keys(module.config.public.extensions)
end

module.config.public = {
    -- Any extensions you may want to use when exporting to markdown. By
    -- default no extensions are loaded (the exporter is commonmark compliant).
    -- You can also set this value to `"all"` to enable all extensions.
    -- The full extension list is: `todo-items-basic`, `todo-items-pending`, `todo-items-extended`,
    -- `definition-lists`, `mathematics` and 'metadata'.
    extensions = {},

    -- Data about how to render mathematics.
    -- The default is recommended as it is the most common, although certain flavours
    -- of markdown use different syntax.
    mathematics = {
        inline = {
            start = "$",
            ["end"] = "$",
        },
        block = {
            start = "$$",
            ["end"] = "$$",
        },
    },

    -- Data about how to render metadata
    -- There are a few ways to render metadata blocks, but this is the most
    -- common.
    metadata = {
        start = "---",
        ["end"] = "---", -- Is usually also "..."
    },

    -- Used by the exporter to know what extension to use
    -- when creating markdown files.
    -- The default is recommended, although you can change it.
    extension = "md",
}

module.public = {
    export = {
        init_state = function()
            return {
                weak_indent = 0,
                indent = 0,
                ordered_list_level = {
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                },
                tag_indent = 0,
                tag_close = "",
                ranged_tag_indentation_level = 0,
                is_url = false,
            }
        end,

        functions = {
            ["_word"] = true,
            ["_space"] = true,

            ["_line_break"] = function(_, node, state)
                local next_sibling = node:next_sibling()

                return "\n"
                    .. ((next_sibling and next_sibling:type() == "paragraph_segment" and string.rep(
                        " ",
                        state.weak_indent
                    )) or "")
                    .. string.rep(" ", state.indent)
            end,

            ["_paragraph_break"] = function(newlines, _, state)
                return {
                    output = string.rep("\n\n", newlines:len()) .. string.rep(" ", state.indent),
                    state = {
                        weak_indent = 0,
                        ordered_list_level = { 0, 0, 0, 0, 0, 0 },
                    },
                }
            end,

            ["_segment"] = function(text, node, state)
                return string.rep(" ", state.indent + (({ node:range() })[2] - state.ranged_tag_indentation_level))
                    .. text
            end,

            ["heading1_prefix"] = "# ",
            ["heading2_prefix"] = "## ",
            ["heading3_prefix"] = "### ",
            ["heading4_prefix"] = "#### ",
            ["heading5_prefix"] = "##### ",
            ["heading6_prefix"] = "###### ",

            ["_open"] = function(_, node)
                local type = node:parent():type()

                if type == "bold" then
                    return "**"
                elseif type == "italic" then
                    return "_"
                elseif type == "underline" then
                    return "<u>"
                elseif type == "strikethrough" then
                    return "~~"
                elseif type == "spoiler" then
                    return "|"
                elseif type == "verbatim" then
                    return "`"
                elseif type == "superscript" then
                    return "<sup>"
                elseif type == "subscript" then
                    return "<sub>"
                elseif type == "inline_comment" then
                    return "<!-- "
                elseif type == "inline_math" and module.config.public.extensions["mathematics"] then
                    return module.config.public.mathematics.inline["start"]
                end
            end,

            ["_close"] = function(_, node)
                local type = node:parent():type()

                if type == "bold" then
                    return "**"
                elseif type == "italic" then
                    return "_"
                elseif type == "underline" then
                    return "</u>"
                elseif type == "strikethrough" then
                    return "~~"
                elseif type == "spoiler" then
                    return "|"
                elseif type == "verbatim" then
                    return "`"
                elseif type == "superscript" then
                    return "</sup>"
                elseif type == "subscript" then
                    return "</sub>"
                elseif type == "inline_comment" then
                    return " -->"
                elseif type == "inline_math" and module.config.public.extensions["mathematics"] then
                    return module.config.public.mathematics.inline["end"]
                end
            end,

            ["_begin"] = function(text, node)
                local type = node:parent():type()

                if type == "link_location" then
                    return text == "{" and "("
                elseif type == "link_description" then
                    return "["
                end
            end,

            ["_end"] = function(text, node)
                local type = node:parent():type()

                if type == "link_location" then
                    return text == "}" and ")"
                elseif type == "link_description" then
                    return "]"
                end
            end,

            ["link_file_text"] = function(text)
                return vim.uri_from_fname(text .. ".md"):sub(string.len("file://") + 1)
            end,

            ["link_target_url"] = function()
                return {
                    state = {
                        is_url = true,
                    },
                }
            end,

            ["escape_sequence"] = function(text)
                local escaped_char = text:sub(-1)
                return escaped_char:match("%p") and text or escaped_char
            end,

            ["unordered_list1_prefix"] = unordered_list_prefix(1),
            ["unordered_list2_prefix"] = unordered_list_prefix(2),
            ["unordered_list3_prefix"] = unordered_list_prefix(3),
            ["unordered_list4_prefix"] = unordered_list_prefix(4),
            ["unordered_list5_prefix"] = unordered_list_prefix(5),
            ["unordered_list6_prefix"] = unordered_list_prefix(6),

            ["ordered_list1_prefix"] = ordered_list_prefix(1),
            ["ordered_list2_prefix"] = ordered_list_prefix(2),
            ["ordered_list3_prefix"] = ordered_list_prefix(3),
            ["ordered_list4_prefix"] = ordered_list_prefix(4),
            ["ordered_list5_prefix"] = ordered_list_prefix(5),
            ["ordered_list6_prefix"] = ordered_list_prefix(6),

            ["tag_parameters"] = function(text, _, state)
                if state.ignore_tag_parameters then
                    state.ignore_tag_parameters = nil
                    return {
                        output = "",
                        state = state,
                    }
                end

                return text
            end,

            ["tag_name"] = function(text, node, _, _)
                local _, tag_start_column = node:range()

                if text == "code" then
                    return {
                        output = "```",
                        state = {
                            -- Minus one to account for the `@`
                            tag_indent = tag_start_column - 1,
                            tag_close = "```",
                        },
                    }
                elseif text == "comment" then
                    return {
                        output = "<!--",
                        state = {
                            tag_indent = tag_start_column - 1,
                            tag_close = "-->",
                        },
                    }
                elseif text == "math" and module.config.public.extensions["mathematics"] then
                    return {
                        output = module.config.public.mathematics.block["start"],
                        state = {
                            tag_indent = tag_start_column - 1,
                            tag_close = module.config.public.mathematics.block["end"],
                        },
                    }
                elseif text == "document.meta" and module.config.public.extensions["metadata"] then
                    return {
                        output = module.config.public.metadata["start"],
                        state = {
                            tag_indent = tag_start_column - 1,
                            tag_close = module.config.public.metadata["end"],
                            is_meta = true,
                        },
                    }
                elseif
                    text == "embed"
                    and node:next_sibling()
                    and module.required["core.integrations.treesitter"].get_node_text(node:next_sibling())
                        == "markdown"
                then
                    return {
                        state = {
                            tag_indent = tag_start_column - 1,
                            tag_close = "",
                            ignore_tag_parameters = true,
                        },
                    }
                end

                return {
                    state = {
                        ignore_tag_parameters = true,
                        tag_close = nil,
                    },
                }
            end,

            ["ranged_tag_content"] = function(text, node, state)
                if state.is_meta then
                    state.is_meta = false
                    return {
                        keep_descending = true,
                        state = {
                            parse_as = "norg_meta",
                        },
                    }
                end

                local _, ranged_tag_content_column_start = node:range()

                local split_text = vim.split(text, "\n")

                split_text[1] = string.rep(" ", ranged_tag_content_column_start - state.tag_indent) .. split_text[1]

                for i = 2, #split_text do
                    split_text[i] = split_text[i]:sub(state.tag_indent + 1)
                end

                return state.tag_close and (table.concat(split_text, "\n") .. "\n")
            end,

            ["ranged_tag_end"] = function(_, _, state)
                local tag_close = state.tag_close
                state.tag_close = nil
                return tag_close
            end,

            ["quote1_prefix"] = true,
            ["quote2_prefix"] = true,
            ["quote3_prefix"] = true,
            ["quote4_prefix"] = true,
            ["quote5_prefix"] = true,
            ["quote6_prefix"] = true,

            ["todo_item_done"] = function(_, _, state)
                return {
                    output = module.config.public.extensions["todo-items-basic"] and "[x] ",
                    state = {
                        weak_indent = state.weak_indent + 4,
                    },
                }
            end,

            ["todo_item_undone"] = function(_, _, state)
                return {
                    output = module.config.public.extensions["todo-items-basic"] and "[ ] ",
                    state = {
                        weak_indent = state.weak_indent + 4,
                    },
                }
            end,

            ["todo_item_pending"] = function(_, _, state)
                return {
                    output = module.config.public.extensions["todo-items-pending"] and "[*] ",
                    state = {
                        weak_indent = state.weak_indent + 4,
                    },
                }
            end,

            ["todo_item_urgent"] = todo_item_extended("[ ] "),
            ["todo_item_cancelled"] = todo_item_extended("[_] "),
            ["todo_item_recurring"] = todo_item_extended("[ ] "),
            ["todo_item_on_hold"] = todo_item_extended("[ ] "),
            ["todo_item_uncertain"] = todo_item_extended("[ ] "),

            ["single_definition_prefix"] = function()
                return module.config.public.extensions["definition-lists"] and ": "
            end,

            ["multi_definition_prefix"] = function(_, _, state)
                if not module.config.public.extensions["definition-lists"] then
                    return
                end

                return {
                    output = ": ",
                    state = {
                        indent = state.indent + 2,
                    },
                }
            end,

            ["multi_definition_suffix"] = function(_, _, state)
                if not module.config.public.extensions["definition-lists"] then
                    return
                end

                return {
                    state = {
                        indent = state.indent - 2,
                    },
                }
            end,

            ["_prefix"] = function(_, node)
                return {
                    state = {
                        ranged_tag_indentation_level = ({ node:range() })[2],
                    },
                }
            end,

            ["capitalized_word"] = function(text, node)
                if node:parent():type() == "insertion" then
                    if text == "Image" then
                        return "!["
                    end
                end
            end,

            ["carryover_tag"] = "",

            ["key"] = true,

            [":"] = ": ",

            ["["] = function(_, _, state)
                return {
                    state = {
                        indent = state.indent + 2,
                    },
                }
            end,
            ["]"] = function(_, _, state)
                return {
                    state = {
                        indent = state.indent - 2,
                    },
                }
            end,

            ["value"] = function(text, node, state)
                if node:parent():type() == "array" then
                    return "\n" .. string.rep(" ", state.indent) .. "- " .. text
                end

                return text
            end,
        },

        recollectors = {
            ["link_location"] = function(output, state)
                last_parsed_link_location = output[#output - 1]

                if state.is_url then
                    state.is_url = false
                    output[#output - 1] = vim.uri_from_fname(output[#output - 1]):sub(string.len("file://") + 1)
                    return output
                end

                table.insert(output, #output - 1, "#")
                output[#output - 1] = output[#output - 1]:lower():gsub("-", " "):gsub("%p+", ""):gsub("%s+", "-")

                return output
            end,

            ["link"] = function(output)
                return {
                    output[2] or ("[" .. last_parsed_link_location .. "]"),
                    output[1],
                }
            end,

            ["ranged_tag"] = function(output)
                if #output == 2 or (output[2] and output[2]:sub(-1, -1) == "\n") then
                    table.insert(output, 2, "\n")
                else
                    table.insert(output, 3, "\n")
                end

                return output
            end,

            ["todo_item1"] = todo_item_recollector(),
            ["todo_item2"] = todo_item_recollector(),
            ["todo_item3"] = todo_item_recollector(),
            ["todo_item4"] = todo_item_recollector(),
            ["todo_item5"] = todo_item_recollector(),
            ["todo_item6"] = todo_item_recollector(),

            ["single_definition"] = function(output)
                return {
                    output[2],
                    output[3],
                    output[1],
                    output[4],
                }
            end,

            ["multi_definition"] = function(output)
                output[3] = output[3]:gsub("^\n+  ", "\n") .. output[1]
                table.remove(output, 1)

                return output
            end,

            ["insertion"] = function(output)
                if output[1] == "![" then
                    table.insert(output, 1, "\n")

                    local split = vim.split(output[3], "/", { plain = true })
                    table.insert(output, 3, (split[#split]:match("^(.+)%..+$") or split[#split]) .. "](")
                    table.insert(output, ")\n")
                end

                return output
            end,

            ["heading1"] = handle_heading_newlines(),
            ["heading2"] = handle_heading_newlines(),
            ["heading3"] = handle_heading_newlines(),
            ["heading4"] = handle_heading_newlines(),
            ["heading5"] = handle_heading_newlines(),
            ["heading6"] = handle_heading_newlines(),

            ["pair"] = function(output)
                table.insert(output, "\n")
                return output
            end,
        },

        cleanup = function()
            last_parsed_link_location = ""
        end,
    },
}

return module
