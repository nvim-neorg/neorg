require("neorg.modules.base")

local module = neorg.modules.create("core.norg.qol.toc")

module.setup = function()
    return { success = true, requires = { "core.integrations.treesitter", "core.ui", "core.keybinds","core.mode"} }
end

module.load = function()
    module.required["core.keybinds"].register_keybind(module.name, "hop-toc-link")
end

module.public = {
    follow_link_toc = function(split,close_toc_split)
        print("mapping executed")
        local previous_mode = module.required["core.mode"].get_previous_mode()
        module.required["core.mode"].set_mode(previous_mode)
        if true then return end

        vim.fn.feedkeys("$", "n")
        local link_node_at_cursor = module.public.extract_link_node()
        vim.cmd("close")

        if not link_node_at_cursor then
            log.trace("No link under cursor.")
            return
        end

        if link_node_at_cursor:type() == "anchor_declaration" then
            local located_anchor_declaration = module.public.locate_anchor_declaration_target(link_node_at_cursor)

            if not located_anchor_declaration then
                return
            end

            local range = module.required["core.integrations.treesitter"].get_node_range(
                located_anchor_declaration.node
            )

            vim.api.nvim_win_set_cursor(0, { range.row_start + 1, range.column_start })
            return
        end

        local parsed_link = module.public.parse_link(link_node_at_cursor)


        if not parsed_link then
            return
        end

        local located_link_information = module.public.locate_link_target(parsed_link)

        if located_link_information then
            if close_toc_split then
                if split then
                    if split == "vsplit" then
                        vim.cmd("vsplit")
                    elseif split == "split" then
                        vim.cmd("split")
                    end
                end
            end

            if not vim.tbl_isempty(located_link_information) then
                if located_link_information.buffer ~= vim.api.nvim_get_current_buf() then
                    vim.api.nvim_buf_set_option(located_link_information.buffer, "buflisted", true)
                    vim.api.nvim_set_current_buf(located_link_information.buffer)
                end

                if not located_link_information.node then
                    return
                end

                local range = module.required["core.integrations.treesitter"].get_node_range(
                    located_link_information.node
                )

                vim.api.nvim_win_set_cursor(0, { range.row_start + 1, range.column_start })
            end

            return
        end

        local selection = module.required["core.ui"].begin_selection(
            module.required["core.ui"].create_split("link-not-found")
        )
            :listener("delete-buffer", {
                "<Esc>",
            }, function(self)
                    self:destroy()
                end)
            :apply({
                warning = function(self, text)
                    return self:text("WARNING: " .. text, "TSWarning")
                end,
                desc = function(self, text)
                    return self:text(text, "TSComment")
                end,
            })

        selection
        :title("Link not found - what do we do now?")
        :blank()
        :text("There are a few actions that you can perform whenever a link cannot be located.", "Normal")
        :text("Press one of the available keys to perform your desired action.")
        :blank()
        :desc("The most common action will be to try and fix the link.")
        :desc("Fixing the link will perform a fuzzy search on every item of the same type in the file")
        :desc("and make the link point to the closest match:")
        :flag("f", "Attempt to fix the link", function()
            local similarities = module.private.fix_link_strict(parsed_link)

            if not similarities or vim.tbl_isempty(similarities) then
                return
            end

            module.private.write_fixed_link(link_node_at_cursor, parsed_link, similarities)
        end)
        :blank()
        :desc("Does the same as the above keybind, however doesn't limit matches to those")
        :desc("defined by the link type. This means that even if the link points to a level 1")
        :desc("heading this fixing algorithm will be able to match any other item type:")
        :flag("F", "Attempt to fix the link (loose fuzzing)", function()
            local similarities = module.private.fix_link_loose(parsed_link)

            if not similarities or vim.tbl_isempty(similarities) then
                return
            end

            module.private.write_fixed_link(link_node_at_cursor, parsed_link, similarities, true)
        end)
        :blank()
        :warning("The below flags currently do not work, this is a beta build.")
        :desc("Instead of fixing the link you may actually want to create the target:")
        :flag("a", "Place target above current link parent")
        :flag("b", "Place target below current link parent")
    end,

    extract_link_node = function()
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        if not ts_utils then
            return
        end

        local current_node = ts_utils.get_node_at_cursor()
        local found_node = module.required["core.integrations.treesitter"].find_parent(
            current_node,
            { "link", "anchor_declaration", "anchor_definition" }
        )

        if not found_node then
            found_node = (module.config.public.lookahead and module.public.lookahead_link_node())
        end

        if found_node then
            if found_node:parent():type() == "anchor_definition" then
                return found_node:parent()
            end

            return found_node
        end
    end,

    lookahead_link_node = function()
        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

        local line = vim.api.nvim_get_current_line()
        local current_cursor_pos = vim.api.nvim_win_get_cursor(0)
        local current_line = current_cursor_pos[1]
        local index = current_cursor_pos[2]
        local resulting_node

        while not resulting_node do
            local next_square_bracket = line:find("%[", index)
            local next_curly_bracket = line:find("{", index)
            local smaller_value

            if not next_square_bracket and not next_curly_bracket then
                return
            elseif not next_square_bracket and next_curly_bracket then
                smaller_value = next_curly_bracket
            elseif next_square_bracket and not next_curly_bracket then
                smaller_value = next_square_bracket
            else
                smaller_value = (next_square_bracket < next_curly_bracket and next_square_bracket or next_curly_bracket)
            end

            vim.api.nvim_win_set_cursor(0, {
                current_line,
                smaller_value - 1,
            })

            local node_under_cursor = ts_utils.get_node_at_cursor()

            resulting_node = neorg.lib.match({
                node_under_cursor:type(),
                link = node_under_cursor,
                anchor_declaration = node_under_cursor,
            })

            index = index + 1
        end

        return resulting_node
    end,

    locate_anchor_declaration_target = function(anchor_decl_node)
        local target =
            module.required["core.integrations.treesitter"].get_node_text(
                anchor_decl_node:named_child(0)
            ):gsub("[%s\\]", "")

        local query_str = [[
        (anchor_definition
        (anchor_declaration
        text: (anchor_declaration_text) @text
        )
        )
        ]]

        local document_root = module.required["core.integrations.treesitter"].get_document_root()
        local query = vim.treesitter.parse_query("norg", query_str)

        for id, node in query:iter_captures(document_root, 0) do
            local capture = query.captures[id]

            if capture == "text" then
                local original_title = module.required["core.integrations.treesitter"].get_node_text(node)
                local title = original_title:gsub("[%s\\]", "")

                if title == target then
                    return {
                        original_title = original_title,
                        node = node,
                    }
                end
            end
        end
    end,

    parse_link = function(link_node)
        if not link_node or not vim.tbl_contains({ "link", "anchor_definition" }, link_node:type()) then
            return
        end

        local query_text = [[
        [
        (link
        (link_file
        location: (link_file_text) @link_file_text
        )?
        (link_location
        type: [
        (link_location_url)
        (link_location_generic)
        (link_location_external_file)
        (link_location_marker)
        (link_location_heading1)
        (link_location_heading2)
        (link_location_heading3)
        (link_location_heading4)
        (link_location_heading5)
        (link_location_heading6)
        ] @link_type
        text: (link_location_text) @link_location_text
        )?
        (link_description
        text: (link_text) @link_description
        )?
        )
        (anchor_definition
        (anchor_declaration
        text: (anchor_declaration_text)
        )
        (link_file
        location: (link_file_text) @link_file_text
        )?
        (link_location
        type: [
        (link_location_url)
        (link_location_generic)
        (link_location_external_file)
        (link_location_marker)
        (link_location_heading1)
        (link_location_heading2)
        (link_location_heading3)
        (link_location_heading4)
        (link_location_heading5)
        (link_location_heading6)
        ] @link_type
        text: (link_location_text) @link_location_text
        )
        )
        ]
        ]]

        local document_root = module.required["core.integrations.treesitter"].get_document_root()

        if not document_root then
            return
        end

        local query = vim.treesitter.parse_query("norg", query_text)
        local range = module.required["core.integrations.treesitter"].get_node_range(link_node)

        local parsed_link_information = {}

        for id, node in query:iter_captures(document_root, 0, range.row_start, range.row_end + 1) do
            local capture = query.captures[id]

            local extract_node_text = neorg.lib.wrap(
                module.required["core.integrations.treesitter"].get_node_text,
                node
            )

            parsed_link_information[capture] = parsed_link_information[capture]
                or neorg.lib.match({
                    capture,
                    link_file_text = extract_node_text,
                    link_type = neorg.lib.wrap(string.sub, node:type(), string.len("link_location_") + 1),
                    link_location_text = extract_node_text,
                    link_description = extract_node_text,

                    default = function()
                        log.error("Unknown capture type encountered when parsing link:", capture)
                    end,
                })
        end

        return parsed_link_information
    end,

    locate_link_target = function(parsed_link_information)
        --- A pointer to the target buffer we will be parsing.
        -- This may change depending on the target file the user gave.
        local buf_pointer = vim.api.nvim_get_current_buf()

        -- Check whether our target is from a different file
        if parsed_link_information.link_file_text then
            local expanded_link_text = module.required["core.norg.dirman"].expand_path(
                parsed_link_information.link_file_text
            )

            if expanded_link_text ~= vim.fn.expand("%:p") then
                -- We are dealing with a foreign file
                buf_pointer = vim.uri_to_bufnr("file://" .. expanded_link_text)
            end

            if not parsed_link_information.link_type then
                return {
                    original_title = nil,
                    node = nil,
                    buffer = buf_pointer,
                }
            end
        end

        return neorg.lib.match({
            parsed_link_information.link_type,

            url = function()
                local destination = parsed_link_information.link_location_text

                if neorg.configuration.os_info == "linux" then
                    vim.cmd('silent !xdg-open "' .. vim.fn.fnameescape(destination) .. '"')
                elseif neorg.configuration.os_info == "mac" then
                    vim.cmd('silent !open "' .. vim.fn.fnameescape(destination) .. '"')
                else
                    vim.cmd('silent !start "' .. vim.fn.fnameescape(destination) .. '"')
                end

                return {}
            end,

            external_file = function()
                vim.cmd("e " .. vim.fn.fnameescape(parsed_link_information.link_location_text))
                return {}
            end,

            default = function()
                -- Dynamically forge query
                local query_str = neorg.lib.match({
                    parsed_link_information.link_type,
                    generic = [[
                    (carryover_tag_set
                    (carryover_tag
                    name: (tag_name) @tag_name
                    (tag_parameters) @title
                    (#eq? @tag_name "name")
                    )
                    )?
                    (_
                    title: (paragraph_segment) @title
                    )?
                    ]],

                    default = string.format(
                        [[
                        (carryover_tag_set
                        (carryover_tag
                        name: (tag_name) @tag_name
                        (tag_parameters) @title
                        (#eq? @tag_name "name")
                        )
                        )?
                        (%s
                        (%s_prefix)
                        title: (paragraph_segment) @title
                        )?
                        ]],
                        neorg.lib.reparg(parsed_link_information.link_type, 2)
                    ),
                })

                local document_root = module.required["core.integrations.treesitter"].get_document_root(buf_pointer)

                if not document_root then
                    return
                end

                local query = vim.treesitter.parse_query("norg", query_str)

                for id, node in query:iter_captures(document_root, buf_pointer) do
                    local capture = query.captures[id]

                    if capture == "title" then
                        local original_title = module.required["core.integrations.treesitter"].get_node_text(
                            node,
                            buf_pointer
                        )

                        if original_title then
                            local title = original_title:gsub("[%s\\]", "")
                            local target = parsed_link_information.link_location_text:gsub("[%s\\]", "")

                            if title == target then
                                return {
                                    original_title = original_title,
                                    node = node,
                                    buffer = buf_pointer,
                                }
                            end
                        end
                    end
                end
            end,
        })
    end,
    --- Find a Table of Contents insertions in the document and returns its data
    --- @return table A table that consist of two values: { item, parameters }.
    --- Parameters can be nil if no parameters to the insertion were given.
    find_toc = function()
        -- Extract any insertion that has a ToC value in it
        local query = vim.treesitter.parse_query(
            "norg",
            [[
            (insertion
            (insertion_prefix)
            item: (capitalized_word) @item
            parameters: (paragraph_segment)? @parameters
            (#match? @item "^[tT][oO][cC]$")
            )
            ]]
        )

        local exists = false
        local node_data = {
            item = nil,
            parameters = nil,
            line = nil,
        }

        -- The document root is required for iterating over query captures
        local root = module.required["core.integrations.treesitter"].get_document_root()

        if not root then
            return
        end

        -- All captures are looped over here
        for id, node in query:iter_captures(root, 0) do
            -- Extract the name of the capture from the captures table (this makes it easier to perform comparisons on)
            local capture = query.captures[id]

            -- If the capture name is "item" then we set the item variable inside of node_data
            -- It can also optionally be "parameters", in which case that variable will be set too
            node_data[capture] = node

            if node_data.line == nil then
                node_data.line = module.required["core.integrations.treesitter"].get_node_range(node).row_end
            end

            -- This is set to true to tell the program that we've encountered a node
            -- I don't think there's an easier way of doing this, as iter_captures returns a function,
            -- not a list of nodes. We can't simply check if that table of nodes is empty
            exists = true
        end

        if not exists then
            log.error(vim.trim([[
            Uh oh! We couldn't generate a Table of Contents because you didn't specify one in the document!
            You can do:
            = TOC <Optional custom name for the table of contents>
            Anywhere in your document. Doing so will cause the ToC to appear in that location during render.
            Type :messages to see full output
            ]]))
            return
        end

        return node_data
    end,

    --- Generates a Table Of Contents (doesn't display it)
    --- @param generator function the function to invoke for each node (used for building the toc)
    --- @param display_as_links boolean
    --- @return table a table of { text, highlight_group } pairs
    generate_toc = function(toc_data, generator, display_as_links)
        vim.validate({
            toc_data = { toc_data, "table" },
            generator = { generator, "function", true },
        })

        local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()
        local ts = module.required["core.integrations.treesitter"]

        -- Initialize the default generator if it can't be found
        generator = generator
            or function(node, get_text, state)
                local node_type = node:type()

                if vim.startswith(node_type, "heading") and not vim.endswith(node_type, "prefix") then
                    local heading_level = tonumber(node_type:sub(8, 8))

                    local function join_text(text)
                        local out = {}
                        for k, v in ipairs(text) do
                            -- TODO: figure out how to do this in a single gsub
                            -- (it's not as trivial as it seems because we must
                            -- avoid that `(.+)` greedily includes the trailing
                            -- modifier...)
                            v = v:gsub("^(.+)%~$", "%1")
                            v = v:gsub("^%s*(.+)$", "%1")
                            out[k] = v
                        end
                        return table.concat(out, " ")
                    end

                    local line, _, _ = node:start()
                    local heading_text_node = ts.get_first_node("paragraph_segment", 0, node)
                    local heading_text = ts_utils.get_node_text(heading_text_node, 0)

                    local prefix = string.rep(display_as_links and "-" or "*", heading_level)
                        .. (display_as_links and "> " or " ")
                    local text = prefix
                        .. (function()
                            if display_as_links then
                                return "{# " .. table.concat(heading_text, "") .. "}"
                            end
                            return join_text(heading_text)
                        end)()
                    return {
                        text = text,
                        highlight = "NeorgHeading" .. heading_level .. "Title",
                        level = heading_level,
                        state = state,
                        line = line + 1,
                    }
                end
            end

        local title = toc_data.parameters and ts.get_node_text(toc_data.parameters)
            or (display_as_links and "* " or "") .. "Table of Contents"
        local result = {
            {
                text = title,
                highlight = "TSAnnotation",
                level = 1,
            },
            {
                text = "",
            },
        }

        local root = module.required["core.integrations.treesitter"].get_document_root()

        if not root then
            return
        end

        local state = {}

        -- Recursively go through all nodes and run the generator on each one
        -- If the generator returns a valid value then store it in the result
        ts.tree_map_rec(function(node)
            local output = generator(node, ts.get_node_text, state)

            if output then
                state = output.state
                table.insert(result, output)
            end
        end)

        return result
    end,

    --- Displays the table of contents to the user
    --- @param split boolean if true will spawn the vertical split on the right hand side
    display_toc = function(split)
        local found_toc = module.public.find_toc()

        if not found_toc then
            return
        end

        local generated_toc = module.public.generate_toc(found_toc, nil, split)

        if not generated_toc then
            return
        end

        local virt_lines = {}
        for _, element in ipairs(generated_toc) do
            table.insert(virt_lines, { { element.text, element.highlight } })
        end

        if split then
            local buf = module.required["core.ui"].create_norg_buffer("Neorg Toc", "vsplitl")
            module.required["core.mode"].set_mode("toc-split")

            local filter = function(a)
                return a.text
            end

            local size = math.floor(vim.api.nvim_win_get_width(0) / 3)
            vim.api.nvim_win_set_width(0, size)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.tbl_map(filter, generated_toc))
            -- vim.api.nvim_buf_set_option(buf, "modifiable", false)

            vim.cmd(string.format([[echom '%s']], "Press <ESC> or q to exit"))
            return
        end

        local namespace = vim.api.nvim_create_namespace("Neorg ToC")
        local extmarks = vim.api.nvim_buf_get_extmarks(0,namespace,0,-1,{})
        if #extmarks == 0 then
            vim.api.nvim_buf_set_extmark(0, namespace, found_toc.line, 0, { virt_lines = virt_lines })
        else
            vim.api.nvim_win_set_cursor(0, {found_toc.line+1,0})
            return
        end
    end,

    --- Populates the quickfix list with the table of contents
    --- @param loclist boolean if true, uses the location list instead of the quickfix one
    toqflist = function(loclist)
        local found_toc = module.public.find_toc()

        if not found_toc then
            return
        end

        local generated_toc = module.public.generate_toc(found_toc)

        if not generated_toc then
            return
        end

        local bufnr = vim.api.nvim_win_get_buf(0)

        local qflist = {}
        for num, element in ipairs(generated_toc) do
            if num > 2 then
                table.insert(qflist, {
                    bufnr = bufnr,
                    lnum = element.line,
                    text = element.text,
                })
            end
        end

        if loclist == true then
            vim.fn.setloclist(0, qflist, "r")
        else
            vim.fn.setqflist(qflist, "r")
        end
    end,
}

module.on_event = function(event)
    if event.split_type[2] == "core.norg.qol.toc.hop-toc-link" then
        module.public.follow_link_toc(event.content[1])
        -- print("keybinding executed")
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.norg.qol.toc.hop-toc-link"] = true,
    },
}

return module
