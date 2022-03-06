local module = neorg.modules.create("core.export.markdown")

-- Multiple `if/elseif` statements exist not to look ugly
-- but instead to be more perfomant than Neorg's match function

local last_parsed_link_location = ""

local function unordered_list_prefix(level)
    return function()
        return string.rep(" ", (level - 1) * 4) .. "- ", true, {
            indent = ((level - 1) * 4) + 2,
        }
    end
end

local function ordered_list_prefix(level)
    return function(_, _, state)
        state.ordered_list_level[level] = state.ordered_list_level[level] + 1
        state.indent = ((level - 1) * 4) + 3 + (tostring(state.ordered_list_level[level]):len() - 1)

        for i = level + 1, 6 do
            state.ordered_list_level[i] = 0
        end

        return string.rep(" ", (level - 1) * 4) .. tostring(state.ordered_list_level[level]) .. ". ", true, state
    end
end

module.public = {
    export = {
        init_state = function()
            return {
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
                    .. (
                        (next_sibling and next_sibling:type() == "paragraph_segment" and string.rep(" ", state.indent))
                        or ""
                    )
            end,
            ["_paragraph_break"] = function(newlines)
                return string.rep("\n", newlines:len()),
                    false,
                    {
                        indent = 0,
                        ordered_list_level = { 0, 0, 0, 0, 0, 0 },
                    }
            end,
            ["_segment"] = function(text)
                return text, false
            end,
            ["heading1_prefix"] = function()
                return "# "
            end,
            ["heading2_prefix"] = function()
                return "## "
            end,
            ["heading3_prefix"] = function()
                return "### "
            end,
            ["heading4_prefix"] = function()
                return "#### "
            end,
            ["heading5_prefix"] = function()
                return "##### "
            end,
            ["heading6_prefix"] = function()
                return "###### "
            end,
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
                        tag_close = "```"
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
                table.insert(output, 3, "\n")
                return output
            end
        },

        cleanup = function(text)
            return text:gsub("\n\n\n+", "\n\n")
        end,
    },
}

return module
