--[[
-- Indentation module for Neorg
--]]

require('neorg.modules.base')

local module = neorg.modules.create("core.norg.esupports.indent")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
            "core.autocommands"
        }
    }
end

module.config.private = {
    generic_indent = {
        indent = function(node, get_range)
            return get_range(node:named_child(1)).column_start
        end,
    },
}

module.config.public = {
    indents = {
        extract = function(node)
            if not node or node:type() == "document" then
                return
            end

            local destinations = {
                "quote",
                "heading",
                "carryover_tag",
                "unordered_list",
                "ordered_list",
                "todo_item",
                "unordered_link",
                "ordered_link",
            }

            local exclude_suffixes = {
                "prefix",
            }

            local function check_all()
                for _, destination in ipairs(destinations) do
                    for _, suffix in ipairs(exclude_suffixes) do
                        if not vim.endswith(node:type(), suffix) and vim.startswith(node:type(), destination) then
                            return node
                        end
                    end
                end
            end

            while not check_all() do
                if node:type() == "document" then
                    return node
                end

                node = node:parent()
            end

            return node
        end,

        heading1 = {
            -- TODO
        }
    },

    lookbacks = {
        heading1 = module.config.private.generic_indent,
        heading2 = module.config.private.generic_indent,
        heading3 = module.config.private.generic_indent,
        heading4 = module.config.private.generic_indent,
        heading5 = module.config.private.generic_indent,
        heading6 = module.config.private.generic_indent,

        paragraph = {
            indent = function(node, get_range)
                return get_range(node).column_start
            end
        },

        weak_paragraph_delimiter = {
            indent = function(node, get_range)
                if node:parent() then
                    return get_range(node).column_start
                end

                return 0
            end,
        },

        strong_paragraph_delimiter = {
            indent = function()
                return 0
            end
        }
    }
}

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufEnter")
end

module.public = {
    indent_expr = function()
        vim.api.nvim_win_set_cursor(0, vim.api.nvim_win_get_cursor(0))

        local ts = module.required["core.integrations.treesitter"].get_ts_utils()
        local current_node = module.config.public.indents.extract(ts.get_node_at_cursor())

        if not current_node then
            return 0
        end

        if vim.api.nvim_get_current_line():match("^%s*$") then
            log.trace("Empty, use lookback only")
            return module.public.get_indent_for_lookback(current_node)
        else
            log.trace("Not empty, use regular indents")
            return 4
        end
    end,

    get_indent_for_lookback = function(node)
        local indentor = module.config.public.lookbacks[node:type()]

        return indentor and indentor.indent(node, module.required["core.integrations.treesitter"].get_node_range) or 0
    end,
}

module.on_event = function(event)
    if event.type == "core.autocommands.events.bufenter" and event.content.norg then
        vim.opt_local.indentexpr = "v:lua.neorg.modules.get_module('" .. module.name .. "').indent_expr()"
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true
    }
}

return module
