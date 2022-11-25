--[[
    File: Treesitter-Integration
    Title: TreeSitter integration in Neorg
    Summary: A module designed to integrate TreeSitter into Neorg.
    ---
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.integrations.treesitter")

module.private = {
    ts_utils = nil,
    link_query = [[
                (link) @next-segment
                (anchor_declaration) @next-segment
                (anchor_definition) @next-segment
             ]],
    heading_query = [[
                 [
                     (heading1
                         title: (paragraph_segment) @next-segment
                     )
                     (heading2
                         title: (paragraph_segment) @next-segment
                     )
                     (heading3
                         title: (paragraph_segment) @next-segment
                     )
                     (heading4
                         title: (paragraph_segment) @next-segment
                     )
                     (heading5
                         title: (paragraph_segment) @next-segment
                     )
                     (heading6
                         title: (paragraph_segment) @next-segment
                     )
                 ]
             ]],
}

module.setup = function()
    return { success = true, requires = { "core.highlights", "core.mode", "core.keybinds", "core.neorgcmd" } }
end

module.load = function()
    local success, ts_utils = pcall(require, "nvim-treesitter.ts_utils")

    assert(success, "Unable to load nvim-treesitter.ts_utils :(")

    if module.config.public.configure_parsers then
        -- luacheck: push ignore

        local parser_configs = require("nvim-treesitter.parsers").get_parser_configs()

        parser_configs.norg = {
            install_info = module.config.public.parser_configs.norg,
        }

        parser_configs.norg_meta = {
            install_info = module.config.public.parser_configs.norg_meta,
        }

        module.required["core.neorgcmd"].add_commands_from_table({
            ["sync-parsers"] = {
                args = 0,
                name = "sync-parsers",
            },
        })

        -- luacheck: pop

        vim.api.nvim_create_autocmd("BufEnter", {
            pattern = "*.norg",
            once = true,
            callback = function()
                if vim.tbl_isempty(vim.api.nvim_get_runtime_file("parser/norg.so", false) or {}) then
                    if module.config.public.install_parsers then
                        require("nvim-treesitter.install").commands.TSInstallSync["run!"]("norg", "norg_meta")
                    else
                        assert(false, "Neorg's parser is not installed! Run `:Neorg sync-parsers` to install it.")
                    end
                end
            end,
        })
    end

    module.private.ts_utils = ts_utils

    module.required["core.mode"].add_mode("traverse-heading")
    module.required["core.keybinds"].register_keybinds(
        module.name,
        { "next.heading", "previous.heading", "next.link", "previous.link" }
    )
end

module.config.public = {
    --- If true will auto-configure the parsers to use the recommended setup.
    --  Sometimes `nvim-treesitter`'s repositories lag behind and this is the only good fix.
    configure_parsers = true,

    --- If true will automatically install parsers if they are not present.
    install_parsers = true,

    --- Configurations for each parser as expected by `nvim-treesitter`.
    --  If you want to tweak your parser configs you can do so here.
    parser_configs = {
        norg = {
            url = "https://github.com/nvim-neorg/tree-sitter-norg",
            files = { "src/parser.c", "src/scanner.cc" },
            branch = "main",
            revision = "5d9c76b5c9927955f7c5d5d946397584e307f69f",
        },
        norg_meta = {
            url = "https://github.com/nvim-neorg/tree-sitter-norg-meta",
            files = { "src/parser.c" },
            branch = "main",
            revision = "e93dcbc56a472649547cfc288f10ae4a93ef8795",
        },
    },
}

---@class core.integrations.treesitter
module.public = {
    --- Gives back an instance of `nvim-treesitter.ts_utils`
    ---@return table #`nvim-treesitter.ts_utils`
    get_ts_utils = function()
        return module.private.ts_utils
    end,

    --- Jumps to the next match of a query in the current buffer
    ---@param query_string string Query with `@next-segment` captures
    goto_next_query_match = function(query_string)
        local cursor = vim.api.nvim_win_get_cursor(0)
        local line_number, col_number = cursor[1], cursor[2]

        local document_root = module.public.get_document_root(0)

        if not document_root then
            return
        end
        local next_match_query = vim.treesitter.parse_query("norg", query_string)
        for id, node in next_match_query:iter_captures(document_root, 0, line_number - 1, -1) do
            if next_match_query.captures[id] == "next-segment" then
                local start_line, start_col = node:range()
                -- start_line is 0-based; increment by one so we can compare it to the 1-based line_number
                start_line = start_line + 1

                -- Skip node if it's inside a closed fold
                if not vim.tbl_contains({ -1, start_line }, vim.fn.foldclosed(start_line)) then
                    goto continue
                end

                -- Find and go to the first matching node that starts after the current cursor position.
                if (start_line == line_number and start_col > col_number) or start_line > line_number then
                    module.private.ts_utils.goto_node(node)
                    return
                end
            end

            ::continue::
        end
    end,

    --- Jumps to the previous match of a query in the current buffer
    ---@param query_string string Query with `@next-segment` captures
    goto_previous_query_match = function(query_string)
        local cursor = vim.api.nvim_win_get_cursor(0)
        local line_number, col_number = cursor[1], cursor[2]

        local document_root = module.public.get_document_root(0)

        if not document_root then
            return
        end
        local previous_match_query = vim.treesitter.parse_query("norg", query_string)
        local final_node = nil

        for id, node in previous_match_query:iter_captures(document_root, 0, 0, line_number) do
            if previous_match_query.captures[id] == "next-segment" then
                local start_line, _, _, end_col = node:range()
                -- start_line is 0-based; increment by one so we can compare it to the 1-based line_number
                start_line = start_line + 1

                -- Skip node if it's inside a closed fold
                if not vim.tbl_contains({ -1, start_line }, vim.fn.foldclosed(start_line)) then
                    goto continue
                end

                -- Find the last matching node that ends before the current cursor position.
                if start_line < line_number or (start_line == line_number and end_col < col_number) then
                    final_node = node
                end
            end

            ::continue::
        end
        if final_node then
            module.private.ts_utils.goto_node(final_node)
        end
    end,

    ---  Gets all nodes of a given type from the AST
    ---@param  type string #The type of node to filter out
    ---@param opts? table #A table of two options: `buf` and `ft`, for the buffer and format to use respectively.
    get_all_nodes = function(type, opts)
        local result = {}
        opts = opts or {}

        if not opts.buf then
            opts.buf = 0
        end

        if not opts.ft then
            opts.ft = "norg"
        end

        -- Do we need to go through each tree? lol
        vim.treesitter.get_parser(opts.buf, opts.ft):for_each_tree(function(tree)
            -- Get the root for that tree
            local root = tree:root()

            --- Recursively searches for a node of a given type
            ---@param node userdata #The starting point for the search
            local function descend(node)
                -- Iterate over all children of the node and try to match their type
                for child, _ in node:iter_children() do
                    if child:type() == type then
                        table.insert(result, child)
                    else
                        -- If no match is found try descending further down the syntax tree
                        for _, child_node in ipairs(descend(child) or {}) do
                            table.insert(result, child_node)
                        end
                    end
                end
            end

            descend(root)
        end)

        return result
    end,

    --- Executes function callback on each child node of the root
    ---@param callback function
    ---@param ts_tree #Optional syntax tree
    tree_map = function(callback, ts_tree)
        local tree = ts_tree or vim.treesitter.get_parser(0, "norg"):parse()[1]

        local root = tree:root()

        for child, _ in root:iter_children() do
            callback(child)
        end
    end,

    --- Executes callback on each child recursive
    ---@param callback function Executes with each node as parameter, can return false to stop recursion
    ---@param ts_tree #Optional syntax tree
    tree_map_rec = function(callback, ts_tree)
        local tree = ts_tree or vim.treesitter.get_parser(0, "norg"):parse()[1]

        local root = tree:root()

        local function descend(start)
            for child, _ in start:iter_children() do
                local stop_descending = callback(child)
                if not stop_descending then
                    descend(child)
                end
            end
        end

        descend(root)
    end,

    get_node_text = function(node, source)
        source = source or 0

        local start_row, start_col = node:start()
        local end_row, end_col = node:end_()

        local eof_row = vim.api.nvim_buf_line_count(source)

        if end_row >= eof_row then
            end_row = eof_row - 1
            end_col = -1
        end

        if start_row >= eof_row then
            return nil
        end

        local lines = vim.api.nvim_buf_get_text(source, start_row, start_col, end_row, end_col, {})

        return table.concat(lines, "\n")
    end,

    --- Returns the first node of given type if present
    ---@param type string #The type of node to search for
    ---@param buf number #The buffer to search in
    ---@param parent userdata #The node to start searching in
    get_first_node = function(type, buf, parent)
        if not buf then
            buf = 0
        end

        local function iterate(parent_node)
            for child, _ in parent_node:iter_children() do
                if child:type() == type then
                    return child
                end
            end
        end

        if parent then
            return iterate(parent)
        end

        vim.treesitter.get_parser(buf, "norg"):for_each_tree(function(tree)
            -- Iterate over all top-level children and attempt to find a match
            return iterate(tree:root())
        end)
    end,

    --- Recursively attempts to locate a node of a given type
    ---@param type string #The type of node to look for
    ---@param opts table #A table of two options: `buf` and `ft`, for the buffer and format respectively
    ---@return
    get_first_node_recursive = function(type, opts)
        opts = opts or {}
        local result

        if not opts.buf then
            opts.buf = 0
        end

        if not opts.ft then
            opts.ft = "norg"
        end

        -- Do we need to go through each tree? lol
        vim.treesitter.get_parser(opts.buf, opts.ft):for_each_tree(function(tree)
            -- Get the root for that tree
            local root
            if opts.parent then
                root = opts.parent
            else
                root = tree:root()
            end

            --- Recursively searches for a node of a given type
            ---@param node userdata #The starting point for the search
            local function descend(node)
                -- Iterate over all children of the node and try to match their type
                for child, _ in node:iter_children() do
                    if child:type() == type then
                        return child
                    else
                        -- If no match is found try descending further down the syntax tree
                        local descent = descend(child)
                        if descent then
                            return descent
                        end
                    end
                end

                return nil
            end

            result = result or descend(root)
        end)

        return result
    end,

    --- Given a node this function will break down the AST elements and return the corresponding text for certain nodes
    -- @Param  tag_node (userdata/treesitter node) - a node of type tag/carryover_tag
    get_tag_info = function(tag_node, check_parent)
        if not tag_node or (tag_node:type() ~= "ranged_tag" and tag_node:type() ~= "carryover_tag") then
            return nil
        end

        local start_row, start_column, end_row, end_column = tag_node:range()

        local attributes = {}
        local resulting_name, params, content = {}, {}, {}
        local content_start_column = 0

        if check_parent == true or check_parent == nil then
            local parent = tag_node:parent()

            if parent:type() == "carryover_tag_set" then
                for child in parent:iter_children() do
                    if child:type() == "carryover_tag" then
                        local meta = module.public.get_tag_info(child, false)

                        if
                            vim.tbl_isempty(vim.tbl_filter(function(attribute)
                                return attribute.name == meta.name
                            end, attributes))
                        then
                            table.insert(attributes, meta)
                        else
                            log.warn(
                                "Two carryover tags with the same name detected, the top level tag will take precedence"
                            )
                        end
                    end
                end
            end
        end

        -- Iterate over all children of the tag node
        for child, _ in tag_node:iter_children() do
            -- If we're dealing with the tag name then append the text of the tag_name node to this table
            if child:type() == "tag_name" then
                table.insert(resulting_name, vim.split(module.public.get_node_text(child), "\n")[1])
            elseif child:type() == "tag_parameters" then
                table.insert(params, vim.split(module.public.get_node_text(child), "\n")[1])
            elseif child:type() == "ranged_tag_content" then
                -- If we're dealing with tag content then retrieve that content
                content = vim.split(module.public.get_node_text(child), "\n")
                _, content_start_column = child:range()
            end
        end

        for i, line in ipairs(content) do
            if i == 1 then
                if content_start_column < start_column then
                    log.error(
                        string.format(
                            "Unable to query information about tag on line %d: content is indented less than tag start!",
                            start_row + 1
                        )
                    )
                    return nil
                end
                content[i] = string.rep(" ", content_start_column - start_column) .. line
            else
                content[i] = line:sub(1 + start_column)
            end
        end

        content[#content] = nil

        return {
            name = table.concat(resulting_name, "."),
            parameters = params,
            content = content,
            attributes = vim.fn.reverse(attributes),
            start = { row = start_row, column = start_column },
            ["end"] = { row = end_row, column = end_column },
        }
    end,

    --- Gets the range of a given node
    ---@param node userdata #The node to get the range of
    ---@return table #A table of `row_start`, `column_start`, `row_end` and `column_end` values
    get_node_range = function(node)
        if not node then
            return {
                row_start = 0,
                column_start = 0,
                row_end = 0,
                column_end = 0,
            }
        end

        local rs, cs, re, ce = neorg.lib.when(type(node) == "table", function()
            local brs, bcs, _, _ = node[1]:range()
            local _, _, ere, ece = node[#node]:range()
            return brs, bcs, ere, ece
        end, function()
            local a, b, c, d = node:range()
            return a, b, c, d
        end)

        return {
            row_start = rs,
            column_start = cs,
            row_end = re,
            column_end = ce,
        }
    end,

    --- Extracts the document root from the current document or from the string
    ---@param src number|string The number of the buffer to extract or string with code (can be nil)
    ---@param filetype The filetype of the buffer or the string with code
    ---@return userdata #The root node of the document
    get_document_root = function(src, filetype)
        filetype = filetype or "norg"

        local parser
        if type(src) == "string" then
            parser = vim.treesitter.get_string_parser(src, filetype)
        else
            parser = vim.treesitter.get_parser(src or 0, filetype)
        end

        local tree = parser:parse()[1]

        if not tree or not tree:root() or tree:root():type() == "ERROR" then
            log.warn("Unable to parse the current document's syntax tree :(")
            return
        end

        return tree:root()
    end,

    --- Attempts to find a parent of a node recursively
    ---@param node userdata #The node to start at
    ---@param types table|string #If `types` is a table, this function will attempt to match any of the types present in the table.
    -- If the type is a string, the function will attempt to pattern match the `types` value with the node type.
    find_parent = function(node, types)
        local _node = node

        while _node do
            if type(types) == "string" then
                if _node:type():match(types) then
                    return _node
                end
            elseif vim.tbl_contains(types, _node:type()) then
                return _node
            end

            _node = _node:parent()
        end
    end,

    --- Retrieves the first node at a specific line
    ---@param buf number #The buffer to search in (0 for current)
    ---@param line number #The line number (0-indexed) to get the node from
    -- the same line as `line`.
    ---@param string|table? #Don't recurse to the provided type(s)
    ---@return userdata|nil #The first node on `line`
    get_first_node_on_line = function(buf, line, stop_type)
        if type(stop_type) == "string" then
            stop_type = { stop_type }
        end

        local document_root = module.public.get_document_root(buf)

        if not document_root then
            return
        end

        local first_char = (vim.api.nvim_buf_get_lines(buf, line, line + 1, true)[1] or ""):match("^(%s+)[^%s]")
        first_char = first_char and first_char:len() or 0

        local descendant = document_root:descendant_for_range(line, first_char, line, first_char + 1)

        if not descendant then
            return
        end

        while
            descendant:parent()
            and (descendant:parent():start()) == line
            and descendant:parent():symbol() ~= document_root:symbol()
        do
            local parent = descendant:parent()

            if parent and stop_type and vim.tbl_contains(stop_type, parent:type()) then
                break
            end

            descendant = parent
        end

        return descendant
    end,

    get_document_metadata = function(buf, no_trim)
        buf = buf or 0

        local languagetree = vim.treesitter.get_parser(buf, "norg")

        if not languagetree then
            return
        end

        local result = {}

        languagetree:for_each_child(function(tree)
            if tree:lang() ~= "norg_meta" then
                return
            end

            local meta_language_tree = tree:parse()[1]

            if not meta_language_tree then
                return
            end

            local query = vim.treesitter.parse_query(
                "norg_meta",
                [[
                (metadata
                    (pair
                        (key) @key
                    )
                )
            ]]
            )

            local function trim(value)
                return no_trim and value or vim.trim(value)
            end

            local function parse_data(node)
                return neorg.lib.match(node:type())({
                    value = function()
                        return trim(module.public.get_node_text(node, buf))
                    end,
                    array = function()
                        local resulting_array = {}

                        for child in node:iter_children() do
                            if child:named() then
                                local parsed_data = parse_data(child)

                                if parsed_data then
                                    table.insert(resulting_array, parsed_data)
                                end
                            end
                        end

                        return resulting_array
                    end,
                    object = function()
                        local resulting_object = {}

                        for child in node:iter_children() do
                            if not child:named() or child:type() ~= "pair" then
                                goto continue
                            end

                            local key = child:named_child(0)
                            local value = child:named_child(1)

                            if not key then
                                goto continue
                            end

                            local key_content = trim(module.public.get_node_text(key, buf))

                            resulting_object[key_content] = (value and parse_data(value) or vim.NIL)

                            ::continue::
                        end

                        return resulting_object
                    end,
                })
            end

            for id, node in query:iter_captures(meta_language_tree:root(), buf) do
                if query.captures[id] == "key" then
                    local key_content = trim(module.public.get_node_text(node, buf))

                    result[key_content] = (
                        node:next_named_sibling() and parse_data(node:next_named_sibling()) or vim.NIL
                    )
                end
            end
        end)

        return result
    end,
}

module.on_event = function(event)
    if event.split_type[1] == "core.keybinds" then
        if event.split_type[2] == "core.integrations.treesitter.next.heading" then
            module.public.goto_next_query_match(module.private.heading_query)
        elseif event.split_type[2] == "core.integrations.treesitter.previous.heading" then
            module.public.goto_previous_query_match(module.private.heading_query)
        elseif event.split_type[2] == "core.integrations.treesitter.next.link" then
            module.public.goto_next_query_match(module.private.link_query)
        elseif event.split_type[2] == "core.integrations.treesitter.previous.link" then
            module.public.goto_previous_query_match(module.private.link_query)
        end
    elseif event.split_type[2] == "sync-parsers" then
        local ok = pcall(vim.cmd, "TSInstall! norg")

        if not ok then
            vim.notify([[Unable to install norg parser.
]])
        end

        pcall(vim.cmd, "TSInstall! norg_meta")
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.integrations.treesitter.next.heading"] = true,
        ["core.integrations.treesitter.previous.heading"] = true,
        ["core.integrations.treesitter.next.link"] = true,
        ["core.integrations.treesitter.previous.link"] = true,
    },

    ["core.neorgcmd"] = {
        ["sync-parsers"] = true,
    },
}

return module
