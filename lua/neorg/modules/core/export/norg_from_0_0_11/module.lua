local module = neorg.modules.create("core.export.norg_from_0_0_11")

local function convert_todo_item(text)
    -- NOTE(vhyrro): We must extract the return value of `gsub` into a single variable
    -- If we inline the function call to be in the return statement then
    -- we may accidentally return two values, which we don't want.
    local substitution = text:gsub("^(%-+%s+)%[([ %p])%]", "%1|%2|")
    return substitution
end

local function convert_unordered_link(text)
    local substitution = text:gsub("^([%-~]+)>", "%1")
    return substitution
end

module.config.public = {
    extension = "norg",
    verbatim = true,
}

module.public = {
    output = "0.0.12",

    export = {
        functions = {
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

            ["_prefix"] = function(_, node)
                if node:parent():type() == "carryover_tag" then
                    return "|"
                end
            end,

            ["todo_item1"] = convert_todo_item,
            ["todo_item2"] = convert_todo_item,
            ["todo_item3"] = convert_todo_item,
            ["todo_item4"] = convert_todo_item,
            ["todo_item5"] = convert_todo_item,
            ["todo_item6"] = convert_todo_item,

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
