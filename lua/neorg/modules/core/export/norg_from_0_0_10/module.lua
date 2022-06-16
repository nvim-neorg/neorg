local module = neorg.modules.create("core.export.norg_from_0_0_10")

local function convert_unordered_link(text)
    local substitution = text:gsub("^([%-~]+)>", "%1")
    return substitution
end

module.config.public = {
    extension = "norg",
    verbatim = true,
}

local function save_whitespace_information()
    return function(text, node, state, ts_utils)
        local start_line, start_column = node:range()

        local prev = node:prev_sibling()

        if not prev then
            return nil, true, {
                [start_line] = (state[start_line] and math.min(state[start_line], start_column) or start_column),
            }
        end

        local _, _, prev_end_line = prev:range()

        if start_line == prev_end_line then
            return nil, true
        end

        return nil, true, {
            [start_line] = (state[start_line] and math.min(state[start_line], start_column) or start_column),
        }
    end
end

local function retain_whitespace()
    return function(output, state, node)
        local start_line, start_column = node:range()

        if start_column == vim.fn.getline(start_line + 1):match("^%s*"):len() then
            table.insert(output, 1, string.rep(" ", state[start_line]))
            state[start_line] = 0
        end

        return output
    end
end

module.public = {
    output = "0.0.11",

    export = {
        functions = {
            _ = save_whitespace_information(),

            ["_open"] = function(text, node)
                if node:parent():type() == "spoiler" then
                    return "!"
                elseif node:parent():type() == "variable" then
                    return "&"
                end

                return text
            end,

            ["_close"] = function(text, node)
                if node:parent():type() == "spoiler" then
                    return "!"
                elseif node:parent():type() == "variable" then
                    return "&"
                end

                return text
            end,

            ["_prefix"] = function(text, node)
                if node:parent():type() == "carryover_tag" then
                    return "|"
                end

                return text
            end,

            -- TODO: Apply this also to macro invocations
            -- Support new markers
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
        },

        recollectors = {
            _ = retain_whitespace(),
        }
    },
}

return module
