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
            ["heading1_prefix"] = function() return "# " end,
            ["heading2_prefix"] = function() return "## " end,
            ["heading3_prefix"] = function() return "### " end,
            ["heading4_prefix"] = function() return "#### " end,
            ["heading5_prefix"] = function() return "##### " end,
            ["heading6_prefix"] = function() return "###### " end,
            ["bold"] = function(text) return "**" .. text:sub(2, -2) .. "**" end,
            ["italic"] = function(text) return "*" .. text:sub(2, -2) .. "*" end,
            ["underline"] = function(text) return "__" .. text:sub(2, -2) .. "__" end,
            ["strikethrough"] = function(text) return "~~" .. text:sub(2, -2) .. "~~" end,
            ["spoiler"] = function(text) return "||" .. text:sub(2, -2) .. "||" end,
        }
    },
}

return module
