--[[
-- TODO
--]]

-- TODO: Make `get_first_node_on_line` move up the node list to the closest named parent

local module = neorg.modules.create("core.norg.esupports.indent")

module.setup = function()
    return {
        wants = {
            "core.integrations.treesitter",
            "core.autocommands",
        },
    }
end

module.public = {
    indentexpr = function(buf)
        local node = module.required["core.integrations.treesitter"].get_first_node_on_line(buf, vim.v.lnum - 1)
            or module.required["core.integrations.treesitter"].get_first_node_on_line(buf, vim.v.lnum - 1, true, true)

        if not node then
            return 0
        end

        local indent_data = module.config.public.indents[node:type()] or module.config.public.indents._

        if not indent_data then
            return 0
        end

        local initial_indent = module.required["core.integrations.treesitter"].get_node_range(node).column_start

        local indent = 0

        for _, modifier in ipairs(indent_data.modifiers or {}) do
            if module.config.public.modifiers[modifier] then
                local ret = module.config.public.modifiers[modifier](buf, node, initial_indent)

                if ret ~= 0 then
                    indent = ret
                end
            end
        end

        local line_len = vim.fn.getline(vim.v.lnum):len()

        local current_lang = vim.treesitter.get_parser(buf, "norg"):language_for_range({
            vim.v.lnum - 1,
            line_len,
            vim.v.lnum - 1,
            line_len,
        })

        if current_lang:lang() ~= "norg" then
            local prev = module.required["core.integrations.treesitter"].get_first_node_on_line(buf, vim.v.lnum - 2)

            if prev and prev:type() == "ranged_tag" then
                return module.required["core.integrations.treesitter"].get_node_range(prev).column_start
                    + vim.fn["nvim_treesitter#indent"]()
            else
                return vim.fn["nvim_treesitter#indent"]()
            end
        end

        if type(indent_data.indent) == "number" then
            return indent_data.indent ~= -1 and (indent + indent_data.indent) or -1
        end

        local calculated_indent = indent_data.indent(buf, node, indent, initial_indent) or 0
        return calculated_indent ~= -1 and (indent + calculated_indent) or -1
    end,
}

module.config.public = {
    indents = {
        _ = {
            modifiers = { "under-headings" },
            indent = 0,
        },

        ["paragraph_segment"] = {
            modifiers = { "under-headings", "under-nestable-detached-modifiers" },
            indent = 0,
        },

        ["_line_break"] = {
            indent = function(_, node)
                if node:parent():type() == "ranged_tag_content" then
                    return -1
                end
            end,
        },

        ["strong_paragraph_delimiter"] = {
            indent = function(buf)
                local node = module.required["core.integrations.treesitter"].get_first_node_on_line(
                    buf,
                    vim.fn.prevnonblank(vim.v.lnum - 1) - 1
                )

                if not node then
                    return 0
                end

                return module.required["core.integrations.treesitter"].get_node_range(
                    node:type():match("heading%d") and node:named_child(1) or node
                ).column_start
            end,
        },

        ["heading1"] = {
            indent = 0,
        },
        ["heading2"] = {
            indent = 0,
        },
        ["heading3"] = {
            indent = 0,
        },
        ["heading4"] = {
            indent = 0,
        },
        ["heading5"] = {
            indent = 0,
        },
        ["heading6"] = {
            indent = 0,
        },

        ["ranged_tag"] = {
            modifiers = { "under-headings" },
            indent = 0,
        },

        ["ranged_tag_content"] = {
            indent = -1,
        },

        ["ranged_tag_end"] = {
            indent = function(_, node)
                return module.required["core.integrations.treesitter"].get_node_range(node:parent()).column_start
            end,
        },
    },
    modifiers = {
        -- For any object that can exist under headings
        ["under-headings"] = function(_, node)
            local heading = module.required["core.integrations.treesitter"].find_parent(node:parent(), "heading%d")

            if not heading or not heading:named_child(1) then
                return 0
            end

            return module.required["core.integrations.treesitter"].get_node_range(heading:named_child(1)).column_start
        end,

        -- For any object that should be indented under a list
        ["under-nestable-detached-modifiers"] = function(_, node)
            local list = module.required["core.integrations.treesitter"].find_parent(node, {
                "unordered_list1",
                "unordered_list2",
                "unordered_list3",
                "unordered_list4",
                "unordered_list5",
                "unordered_list6",
                "ordered_list1",
                "ordered_list2",
                "ordered_list3",
                "ordered_list4",
                "ordered_list5",
                "ordered_list6",
                "quote1",
                "quote2",
                "quote3",
                "quote4",
                "quote5",
                "quote6",
            })

            if not list or not list:named_child(1) then
                return 0
            end

            return module.required["core.integrations.treesitter"].get_node_range(list:named_child(1)).column_start
        end,
    },
}

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufEnter")
end

module.on_event = function(event)
    if event.type == "core.autocommands.events.bufenter" and event.content.norg then
        vim.api.nvim_buf_set_option(
            event.buffer,
            "indentexpr",
            ("v:lua.neorg.modules.get_module('core.norg.esupports.indent').indentexpr(%d)"):format(event.buffer)
        )

        vim.api.nvim_buf_set_option(event.buffer, "indentkeys", "o,O,*<CR>,*<Esc>,*<M-o>,*<M-O>")
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
    },
}

return module
