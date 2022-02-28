local module = neorg.modules.create("core.export.markdown")

local function detached_modifier_prefix(modifier)
    return {
        convert = function()
            return modifier .. " "
        end,
    }
end

module.public = {
    converters = {
        ["_word"] = {
            convert = function(data, node)
                return node:parent():type() == "paragraph_segment" and data
            end,
        },
        ["_space"] = {
            convert = function()
                return " "
            end,
        },
        ["heading1_prefix"] = detached_modifier_prefix("#"),
        ["heading2_prefix"] = detached_modifier_prefix("##"),
        ["heading3_prefix"] = detached_modifier_prefix("###"),
        ["heading4_prefix"] = detached_modifier_prefix("####"),
        ["heading5_prefix"] = detached_modifier_prefix("#####"),
        ["heading6_prefix"] = detached_modifier_prefix("######"),
        ["unordered_list1_prefix"] = detached_modifier_prefix("-"),
        ["unordered_list2_prefix"] = detached_modifier_prefix("\t-"),
        ["unordered_list3_prefix"] = detached_modifier_prefix("\t\t-"),
        ["unordered_list4_prefix"] = detached_modifier_prefix("\t\t\t-"),
        ["unordered_list5_prefix"] = detached_modifier_prefix("\t\t\t\t-"),
        ["unordered_list6_prefix"] = {
            convert = function(data)
                return string.rep("\t", vim.fn.count(data, "-")) .. "- "
            end,
        },
    },
}

return module
