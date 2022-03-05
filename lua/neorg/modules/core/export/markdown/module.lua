local module = neorg.modules.create("core.export.markdown")

module.public = {
    export = {
        functions = {
            ["_word"] = function(text)
                return text, true
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
                return neorg.lib.match({
                    node:parent():type(),
                    bold = "**",
                    italic = "*",
                    underline = "__",
                    strikethrough = "~~",
                    spoiler = "|",
                    inline_code = "`",
                    inline_comment = "<!-- ",
                })
            end,
            ["_close"] = function(_, node)
                return neorg.lib.match({
                    node:parent():type(),
                    bold = "**",
                    italic = "*",
                    underline = "__",
                    strikethrough = "~~",
                    spoiler = "|",
                    inline_code = "`",
                    inline_comment = " -->",
                })
            end,
            ["_begin"] = function(text, node)
                return neorg.lib.match({
                    node:parent():type(),

                    link_location = function()
                        return text == "{" and "("
                    end,
                    link_description = function()
                        return "["
                    end,
                })
            end,
            ["_end"] = function(text, node)
                return neorg.lib.match({
                    node:parent():type(),

                    link_location = function()
                        return text == "}" and ")"
                    end,
                    link_description = function()
                        return "]"
                    end,
                })
            end,
            ["link_file_text"] = function(text)
                return vim.uri_from_fname(text .. ".md"):sub(string.len("file://") + 1)
            end,
        },
        recollectors = {
            ["link_location"] = function(output)
                table.insert(output, #output - 1, "#")

                output[#output - 1] = output[#output - 1]:lower():gsub("[^%s%w]+", ""):gsub("%s+", "-")

                return output
            end,
            ["link"] = function(output)
                return {
                    output[2],
                    output[1],
                }
            end,
        },
    },
}

return module
