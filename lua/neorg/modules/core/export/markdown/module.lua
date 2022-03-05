local module = neorg.modules.create("core.export.markdown")

-- Multiple `if/elseif` statements exist not to look ugly
-- but instead to be more perfomant than Neorg's match function

local last_parsed_link_location = ""

module.public = {
    export = {
        functions = {
            ["_word"] = function(text)
                return text
            end,
            ["_space"] = function(space)
                return space
            end,
            ["_line_break"] = function()
                return "\n"
            end,
            ["_paragraph_break"] = function(newlines)
                return string.rep("\n", newlines:len())
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
        },
    },
}

return module
