--[[
    file: Esupports-Hop
    title: Follow Various Link Locations
    description: `esupport.hop` handles the process of dealing with links so you don't have to
    summary: "Hop" between Neorg links, following them with a single keypress.
    ---
The hop module serves to provide an easy way to follow and fix broken links with a single keypress.

By default, pressing `<CR>` in normal mode under a link will attempt to follow said link.
If the link location is found, you will be taken to the destination - if it is not, you will be
prompted with a set of actions that you can perform on the broken link.
--]]

local neorg = require("neorg.core")
local config, lib, log, modules, utils = neorg.config, neorg.lib, neorg.log, neorg.modules, neorg.utils

local module = modules.create("core.esupports.hop")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.integrations.treesitter",
            "core.ui",
            "core.dirman.utils",
        },
    }
end

module.load = function()
    modules.await("core.keybinds", function(keybinds)
        keybinds.register_keybind(module.name, "hop-link")
    end)
end

module.config.public = {
    -- If true, will attempt to find a link further than your cursor on the current line,
    -- even if your cursor is not over the link itself.
    lookahead = true,

    -- This value determines the strictness of fuzzy matching when trying to fix a link.
    -- Zero means only exact matches will be found, and higher values mean more lenience.
    --
    -- `0.5` is the optimal default value, and it is recommended to keep this option as-is.
    fuzzing_threshold = 0.5,

    -- List of strings specifying which filetypes to open in an external application,
    -- should the user want to open a link to such a file.
    external_filetypes = {},
}

local function xy_le(x0, y0, x1, y1)
    return x0 < x1 or (x0 == x1 and y0 <= y1)
end

local function range_contains(r_out, r_in)
    return xy_le(r_out.row_start, r_out.column_start, r_in.row_start, r_in.column_start)
        and xy_le(r_in.row_end, r_in.column_end, r_out.row_end, r_out.column_end)
end

---@class core.esupports.hop
module.public = {
    --- Follow link from a specific node
    ---@param node table
    ---@param open_mode string|nil if not nil, will open a new split with the split mode defined (vsplitr...) or new tab (mode="tab") or with external app (mode="external")
    ---@param parsed_link table a table of link information gathered from parse_link()
    follow_link = function(node, open_mode, parsed_link)
        if node:type() == "anchor_declaration" then
            local located_anchor_declaration = module.public.locate_anchor_declaration_target(node)

            if not located_anchor_declaration then
                return
            end

            local range =
                module.required["core.integrations.treesitter"].get_node_range(located_anchor_declaration.node)

            vim.cmd([[normal! m`]])
            vim.api.nvim_win_set_cursor(0, { range.row_start + 1, range.column_start })
            return
        end

        if not parsed_link then
            log.warn("Please parse your link before calling this function")
            return
        end

        local located_link_information = module.public.locate_link_target(parsed_link)

        local function os_open_link(link_location)
            local o = {}
            if config.os_info == "windows" then
                o.command = "rundll32.exe"
                o.args = { "url.dll,FileProtocolHandler", link_location }
            else
                o.args = { link_location }
                if config.os_info == "linux" then
                    o.command = "xdg-open"
                elseif config.os_info == "mac" then
                    o.command = "open"
                elseif config.os_info == "wsl2" then
                    o.command = "wslview"
                    -- The file uri should be decoded when being transformed to a unix path.
                    -- The decoding step is temporarily missing from wslview (https://github.com/wslutilities/wslu/issues/295),
                    -- so we work around the problem by doing the transformation before invoking wslview.
                    o.args[1] = vim.uri_to_fname(link_location)
                elseif config.os_info == "wsl" then
                    o.command = "explorer.exe"
                end
            end

            require("plenary.job"):new(o):start()
        end

        local function open_split()
            if open_mode then
                if open_mode == "vsplit" then
                    vim.cmd("vsplit")
                elseif open_mode == "split" then
                    vim.cmd("split")
                elseif open_mode == "tab" then
                    vim.cmd("tabnew")
                end
            end
        end

        local function jump_to_line(line)
            local status, _ = pcall(vim.api.nvim_win_set_cursor, 0, { line, 1 })

            if not status then
                log.error("Failed to jump to line:", line, "- make sure the line number exists!")
            end
        end

        if located_link_information then
            if open_mode == "external" then
                os_open_link(located_link_information.uri or located_link_information.path)
                return
            end

            lib.match(located_link_information.type)({
                -- If we're dealing with a URI, simply open the URI in the user's preferred method
                external_app = function()
                    os_open_link(located_link_information.uri)
                end,

                -- If we're dealing with an external file, open it up in another Neovim buffer (unless otherwise applicable)
                external_file = function()
                    open_split()

                    vim.api.nvim_cmd({ cmd = "edit", args = { located_link_information.path } }, {})

                    if located_link_information.line then
                        jump_to_line(located_link_information.line)
                    end
                end,

                buffer = function()
                    open_split()

                    if located_link_information.buffer ~= vim.api.nvim_get_current_buf() then
                        vim.api.nvim_buf_set_option(located_link_information.buffer, "buflisted", true)
                        vim.api.nvim_set_current_buf(located_link_information.buffer)
                    end

                    if located_link_information.line then
                        jump_to_line(located_link_information.line)
                        return
                    end

                    if located_link_information.node then
                        local range = module.required["core.integrations.treesitter"].get_node_range(
                            located_link_information.node
                        )

                        vim.cmd([[normal! m`]])
                        vim.api.nvim_win_set_cursor(0, { range.row_start + 1, range.column_start })
                        return
                    end
                end,

                calendar = function()
                    local calendar = modules.get_module("core.ui.calendar")
                    if not calendar then
                        log.error("`core.ui.calendar` is not loaded! Unable to open timestamp.")
                        return
                    end

                    local tempus = modules.get_module("core.tempus")
                    if not tempus then
                        log.error("`core.tempus` is not loaded! Unable to parse timestamp.")
                        return
                    end

                    local buffer = vim.api.nvim_get_current_buf()
                    calendar.select_date({
                        date = located_link_information.date,
                        callback = function(input)
                            local start_row, start_col, end_row, end_col = located_link_information.node:range()
                            vim.api.nvim_buf_set_text(
                                buffer,
                                start_row,
                                start_col,
                                end_row,
                                end_col,
                                { "{@ " .. tostring(tempus.to_date(input, false)) .. "}" }
                            )
                        end,
                    })
                end,
            })
            return
        end

        local link_not_found_buf = module.required["core.ui"].create_split("link-not-found")

        local selection = module.required["core.ui"]
            .begin_selection(link_not_found_buf)
            :listener({
                "<Esc>",
            }, function(self)
                self:destroy()
            end)
            :apply({
                warning = function(self, text)
                    return self:text("WARNING: " .. text, "@text.warning")
                end,
                desc = function(self, text)
                    return self:text(text, "@comment")
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

                module.private.write_fixed_link(node, parsed_link, similarities) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
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

                module.private.write_fixed_link(node, parsed_link, similarities, true)
            end)
            :blank()
            :warning("The below flags currently do not work, this is a beta build.")
            :desc("Instead of fixing the link you may actually want to create the target:")
            :flag("a", "Place target above current link parent")
            :flag("b", "Place target below current link parent")
    end,

    --- Locate a `link` or `anchor` node under the cursor
    ---@return userdata|nil #A `link` or `anchor` node if present under the cursor, else `nil`
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

        return found_node
    end,

    --- Attempts to locate a `link` or `anchor` node after the cursor on the same line
    ---@return userdata|nil #A `link` or `anchor` node if present on the current line, else `nil`
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

            if vim.tbl_contains({ "link_location", "link_description" }, node_under_cursor:type()) then
                resulting_node = node_under_cursor:parent()
            end

            index = index + 1
        end

        return resulting_node
    end,

    --- Locates the node that an anchor is pointing to
    ---@param anchor_decl_node table #A valid anchod declaration node
    locate_anchor_declaration_target = function(anchor_decl_node)
        if not anchor_decl_node:named_child(0) then
            return
        end

        local target = module
            .required
            ["core.integrations.treesitter"]
            .get_node_text(anchor_decl_node:named_child(0):named_child(0)) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
            :gsub("[%s\\]", "")

        local query_str = [[
            (anchor_definition
                (link_description
                    text: (paragraph) @text
                )
            )
        ]]

        local document_root = module.required["core.integrations.treesitter"].get_document_root()

        if not document_root then
            return
        end

        local query = utils.ts_parse_query("norg", query_str)

        for id, node in query:iter_captures(document_root, 0) do
            local capture = query.captures[id]

            if capture == "text" then
                local original_title = module.required["core.integrations.treesitter"].get_node_text(node)
                local title = original_title:gsub("[%s\\]", "")

                if title:lower() == target:lower() then
                    return {
                        original_title = original_title,
                        node = node,
                    }
                end
            end
        end
    end,

    --- Converts a link node into a table of data related to the link
    ---@param link_node userdata #The link node that was found by e.g. `extract_link_node()`
    ---@param buf number #The buffer to parse the link in
    ---@return table? #A table of data about the link
    parse_link = function(link_node, buf)
        buf = buf or 0
        if not link_node or not vim.tbl_contains({ "link", "anchor_definition" }, link_node:type()) then ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
            return
        end

        local query_text = [[
            [
                (link
                    (link_location
                        file: (
                            (link_file_text) @link_file_text
                        )?
                        type: [
                            (link_target_url)
                            (link_target_generic)
                            (link_target_external_file)
                            (link_target_definition)
                            (link_target_timestamp)
                            (link_target_footnote)
                            (link_target_heading1)
                            (link_target_heading2)
                            (link_target_heading3)
                            (link_target_heading4)
                            (link_target_heading5)
                            (link_target_heading6)
                            (link_target_line_number)
                        ]? @link_type
                        text: (paragraph)? @link_location_text
                    )
                    (link_description
                        text: (paragraph) @link_description
                    )?
                )
                (anchor_definition
                    (link_description
                        text: (paragraph) @link_description
                    )
                    (link_location
                        file: (
                            (link_file_text) @link_file_text
                        )?
                        type: [
                            (link_target_url)
                            (link_target_generic)
                            (link_target_external_file)
                            (link_target_definition)
                            (link_target_timestamp)
                            (link_target_footnote)
                            (link_target_heading1)
                            (link_target_heading2)
                            (link_target_heading3)
                            (link_target_heading4)
                            (link_target_heading5)
                            (link_target_heading6)
                        ]? @link_type
                        text: (paragraph)? @link_location_text
                    )
                )
            ]
        ]]

        local document_root = module.required["core.integrations.treesitter"].get_document_root(buf)

        if not document_root then
            return
        end

        local query = utils.ts_parse_query("norg", query_text)
        local range = module.required["core.integrations.treesitter"].get_node_range(link_node)

        local parsed_link_information = {
            link_node = link_node,
        }

        for id, node in query:iter_captures(document_root, buf, range.row_start, range.row_end + 1) do
            local capture = query.captures[id]

            local capture_node_range = module.required["core.integrations.treesitter"].get_node_range(node)

            -- Check whether the node captured node is in bounds.
            -- There are certain rare cases where incorrect nodes would be parsed.
            if range_contains(range, capture_node_range) then
                local extract_node_text = lib.wrap(module.required["core.integrations.treesitter"].get_node_text, node)

                parsed_link_information[capture] = parsed_link_information[capture]
                    or lib.match(capture)({
                        link_file_text = extract_node_text,
                        link_type = lib.wrap(string.sub, node:type(), string.len("link_target_") + 1),
                        link_location_text = extract_node_text,
                        link_description = extract_node_text,

                        _ = function()
                            log.error("Unknown capture type encountered when parsing link:", capture)
                        end,
                    })
            end
        end

        return parsed_link_information
    end,

    --- Locate the target that a link points to
    ---@param parsed_link_information table #A table returned by `parse_link()`
    ---@return table #A table containing data about the link target
    locate_link_target = function(parsed_link_information)
        --- A pointer to the target buffer we will be parsing.
        -- This may change depending on the target file the user gave.
        local buf_pointer = vim.api.nvim_get_current_buf()

        -- Check whether our target is from a different file
        if parsed_link_information.link_file_text then
            local expanded_link_text =
                module.required["core.dirman.utils"].expand_path(parsed_link_information.link_file_text)

            if expanded_link_text ~= vim.fn.expand("%:p") then
                -- We are dealing with a foreign file
                buf_pointer = vim.uri_to_bufnr("file://" .. expanded_link_text)
            end

            if not parsed_link_information.link_type then
                return {
                    type = "buffer",
                    original_title = nil,
                    node = nil,
                    buffer = buf_pointer,
                }
            end
        end

        return lib.match(parsed_link_information.link_type)({
            url = function()
                return { type = "external_app", uri = parsed_link_information.link_location_text }
            end,

            external_file = function()
                local destination = parsed_link_information.link_location_text
                local path, line = string.match(destination, "^(.*):(%d+)$")
                if line then
                    destination = path
                    line = tonumber(line)
                end
                destination = (
                    vim.tbl_contains({ "/", "~" }, destination:sub(1, 1)) and "" or (vim.fn.expand("%:p:h") .. "/")
                ) .. destination

                return lib.match(vim.fn.fnamemodify(destination, ":e"))({
                    [{ "jpg", "jpeg", "png", "pdf" }] = {
                        type = "external_app",
                        uri = vim.uri_from_fname(vim.fn.expand(destination)), ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
                    },
                    [module.config.public.external_filetypes] = {
                        type = "external_app",
                        uri = vim.uri_from_fname(vim.fn.expand(destination)), ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
                    },
                    _ = function()
                        return {
                            type = "external_file",
                            path = vim.fn.fnamemodify(destination, ":p"),
                            line = line,
                        }
                    end,
                })
            end,

            line_number = function()
                return {
                    type = "buffer",
                    buffer = buf_pointer,
                    line = tonumber(parsed_link_information.link_location_text),
                }
            end,

            timestamp = function()
                local tempus = modules.get_module("core.tempus")

                if not tempus then
                    log.error("`core.tempus` is not loaded! Unable to parse timestamp.")
                    return {}
                end

                local parsed_date = tempus.parse_date(parsed_link_information.link_location_text)

                if type(parsed_date) == "string" then
                    log.error("[ERROR]:", parsed_date)
                    return {}
                end

                return {
                    type = "calendar",
                    date = tempus.to_lua_date(parsed_date),
                    node = parsed_link_information.link_node,
                }
            end,

            _ = function()
                local query_str = lib.match(parsed_link_information.link_type)({
                    generic = [[
                        [(_
                          [(strong_carryover_set
                             (strong_carryover
                               name: (tag_name) @tag_name
                               (tag_parameters) @title
                               (#eq? @tag_name "name")))
                           (weak_carryover_set
                             (weak_carryover
                               name: (tag_name) @tag_name
                               (tag_parameters) @title
                               (#eq? @tag_name "name")))]?
                          title: (paragraph_segment) @title)
                         (inline_link_target
                           (paragraph) @title)]
                    ]],

                    [{ "definition", "footnote" }] = string.format(
                        [[
                        (%s_list
                            (strong_carryover_set
                                  (strong_carryover
                                    name: (tag_name) @tag_name
                                    (tag_parameters) @title
                                    (#eq? @tag_name "name")))?
                            .
                            [(single_%s
                               (weak_carryover_set
                                  (weak_carryover
                                    name: (tag_name) @tag_name
                                    (tag_parameters) @title
                                    (#eq? @tag_name "name")))?
                               (single_%s_prefix)
                               title: (paragraph_segment) @title)
                             (multi_%s
                               (weak_carryover_set
                                  (weak_carryover
                                    name: (tag_name) @tag_name
                                    (tag_parameters) @title
                                    (#eq? @tag_name "name")))?
                                (multi_%s_prefix)
                                  title: (paragraph_segment) @title)])
                        ]],
                        lib.reparg(parsed_link_information.link_type, 5)
                    ),
                    _ = string.format(
                        [[
                            (%s
                              [(strong_carryover_set
                                 (strong_carryover
                                   name: (tag_name) @tag_name
                                   (tag_parameters) @title
                                   (#eq? @tag_name "name")))
                               (weak_carryover_set
                                 (weak_carryover
                                   name: (tag_name) @tag_name
                                   (tag_parameters) @title
                                   (#eq? @tag_name "name")))]?
                              (%s_prefix)
                              title: (paragraph_segment) @title)
                        ]],
                        lib.reparg(parsed_link_information.link_type, 2)
                    ),
                })

                local document_root = module.required["core.integrations.treesitter"].get_document_root(buf_pointer)

                if not document_root then
                    return
                end

                local query = utils.ts_parse_query("norg", query_str)

                for id, node in query:iter_captures(document_root, buf_pointer) do
                    local capture = query.captures[id]

                    if capture == "title" then
                        local original_title =
                            module.required["core.integrations.treesitter"].get_node_text(node, buf_pointer)

                        if original_title then
                            local title = original_title:gsub("[%s\\]", "")
                            local target = parsed_link_information.link_location_text:gsub("[%s\\]", "")

                            if title:lower() == target:lower() then
                                return {
                                    type = "buffer",
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

    --- Fuzzy fixes a link with a loose type checking query
    ---@param parsed_link_information table #A table as returned by `parse_link()`
    ---@return table #A table of similarities (fuzzed items)
    fix_link_loose = function(parsed_link_information)
        local generic_query = [[
            [(_
              [(strong_carryover_set
                 (strong_carryover
                   name: (tag_name) @tag_name
                   (tag_parameters) @title
                   (#eq? @tag_name "name")))
               (weak_carryover_set
                 (weak_carryover
                   name: (tag_name) @tag_name
                   (tag_parameters) @title
                   (#eq? @tag_name "name")))]?
               title: (paragraph_segment) @title)
             (inline_link_target
               (paragraph) @title)]
        ]]

        return module.private.fix_link(parsed_link_information, generic_query)
    end,

    --- Fuzzy fixes a link with a strict type checking query
    ---@param parsed_link_information table #A table as returned by `parse_link()`
    ---@return table #A table of similarities (fuzzed items)
    fix_link_strict = function(parsed_link_information)
        local query = lib.match(parsed_link_information.link_type)({
            generic = [[
                [(_
                  [(strong_carryover_set
                     (strong_carryover
                       name: (tag_name) @tag_name
                       (tag_parameters) @title
                       (#eq? @tag_name "name")))
                   (weak_carryover_set
                     (weak_carryover
                       name: (tag_name) @tag_name
                       (tag_parameters) @title
                       (#eq? @tag_name "name")))]?
                   title: (paragraph_segment) @title)
                 (inline_link_target
                   (paragraph) @title)]
            ]],
            [{ "definition", "footnote" }] = string.format(
                [[
                (%s_list
                    (strong_carryover_set
                          (strong_carryover
                            name: (tag_name) @tag_name
                            (tag_parameters) @title
                            (#eq? @tag_name "name")))?
                    .
                    [(single_%s
                       (weak_carryover_set
                          (weak_carryover
                            name: (tag_name) @tag_name
                            (tag_parameters) @title
                            (#eq? @tag_name "name")))?
                       (single_%s_prefix)
                       title: (paragraph_segment) @title)
                     (multi_%s
                       (weak_carryover_set
                          (weak_carryover
                            name: (tag_name) @tag_name
                            (tag_parameters) @title
                            (#eq? @tag_name "name")))?
                        (multi_%s_prefix)
                          title: (paragraph_segment) @title)])
            ]],
                lib.reparg(parsed_link_information.link_type, 5)
            ),
            _ = string.format(
                [[
                    (%s
                       [(strong_carryover_set
                          (strong_carryover
                            name: (tag_name) @tag_name
                            (tag_parameters) @title
                            (#eq? @tag_name "name")))
                        (weak_carryover_set
                          (weak_carryover
                            name: (tag_name) @tag_name
                            (tag_parameters) @title
                            (#eq? @tag_name "name")))]?
                        (%s_prefix)
                        title: (paragraph_segment) @title)
                ]],
                lib.reparg(parsed_link_information.link_type, 2)
            ),
        })

        return module.private.fix_link(parsed_link_information, query)
    end,

    --- Query all similar targets that a link could be pointing to
    ---@param parsed_link_information table #A table as returned by `parse_link()`
    ---@param query_str string #The query to be used during the search
    ---@return table #A table of similarities (fuzzed items)
    fix_link = function(parsed_link_information, query_str)
        local buffer = vim.api.nvim_get_current_buf()

        if parsed_link_information.link_file_text then
            local expanded_link_text =
                module.required["core.dirman.utils"].expand_path(parsed_link_information.link_file_text)

            if expanded_link_text ~= vim.fn.expand("%:p") then
                -- We are dealing with a foreign file
                buffer = vim.uri_to_bufnr("file://" .. expanded_link_text)
            end
        end

        local query = utils.ts_parse_query("norg", query_str)

        local document_root = module.required["core.integrations.treesitter"].get_document_root(buffer)

        if not document_root then
            return ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
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
            utils.notify("Sorry, Neorg couldn't fix that link.", vim.log.levels.WARN)
        end

        table.sort(similarities, function(lhs, rhs)
            return lhs.similarity < rhs.similarity
        end)

        return similarities
    end,

    --- Writes a link that was fixed through fuzzing into the buffer
    ---@param link_node userdata #The treesitter node of the link, extracted by e.g. `extract_link_node()`
    ---@param parsed_link_information table #A table as returned by `parse_link()`
    ---@param similarities table #The table of similarities as returned by `fix_link_*()`
    ---@param force_type boolean #If true will forcefully overwrite the link type to the target type as well (e.g. would convert `#` -> `*`)
    write_fixed_link = function(link_node, parsed_link_information, similarities, force_type)
        local most_similar = similarities[1]

        if not link_node or not most_similar then
            return
        end

        local range = module.required["core.integrations.treesitter"].get_node_range(link_node)

        local prefix = lib.when(
            parsed_link_information.link_type == "generic" and not force_type,
            "#",
            lib.match(most_similar.node:type())({
                heading1 = "*",
                heading2 = "**",
                heading3 = "***",
                heading4 = "****",
                heading5 = "*****",
                heading6 = "******",
                single_definition = "$",
                multi_definition = "$",
                single_footnote = "^",
                multi_footnote = "^",
                _ = "#",
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
                .. lib.when(
                    parsed_link_information.link_file_text,
                    lib.lazy_string_concat(":", parsed_link_information.link_file_text, ":"),
                    ""
                )
                .. prefix
                .. most_similar.text
                .. "}"
                .. lib.when(
                    parsed_link_information.link_description,
                    lib.lazy_string_concat("[", parsed_link_information.link_description, "]"),
                    ""
                )
        )
    end,
}

module.on_event = function(event)
    if event.split_type[2] == "core.esupports.hop.hop-link" then
        local split_mode = event.content[1]

        -- Get link node at cursor
        local link_node_at_cursor = module.public.extract_link_node()

        if not link_node_at_cursor then
            log.trace("No link under cursor.")
            return
        end

        local parsed_link = module.public.parse_link(link_node_at_cursor) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>

        module.public.follow_link(link_node_at_cursor, split_mode, parsed_link) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
    end
end

module.events.subscribed = {
    ["core.keybinds"] = {
        ["core.esupports.hop.hop-link"] = true,
    },
}

return module
