--[[
    File: Esupports-Hop
    Title: Jump from Neorg links
    Summary: "Hop" between Neorg links, following them with a single keypress.
--]]

require("neorg.modules.base")
require("neorg.external.helpers")

local module = neorg.modules.create("core.norg.esupports.hop")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.keybinds",
            "core.integrations.treesitter",
            "core.ui",
            "core.norg.dirman",
        },
    }
end

module.load = function()
    module.required["core.keybinds"].register_keybind(module.name, "hop-link")
end

module.config.public = {
    lookahead = true,
    fuzzing_threshold = 0.5,
}

module.public = {
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

            local capture_node_range = module.required["core.integrations.treesitter"].get_node_range(node)

            -- Check whether the node captured node is in bounds.
            -- There are certain rare cases where incorrect nodes would be parsed.
            if
                capture_node_range.row_start >= range.row_start
                and capture_node_range.row_end <= capture_node_range.row_end
                and capture_node_range.column_start >= range.column_start
                and capture_node_range.column_end <= range.column_end
            then
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
}

module.private = {
    --- Damerau-levenstein implementation
    calculate_similarity = function(lhs, rhs)
        -- https://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance
        local str1 = lhs
        local str2 = rhs
        local matrix = {}
        local cost

        -- build matrix
        for i = 0, #str1 do
            matrix[i] = {}
            matrix[i][0] = i
        end

        for j = 0, #str2 do
            matrix[0][j] = j
        end

        for j = 1, #str2 do
            for i = 1, #str1 do
                if str1:sub(i, i) == str2:sub(j, j) then
                    cost = 0
                else
                    cost = 1
                end
                matrix[i][j] = math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost)
                if
                    i > 1
                    and j > 1
                    and str1:sub(i, i) == str2:sub(j - 1, j - 1)
                    and str1:sub(i - 1, i - 1) == str2:sub(j, j)
                then
                    matrix[i][j] = math.min(matrix[i][j], matrix[i - 2][j - 2] + cost)
                end
            end
        end

        return matrix[#str1][#str2]
            / (
                (#str1 + #str2)
                + (function()
                    local index = 1
                    local ret = 0

                    while index < #str1 do
                        if str1:sub(index, index):lower() == str2:sub(index, index):lower() then
                            ret = ret + 0.2
                        end

                        index = index + 1
                    end

                    return ret
                end)()
            )
    end,

    fix_link_loose = function(parsed_link_information)
        local generic_query = [[
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
        ]]

        return module.private.fix_link(parsed_link_information, generic_query)
    end,

    fix_link_strict = function(parsed_link_information)
        local query = neorg.lib.when(
            parsed_link_information.link_type == "generic",
            [[
                (carryover_tag_set
                    (carryover_tag
                        name: (tag_name) @tag_name
                        (tag_parameters) @title
                        (#eq? @tag_name "name")
                        (#set! "type" "generic")
                    )
                )?
                (_
                    title: (paragraph_segment) @title
                )?
            ]],
            string.format(
                [[
                    (carryover_tag_set
                        (carryover_tag
                            name: (tag_name) @tag_name
                            (tag_parameters) @title
                            (#eq? @tag_name "name")
                            (#set! "type" "generic")
                        )
                    )?
                    (%s
                        (%s_prefix)
                        title: (paragraph_segment) @title
                    )?
                ]],
                neorg.lib.reparg(parsed_link_information.link_type, 2)
            )
        )

        return module.private.fix_link(parsed_link_information, query)
    end,

    fix_link = function(parsed_link_information, query_str)
        local buffer = vim.api.nvim_get_current_buf()

        if parsed_link_information.link_file_text then
            local expanded_link_text = module.required["core.norg.dirman"].expand_path(
                parsed_link_information.link_file_text
            )

            if expanded_link_text ~= vim.fn.expand("%:p") then
                -- We are dealing with a foreign file
                buffer = vim.uri_to_bufnr("file://" .. expanded_link_text)
            end
        end

        local query = vim.treesitter.parse_query("norg", query_str)

        local document_root = module.required["core.integrations.treesitter"].get_document_root(buffer)

        if not document_root then
            return
        end

        local similarities = {
            -- Example: { 0.6, "title", node }
        }

        for id, node in query:iter_captures(document_root, buffer) do
            local capture_name = query.captures[id]

            if capture_name == "title" then
                local text = module.required["core.integrations.treesitter"].get_node_text(node, buffer)
                local similarity = module.private.calculate_similarity(parsed_link_information.link_location_text, text)

                -- If our match is similar enough then add it to the list
                if similarity < module.config.public.fuzzing_threshold then
                    table.insert(similarities, { similarity = similarity, text = text, node = node:parent() })
                end
            end
        end

        if vim.tbl_isempty(similarities) then
            vim.notify("Sorry, Neorg couldn't fix that link :(")
        end

        table.sort(similarities, function(lhs, rhs)
            return lhs.similarity < rhs.similarity
        end)

        return similarities
    end,

    write_fixed_link = function(link_node, parsed_link_information, similarities, force_type)
        local most_similar = similarities[1]

        if not link_node or not most_similar then
            return
        end

        local range = module.required["core.integrations.treesitter"].get_node_range(link_node)

        local prefix = neorg.lib.when(
            parsed_link_information.link_type == "generic" and not force_type,
            "#",
            neorg.lib.match({
                most_similar.node:type(),

                heading1 = "*",
                heading2 = "**",
                heading3 = "***",
                heading4 = "****",
                heading5 = "*****",
                heading6 = "******",
                marker = "|",
                -- single_definition = "$",
                -- multi_definition = "$",
                default = "#",
            })
        ) .. " "

        local function callback(replace)
            vim.api.nvim_buf_set_text(
                0,
                range.row_start,
                range.column_start,
                range.row_end,
                range.column_end,
                { replace }
            )
        end

        callback(
            "{"
                .. neorg.lib.when(
                    parsed_link_information.link_file_text,
                    neorg.lib.lazy_string_concat(":", parsed_link_information.link_file_text, ":"),
                    ""
                )
                .. prefix
                .. most_similar.text
                .. "}"
                .. neorg.lib.when(
                    parsed_link_information.link_description,
                    neorg.lib.lazy_string_concat("[", parsed_link_information.link_description, "]"),
                    ""
                )
        )
    end,
}

module.on_event = function(event)
    if event.split_type[2] == "core.norg.esupports.hop.hop-link" then
        local link_node_at_cursor = module.public.extract_link_node()

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
            if event.content[1] then
                if event.content[1] == "vsplit" then
                    vim.cmd("vsplit")
                elseif event.content[1] == "split" then
                    vim.cmd("split")
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
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.norg.esupports.hop.hop-link"] = true,
    },
}

return module
