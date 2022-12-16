--[[
    File: Indent
    Title: Proper Indents with `core.norg.esupports.indent`
    Summary: A set of instructions for Neovim to indent Neorg documents.
    ---
--]]

local module = neorg.modules.create("core.norg.esupports.indent")

module.setup = function()
    return {
        requires = {
            "core.integrations.treesitter",
            "core.autocommands",
        },
    }
end

module.public = {
    indentexpr = function(buf, line, node)
        line = line or (vim.v.lnum - 1)
        node = node or module.required["core.integrations.treesitter"].get_first_node_on_line(buf, line)

        if not node then
            return 0
        end

        local indent_data = module.config.public.indents[node:type()] or module.config.public.indents._

        if not indent_data then
            return 0
        end

        local _, initial_indent = node:start()

        local indent = 0

        for _, modifier in ipairs(indent_data.modifiers or {}) do
            if module.config.public.modifiers[modifier] then
                local ret = module.config.public.modifiers[modifier](buf, node, line, initial_indent)

                if ret ~= 0 then
                    indent = ret
                end
            end
        end

        local line_len = (vim.api.nvim_buf_get_lines(buf, line, line + 1, true)[1] or ""):len()

        -- Ensure that the cursor is within the `norg` language
        local current_lang = vim.treesitter.get_parser(buf, "norg"):language_for_range({
            line,
            line_len,
            line,
            line_len,
        })

        -- If it isn't then fall back to `nvim-treesitter`'s indent instead.
        if current_lang:lang() ~= "norg" then
            -- If we're in a ranged tag then apart from providing nvim-treesitter indents also make sure
            -- to account for the indentation level of the tag itself.
            if node:type() == "ranged_tag_content" then
                local lnum = line
                local start = node:range()

                while lnum > start do
                    if vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]:match("^%s*$") then
                        lnum = lnum - 1
                    else
                        return vim.fn["nvim_treesitter#indent"]()
                    end
                end

                return module.required["core.integrations.treesitter"].get_node_range(node:parent()).column_start
                    + vim.fn["nvim_treesitter#indent"]()
            else
                return vim.fn["nvim_treesitter#indent"]()
            end
        end

        -- Indents can be a static value, so account for that here
        if type(indent_data.indent) == "number" then
            -- If the indent is -1 then let Neovim indent instead of us
            if indent_data.indent == -1 then
                return -1
            end

            return indent + indent_data.indent + (module.config.public.tweaks[node:type()] or 0)
        end

        local calculated_indent = indent_data.indent(buf, node, line, indent, initial_indent) or 0

        if calculated_indent == -1 then
            return -1
        end

        return indent + calculated_indent + (module.config.public.tweaks[node:type()] or 0)
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

        ["strong_paragraph_delimiter"] = {
            indent = function(buf, _, line)
                local node = module.required["core.integrations.treesitter"].get_first_node_on_line(
                    buf,
                    vim.fn.prevnonblank(line) - 1
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
    tweaks = {},

    format_on_enter = true,
    format_on_escape = true,
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

        local indentkeys = "o,O,*<M-o>,*<M-O>"
            .. neorg.lib.when(module.config.public.format_on_enter, ",*<CR>", "")
            .. neorg.lib.when(module.config.public.format_on_escape, ",*<Esc>", "")
        vim.api.nvim_buf_set_option(event.buffer, "indentkeys", indentkeys)
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
    },
}

return module
