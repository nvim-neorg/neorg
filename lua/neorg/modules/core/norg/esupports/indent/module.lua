--[[
-- TODO
--]]

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

        local indent = 0

        for _, modifier in ipairs(indent_data.modifiers or {}) do
            if module.config.public.modifiers[modifier] then
                local ret = module.config.public.modifiers[modifier](buf, node)

                if ret ~= 0 then
                    indent = ret
                end
            end
        end

        if type(indent_data.indent) == "number" then
            return indent + indent_data.indent
        end

        return indent + indent_data.indent(buf, node)
    end,
}

module.config.public = {
    indents = {
        _ = {
            modifiers = { "under-headings" },
            indent = 0,
        },

        ["paragraph_segment"] = {
            modifiers = { "under-headings", "under-unordered-lists" },
            indent = 0,
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
    },
    modifiers = {
        -- For any object that can exist under headings
        ["under-headings"] = function(_, node)
            local heading = module.required["core.integrations.treesitter"].find_parent(node, "heading%d")

            if not heading or not heading:named_child(1) then
                return 0
            end

            return module.required["core.integrations.treesitter"].get_node_range(heading:named_child(1)).column_start
        end,

        -- For any object that should be indented under a list
        ["under-unordered-lists"] = function(_, node)
            local list = module.required["core.integrations.treesitter"].find_parent(node, "unordered_list%d")

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

        vim.api.nvim_buf_set_option(event.buffer, "indentkeys", "o,O,*<CR>")
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
    },
}

return module