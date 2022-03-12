local module = neorg.modules.create("core.export.markdown")

local last_parsed_link_location = ""

--> Generic Utility Functions

local function unordered_list_prefix(level)
    return function()
        return string.rep(" ", (level - 1) * 4) .. "- ",
            true,
            {
                weak_indent = ((level - 1) * 4) + 2,
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

        return string.rep(" ", (level - 1) * 4) .. tostring(state.ordered_list_level[level]) .. ". ", true, state
    end
end

local function todo_item_extended(replace_text)
    return function(_, _, state)
        return module.config.public.extensions["todo-items-extended"] and replace_text,
            false,
            {
                weak_indent = state.weak_indent + replace_text:len(),
            }
    end
end

--> Recollector Utility Functions

local function todo_item_recollector()
    return function(output)
        return output[2] ~= "[_] " and output
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
        }
    end

    module.config.public.extensions = neorg.lib.to_keys(module.config.public.extensions)
end

module.config.public = {
    -- Any extensions you may want to use when exporting to markdown. By
    -- default no extensions are loaded (the exporter is commonmark compliant).
    -- You can also set this value to `all` to enable all extensions.
    extensions = {},
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
                tag_close = "",
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
                return string.rep("\n", newlines:len()) .. string.rep(" ", state.indent),
                    false,
                    {
                        weak_indent = 0,
                        ordered_list_level = { 0, 0, 0, 0, 0, 0 },
                    }
            end,

            ["_segment"] = function(text, _, state)
                return string.rep(" ", state.indent) .. text
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
                    return "__"
                elseif type == "strikethrough" then
                    return "~~"
                elseif type == "spoiler" then
                    return "|"
                elseif type == "verbatim" then
                    return "`"
                elseif type == "inline_comment" then
                    return "<!-- "
                end
            end,

            ["_close"] = function(_, node)
                local type = node:parent():type()

                if type == "bold" then
                    return "**"
                elseif type == "italic" then
                    return "_"
                elseif type == "underline" then
                    return "__"
                elseif type == "strikethrough" then
                    return "~~"
                elseif type == "spoiler" then
                    return "|"
                elseif type == "verbatim" then
                    return "`"
                elseif type == "inline_comment" then
                    return " -->"
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

            ["tag_parameters"] = true,

            ["tag_name"] = function(text)
                if text == "code" then
                    return "```", false, {
                        tag_close = "```",
                    }
                end
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
                return module.config.public.extensions["todo-items-basic"] and "[x] ",
                    false,
                    {
                        weak_indent = state.weak_indent + 4,
                    }
            end,

            ["todo_item_undone"] = function(_, _, state)
                return module.config.public.extensions["todo-items-basic"] and "[ ] ",
                    false,
                    {
                        weak_indent = state.weak_indent + 4,
                    }
            end,

            ["todo_item_pending"] = function(_, _, state)
                return module.config.public.extensions["todo-items-pending"] and "[*] ",
                    false,
                    {
                        weak_indent = state.weak_indent + 4,
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

                return ": ", false, {
                    indent = state.indent + 2,
                }
            end,

            ["multi_definition_suffix"] = function(_, _, state)
                if not module.config.public.extensions["definition-lists"] then
                    return
                end

                return nil, false, {
                    indent = state.indent - 2,
                }
            end,
        },

        recollectors = {
            ["link_location"] = function(output)
                table.insert(output, #output - 1, "#")

                last_parsed_link_location = output[#output - 1]
                output[#output - 1] = output[#output - 1]:lower():gsub("[^%s%w]+", ""):gsub("%s+", "-")

                return output
            end,

            ["link"] = function(output)
                return {
                    output[2] or ("[" .. last_parsed_link_location .. "]"),
                    output[1],
                }
            end,

            ["ranged_tag"] = function(output)
                if #output == 2 or output[2]:sub(-1, -1) == "\n" then
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
        },

        cleanup = function(text)
            return text:gsub("\n\n\n+", "\n\n")
        end,
    },
}

return module
