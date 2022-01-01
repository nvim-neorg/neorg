--[[
-- Indentation module for Neorg
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.esupports.indent")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
            "core.autocommands",
            "core.keybinds",
        },
    }
end

module.config.private = {
    heading_indent = {
        indent = function(node, get_range)
            return get_range(node:named_child(1)).column_start
        end,
    },

    generic_indent = {
        indent = function(node, get_range)
            return get_range(node).column_start
        end,
    },

    endpoints = {
        "heading%d+",
        "unordered_list%d+",
        "ordered_list%d+",
        "unordered_link%d+",
        "ordered_link%d+",
        "todo_item%d+",
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
        },
    },

    lookbacks = {
        heading1 = module.config.private.heading_indent,
        heading2 = module.config.private.heading_indent,
        heading3 = module.config.private.heading_indent,
        heading4 = module.config.private.heading_indent,
        heading5 = module.config.private.heading_indent,
        heading6 = module.config.private.heading_indent,

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
            end,
        },
    },
}

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufEnter")
    module.required["core.keybinds"].register_keybinds(module.name, { "indent" })
end

module.public = {
    indent_expr = function()
        local ts = module.required["core.integrations.treesitter"].get_ts_utils()
        local node = module.config.public.indents.extract(ts.get_node_at_cursor())

        if not node then
            -- Get the last treesitter node in the document
            local document_root = module.required["core.integrations.treesitter"].get_document_root()

            if not document_root then
                return 0
            end

            -- TODO: Error checks
            local function find_last(starting_node)
                if starting_node:named_child_count() == 0 then
                    return starting_node
                end

                return find_last(starting_node:named_child(starting_node:named_child_count() - 1))
            end

            local function up_until_endpoint(starting_node)
                while starting_node and starting_node:type() ~= "document" do
                    for _, endpoint in ipairs(module.config.private.endpoints) do
                        if starting_node:type():match(endpoint) then
                            return starting_node
                        end
                    end

                    starting_node = starting_node:parent()
                end

                return starting_node
            end

            node = up_until_endpoint(find_last(document_root))
        end

        if vim.api.nvim_get_current_line():match("^%s*$") then
            log.trace("Empty, use lookback only")
            return module.public.get_indent_for_lookback(node)
        else
            log.trace("Not empty, use regular indents")
            return module.public.get_in_place_indent(node)
        end
    end,

    get_indent_for_lookback = function(node)
        local indentor = module.config.public.lookbacks[node:type()]

        return indentor and indentor.indent(node, module.required["core.integrations.treesitter"].get_node_range)
            or module.config.private.generic_indent.indent(
                node,
                module.required["core.integrations.treesitter"].get_node_range
            )
    end,

    get_in_place_indent = function(node)
        if not node:parent() then
            return 0
        end

        -- NOTE: Currently only works when indenting something in visual line mode
        -- We'll have to differentiate between the different modes and indent
        -- accordingly
        return module.public.get_indent_for_lookback(node)
    end,
}

module.on_event = function(event)
    if event.type == "core.autocommands.events.bufenter" and event.content.norg then
        vim.opt_local.indentexpr = "v:lua.neorg.modules.get_module('" .. module.name .. "').indent_expr()"
    elseif event.split_type[2] == "core.norg.esupports.indent.indent" then
        local whitespace_length = event.line_content:match("^%s*"):len()

        if event.cursor_position[2] <= whitespace_length then
            vim.api.nvim_win_set_cursor(0, { event.cursor_position[1], whitespace_length })
        end

        vim.api.nvim_feedkeys("=", "n", false)
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
    },

    ["core.keybinds"] = {
        ["core.norg.esupports.indent.indent"] = true,
    },
}

return module
