local module = neorg.modules.create("core.export.norg_from_0_0_10")

local function convert_unordered_link(text)
    local substitution = text:gsub("^([%-~]+)>", "%1")
    return substitution
end

module.config.public = {
    extension = "norg",
    verbatim = true,
}

module.public = {
    output = "0.0.11",

    export = {
        functions = {
            _ = function(text, node, _, ts_utils)
                local prev = ts_utils.get_previous_node(node, true, true)
                -- TODO: Fix
                log.warn(node, prev, node:child_count())

                local prev_start_line, prev_start_column = prev and prev:range()
                local start_line, start_column = node:range()

                return (prev_start_line ~= start_line and string.rep(" ", start_column) .. text or text)
            end,

            ["_open"] = function(_, node)
                if node:parent():type() == "spoiler" then
                    return "!"
                end
            end,

            ["_close"] = function(_, node)
                if node:parent():type() == "spoiler" then
                    return "!"
                end
            end,

            ["_prefix"] = function(text, node)
                if node:parent():type() == "carryover_tag" then
                    return "|"
                end

                return text
            end,

            ["tag_name"] = function(text, node)
                local next = node:next_named_sibling()
                if next and next:type() == "tag_parameters" then
                    return text .. " "
                end

                -- HACK: This is a workaround for the TS parser
                -- not having a _line_break node after the tag declaration
                return text .. "\n"
            end,

            ["todo_item_undone"] = "| | ",
            ["todo_item_pending"] = "|-| ",
            ["todo_item_done"] = "|x| ",
            ["todo_item_on_hold"] = "|=| ",
            ["todo_item_cancelled"] = "|_| ",
            ["todo_item_urgent"] = "|!| ",
            ["todo_item_uncertain"] = "|?| ",
            ["todo_item_recurring"] = "|+| ",

            ["unordered_link1"] = convert_unordered_link,
            ["unordered_link2"] = convert_unordered_link,
            ["unordered_link3"] = convert_unordered_link,
            ["unordered_link4"] = convert_unordered_link,
            ["unordered_link5"] = convert_unordered_link,
            ["unordered_link6"] = convert_unordered_link,

            ["ordered_link1"] = convert_unordered_link,
            ["ordered_link2"] = convert_unordered_link,
            ["ordered_link3"] = convert_unordered_link,
            ["ordered_link4"] = convert_unordered_link,
            ["ordered_link5"] = convert_unordered_link,
            ["ordered_link6"] = convert_unordered_link,
        }
    }
}

return module
