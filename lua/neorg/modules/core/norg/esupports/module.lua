--[[
	Module for supporting the user while editing. Esupports -> Editing Supports
	Currently provides custom and configurable indenting for Neorg files

USAGE:
	Esupports is part of the `core.defaults` metamodule, and hence should be available to most
	users right off the bat.
CONFIGURATION:
	<TODO>
REQUIRES:
	`core.autocommands` - for detecting whenever a new .norg file is entered
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.esupports")

function _neorg_indent_expr()
    local indent_amount, success

    -- First try and match all available current line checks
    if module.config.public.indent_config.current.enabled then
        for _, data in pairs(module.config.public.indent_config.current) do
            if type(data) == "table" and data.enabled then
                -- Check whether the line matches any of our criteria
                indent_amount, success = module.public.create_indent(data.regex, data.indent, true)
                -- If it does, then return that indent!
                if success then
                    return indent_amount
                end
            end
        end
    end

    -- Attempt to match the current indent level based on the previous nonblank line
    if module.config.public.indent_config.previous.enabled then
        for _, data in pairs(module.config.public.indent_config.previous) do
            if type(data) == "table" and data.enabled then
                -- Check whether the line matches any of our criteria
                indent_amount, success = module.public.create_indent(data.regex, data.indent, false)
                -- If it does, then return that indent!
                if success then
                    return indent_amount
                end
            end
        end
    end

    -- If no criteria were met, let neovim handle the rest
    return vim.fn.indent(vim.api.nvim_win_get_cursor(0)[1])
end

module.setup = function()
    return { success = true, requires = { "core.autocommands", "core.keybinds", "core.norg.dirman", "core.scanner" } }
end

module.config.public = {
    indent = true,

    indent_config = {
        current = {
            enabled = true,

            heading1 = {
                enabled = true,
                regex = "(%s*%*%s+)(.*)",
                indent = function()
                    return 0
                end,
            },

            heading2 = {
                enabled = true,
                regex = "(%s*%*%*%s+)(.*)",
                indent = function()
                    return 1
                end,
            },

            heading3 = {
                enabled = true,
                regex = "(%s*%*%*%*%s+)(.*)",
                indent = function()
                    return 2
                end,
            },

            heading4 = {
                enabled = true,
                regex = "(%s*%*%*%*%*%s+)(.*)",
                indent = function()
                    return 3
                end,
            },

            heading5 = {
                enabled = true,
                regex = "(%s*%*%*%*%*%*%s+)(.*)",
                indent = function()
                    return 4
                end,
            },

            heading6 = {
                enabled = true,
                regex = "(%s*%*%*%*%*%*%*+%s+)(.*)",
                indent = function()
                    return 5
                end,
            },

            tags = {
                enabled = true,
                regex = "%s*@[a-z0-9]+.*",
                indent = function()
                    return 0
                end,
            },
        },

        previous = {
            enabled = true,

            todo_items = {
                enabled = true,
                regex = "(%s*)%-%s+%[%s*[x*%s]%s*%]%s+.*",
                indent = function(matches)
                    return matches[1]:len()
                end,
            },

            headings = {
                enabled = true,
                regex = "(%s*%*+%s+)(.*)",
                indent = function(matches)
                    if matches[2]:len() > 0 then
                        return matches[1]:len()
                    else
                        return -1
                    end
                end,
            },

            unordered_lists = {
                enabled = true,
                regex = "(%s*)%-%s+.+",
                indent = function(matches)
                    return matches[1]:len()
                end,
            },
        },

        realtime = {
            enabled = true,

            heading1 = {
                enabled = true,
                regex = "%s*%*%s+(.*)",
                indent = function()
                    return 0
                end,
            },

            heading2 = {
                enabled = true,
                regex = "%s*%*%*%s+(.*)",
                indent = function()
                    return 1
                end,
            },

            heading3 = {
                enabled = true,
                regex = "%s*%*%*%*%s+(.*)",
                indent = function()
                    return 2
                end,
            },

            heading4 = {
                enabled = true,
                regex = "%s*%*%*%*%*%s+(.*)",
                indent = function()
                    return 3
                end,
            },

            heading5 = {
                enabled = true,
                regex = "%s*%*%*%*%*%*%s+(.*)",
                indent = function()
                    return 4
                end,
            },

            heading6 = {
                enabled = true,
                regex = "%s*%*%*%*%*%*(%*+)%s+(.*)",
                indent = function(matches)
                    return 5 + matches[1]:len()
                end,
            },
        },
    },

    folds = {
        enabled = true,
        foldlevel = 99,
    },

    goto_links = true,
    fuzzing_threshold = 1,
    generate_meta_tags = true,
}

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufEnter")
    module.required["core.autocommands"].enable_autocommand("BufWrite")

    if module.config.public.indent_config.realtime.enabled then
        module.required["core.autocommands"].enable_autocommand("TextChangedI")
    end

    module.required["core.keybinds"].register_keybind(module.name, "goto_link")
end

module.public = {

    -- @Summary Creates a new indent
    -- @Description Sets a new set of rules that when fulfilled will indent the text properly
    -- @Param  match (string) - a regex that should match the line above the newly placed line
    -- @Param  indent (function(matches) -> number) - a function that should return the level of indentation in spaces for that line
    -- @Param  current (boolean) - if true checks the current line rather than the previous non-blank line
    create_indent = function(match, indent, current)
        local line_number = current and vim.api.nvim_win_get_cursor(0)[1]
            or vim.fn.prevnonblank(vim.api.nvim_win_get_cursor(0)[1] - 1)

        -- If the line number above us is 0 then don't indent anything
        if line_number == 0 then
            return 0
        end

        -- nvim_buf_get_lines() doesn't work here for some reason :(
        local line = vim.fn.getline(line_number)

        -- Pack all the matches into this lua table
        local matches = { line:match("^(" .. match .. ")$") }

        -- If the match is successful
        if matches[1] and matches[1]:len() > 0 then
            -- Invoke the callback for indenting
            local indent_amount = indent(vim.list_slice(matches, 2))

            if indent_amount == -1 then
                indent_amount = vim.fn.indent(line)
            elseif not current then
                indent_amount = indent_amount + (vim.api.nvim_strwidth(line) - line:len())
            end

            -- Return success
            return indent_amount, true
        end

        -- If we haven't found a match, return nothing
        return nil, false
    end,

    -- @Summary Creates metadata for the current file
    -- @Description Pastes a @document.meta block at the top of the current document
    construct_metadata = function()
        vim.api.nvim_win_set_cursor(0, { 1, 0 })

        vim.api.nvim_put({
            "@document.meta",
            "\ttitle: " .. vim.fn.expand("%:t:r"),
            "\tdescription: ",
            "\tauthor: " .. require("neorg.external.helpers").get_username(),
            "\tcategories: ",
            "\tcreated: " .. os.date("%F"),
            "\tversion: " .. require("neorg.config").version,
            "@end",
            "",
        }, "l", false, true)

        vim.opt_local.modified = false
    end,

    -- @Summary Indents the current line
    -- @Description Performs real-time indentation of the current line
    indent_line = function()
        -- Loop through all the data present in the indent configuration
        for _, data in pairs(module.config.public.indent_config.realtime) do
            -- If the data we're dealing with is correct and it's enabled then
            if type(data) == "table" and data.enabled then
                -- Get the indent amount for the current line
                local indent_amount, success = module.public.create_indent(data.regex, data.indent, true)

                -- If we've managed to successfully indent the current line
                if success then
                    -- Cache the current line (before any changes)
                    local cursor_pos = vim.api.nvim_win_get_cursor(0)

                    -- Set the indentation level for the current line
                    local line = vim.api.nvim_get_current_line()
                    local sub = line:gsub("^%s*", (" "):rep(indent_amount))

                    -- If the line has undergone any changes
                    if sub ~= vim.api.nvim_get_current_line() then
                        -- Set the line to the newly indented line
                        vim.api.nvim_set_current_line(sub)

                        -- Calculate the difference in chars from before the indentation to set the cursor
                        -- accordingly (otherwise it would get offset in weird ways)
                        vim.api.nvim_win_set_cursor(0, {
                            cursor_pos[1],
                            cursor_pos[2]
                                + (vim.api.nvim_strwidth(vim.api.nvim_get_current_line()) - vim.api.nvim_strwidth(line)),
                        })
                    end

                    break
                end
            end
        end
    end,

    locate_link = function(force_type, locators, multi_file_eval)
        local treesitter = neorg.modules.get_module("core.integrations.treesitter")
        local result = {
            is_under_link = false,
            link_location = nil,
            link_info = {},
        }

        if treesitter then
            local link_info = treesitter.get_link_info()

            if not link_info then
                return result
            else
                result.is_under_link = true
                result.link_info = link_info
            end

            local files = {}
            local link_type = force_type and force_type or link_info.type

            do
                local function slice(text, regex)
                    return ({ text:gsub("^" .. regex .. "$", "%1") })[1]
                end

                link_info.text = slice(link_info.text, "%[(.+)%]")
                link_info.location = slice(link_info.location, "%((.*[%*%#%|]*.+)%)")

                local scanner = module.required["core.scanner"]

                scanner:initialize_new(link_info.location)

                if scanner:lookahead() ~= ":" then
                    scanner:halt(false, true)
                else
                    while scanner:lookahead() do
                        if
                            vim.tbl_contains({ "|", "*", "#" }, scanner:lookbehind())
                            and scanner:lookbehind(2) == ":"
                        then
                            scanner:backtrack(2)
                            scanner:halt(false, true)
                        elseif scanner:lookahead() == ":" then
                            if scanner:current() == "\\" then
                                scanner:advance()
                            elseif not scanner:current() then
                                scanner:skip()
                                scanner:skip()
                                scanner:mark_end()
                            else
                                scanner:advance()
                                scanner:mark_end()
                                scanner:skip()
                            end
                        end

                        scanner:advance()
                    end
                end

                scanner:mark_end()

                files = scanner:end_session()

                link_info.fileless_location = files[#files]
                files[#files] = slice(files[#files], "[%*%#%|]+(.+)")
            end

            local utility = {
                buf = 0,

                ts = neorg.modules.get_module("core.integrations.treesitter") or {},

                strip = function(str)
                    return ({ str:lower():gsub("\\([^\\])", "%1"):gsub("%s+", "") })[1]
                end,

                get_text_as_one = function(self, node)
                    local ts = require("nvim-treesitter.ts_utils")
                    return table.concat(ts.get_node_text(node, self.buf), "\n")
                end,
            }

            if #files == 1 then -- Search only in current file
                local tree = vim.treesitter.get_parser(0, "norg"):parse()[1]

                if not tree then
                    return result
                end

                if not locators[link_type] then
                    log.error("Locator not present for link type:", link_type)
                    return result
                end

                result.link_location = locators[link_type](tree, files[#files], utility)
                return result
            else
                if multi_file_eval then
                    return multi_file_eval(files, locators, link_type, utility, result)
                else
                    result.link_info.file = ""

                    for _, file in ipairs(vim.list_slice(files, 0, #files - 1)) do
                        if vim.startswith(file, "/") then
                            file = module.required["core.norg.dirman"].get_current_workspace()[2] .. file
                        else
                            file = vim.fn.expand("%:p:h") .. "/" .. file
                        end

                        if not vim.endswith(file, ".norg") then
                            file = file .. ".norg"
                        end

                        -- Attempt to open the last workspace cache file in read-only mode
                        local fd = vim.loop.fs_open(file, "r", 438)
                        if not fd then
                            return result
                        end

                        -- Attempt to stat the file and get the file length of the cache file
                        local stat = vim.loop.fs_stat(file)
                        if not stat then
                            return result
                        end

                        local read_data = vim.loop.fs_read(fd, stat.size, 0)
                        if not read_data then
                            return result
                        end

                        vim.loop.fs_close(fd)

                        local buf = vim.api.nvim_create_buf(false, true)

                        vim.api.nvim_buf_set_lines(buf, 0, -1, true, vim.split(read_data, "\n", true))

                        local tree = vim.treesitter.get_parser(buf, "norg"):parse()[1]

                        if not tree then
                            return result
                        end

                        if not locators[link_type] then
                            log.error("Locator not present for link type:", link_type)
                            return result
                        end

                        result.link_location = locators[link_type](
                            tree,
                            files[#files],
                            vim.tbl_extend("force", utility, { buf = buf })
                        )

                        vim.api.nvim_buf_delete(buf, { force = true })

                        result.link_info.file = file

                        if result.link_location then
                            return result
                        end
                    end

                    return result
                end
            end
        end
    end,

    --- Locates a link present under the cursor and jumps to it
    --- Optionally provides actions that can be performed when a link cannot be found
    goto_link = function()
        -- First, grab the location of our link
        local link = module.public.locate_link(nil, module.public.locators.strict)

        -- If there were no internal errors but no location was given then
        if link and not link.link_location then
            -- If we were never under a link to begin with simply bail
            if not link.is_under_link then
                log.trace("No link found under cursor at position:", vim.api.nvim_win_get_cursor(0)[1])
                return
            end

            -- Otherwise it means the destination could not be found, prompt the user with what to do next

            local ui = neorg.modules.get_module("core.ui")

            if not ui then
                return
            end

            -- This variable will be true if we're searching for a destination in a file other than the current file
            local searching_in_foreign_file = link.link_info.file and link.link_info.file ~= vim.fn.expand("%:p")

            -- Actually prompt the user
            ui.create_selection("Link not found - what do we do now?", {
                flags = {
                    { "General actions:", "TSComment" },
                    { "n", "Nothing" },
                    {
                        "f",
                        {
                            display = "Attempt to fix the link",
                            name = "Fixing method",
                            flags = {
                                { "f", "Fuzzy fixing (search for any element)" },
                                { "s", "Strict fixing (search for element of the link type)" },
                            },
                        },
                    },
                    {},
                    { "Locations:", "TSComment" },
                    { "a", "Place above parent node", searching_in_foreign_file },
                    { "A", "Place at the top of the document" },
                    { "b", "Place below parent node", searching_in_foreign_file },
                    { "B", "Place at the bottom of the document" },
                    {},
                    { "Custom:", "TSComment" },
                    {
                        "c",
                        {
                            name = "Enter insert-linkable mode with the following restraints",
                            display = "Custom Placement",
                            flags = {
                                { "h", "Traverse the document by heading" },
                                { "f", "Traverse the document freely" },
                            },
                        },
                        -- This currently isn't supported and so is greyed out
                        true,
                    },
                },
            }, function(result, _)
                --- Converts a node type (like "heading1" or "marker") into a char
                --- representation ("*"/"|" etc.)
                --- @param type string a node type
                local function from_type_to_link_identifier(type)
                    if vim.startswith(type, "heading") then
                        local start = ("heading"):len()
                        return ("*"):rep(tonumber(type:sub(start + 1, start + 1)))
                    elseif type == "marker" then
                        return "|"
                    elseif type == "drawer" then
                        return "||"
                    else
                        return "#"
                    end
                end

                --- Returns the type of node we should search for from a link type
                --- @param link_type string the type of link we're dealing with
                local function extract_node_type(link_type)
                    if vim.startswith(link_type, "link_end_heading") then
                        local start = ("link_end_heading"):len()
                        return "heading" .. link_type:sub(start + 1, start + 1)
                    elseif link_type:find("drawer") then
                        return "drawer"
                    elseif link_type:find("marker") then
                        return "marker"
                    else
                        return "any"
                    end
                end

                local ts = neorg.modules.get_module("core.integrations.treesitter")

                if not ts then
                    log.error(
                        "Unable to perform operations on the syntax tree, treesitter integrations module not loaded"
                    )
                    return
                end

                if #result == 1 then
                    local selected_value = result[1]

                    -- If the user chose to "do nothing" then do nothing :)
                    if selected_value == "n" then
                        return
                        -- If the user has pressed one of "a" or "b" (above/below) then
                    elseif vim.tbl_contains({ "a", "b" }, selected_value) then
                        -- Extract the type of node we should start searching for
                        local to_search = extract_node_type(link.link_info.type)

                        -- If the returned value was any (aka we were dealing with a generic #link)
                        -- then bail, we can't possibly create a linkable if we don't know its type
                        if to_search == "any" then
                            vim.notify("Cannot create a linkable from ambiguous type '#'!", 4)
                            return
                        end

                        -- Extract the link node
                        local link_node = link.link_info.node

                        -- Keep searching for a potential parent node
                        while
                            link_node:type() ~= to_search
                            and link_node:parent():type() ~= "document_content"
                            and link_node:type() ~= "marker"
                        do
                            link_node = link_node:parent()
                        end

                        local range = ts.get_node_range(link_node)

                        -- Here is where we be a bit more narrow, depending on the selected value insert
                        -- the text at different locations
                        if selected_value == "a" then
                            vim.fn.append(range.row_start, {
                                (" "):rep(range.column_start) .. link.link_info.location:gsub("^([%#%*%|]+)", "%1 "),
                                "",
                            })
                        else
                            local line = vim.api.nvim_buf_get_lines(0, range.row_end - 1, range.row_end, true)[1]

                            -- If the line has non-whitespace characters then insert an extra newline before the linkable
                            if line:match("%S") then
                                vim.fn.append(range.row_end, {
                                    "",
                                    (" "):rep(range.column_start) .. link.link_info.location:gsub("^([%#%*%|]+)", "%1 "),
                                    "",
                                })
                            else
                                vim.fn.append(range.row_end, {
                                    (" "):rep(range.column_start) .. link.link_info.location:gsub("^([%#%*%|]+)", "%1 "),
                                    "",
                                })
                            end
                        end
                        -- Else if we pressed one of { A, B }
                    elseif vim.tbl_contains({ "A", "B" }, selected_value) then
                        -- If we're dealing with a foreign file then open that up first
                        if link.link_info.file and link.link_info.file:len() > 0 then
                            vim.cmd("e " .. link.link_info.file)
                        end

                        local document_tree = vim.treesitter.get_parser(0, "norg"):parse()[1]

                        if not document_tree then
                            log.error("Unable to parse current document, what a bummer")
                            return
                        end

                        local document = document_tree:root()
                        local range = ts.get_node_range(
                            document:named_child(document:named_child_count() == 1 and 0 or 1)
                        )

                        -- TODO: Add support for selecting which file to place the link in if multiple files are given
                        if selected_value == "A" then
                            local line

                            if document:named_child_count() == 1 then
                                line = vim.api.nvim_buf_get_lines(0, 0, 1, true)[1]
                            else
                                line = vim.api.nvim_buf_get_lines(0, range.row_start - 1, range.row_start, true)[1]
                            end

                            if range.row_start > 0 and line:match("%S") then
                                vim.fn.append(range.row_start, {
                                    "",
                                    (" "):rep(range.column_start) .. link.link_info.location:gsub("^([%#%*%|]+)", "%1 "),
                                    "",
                                })
                            else
                                vim.fn.append(range.row_start, {
                                    (" "):rep(range.column_start) .. link.link_info.location:gsub("^([%#%*%|]+)", "%1 "),
                                    "",
                                })
                            end
                        elseif selected_value == "B" then
                            local line = vim.api.nvim_buf_get_lines(0, range.row_end - 1, range.row_end, true)[1]

                            if line:match("%S") then
                                vim.fn.append(range.row_end, {
                                    "",
                                    (" "):rep(range.column_start) .. link.link_info.location:gsub("^([%#%*%|]+)", "%1 "),
                                    "",
                                })
                            else
                                vim.fn.append(range.row_end, {
                                    (" "):rep(range.column_start) .. link.link_info.location:gsub("^([%#%*%|]+)", "%1 "),
                                    "",
                                })
                            end
                        end
                    end

                    vim.cmd("w")
                else
                    if result[1] == "f" then
                        local fixed_link = module.public.locate_link(
                            result[2] == "f" and "link_end_generic" or nil,
                            module.public.locators.fuzzy,
                            function(files, locators, link_type, utility, callback_result)
                                local best_matches = {}

                                for _, file in ipairs(vim.list_slice(files, 0, #files - 1)) do
                                    if vim.startswith(file, "/") then
                                        file = module.required["core.norg.dirman"].get_current_workspace()[2] .. file
                                    else
                                        file = vim.fn.expand("%:p:h") .. "/" .. file
                                    end

                                    if not vim.endswith(file, ".norg") then
                                        file = file .. ".norg"
                                    end

                                    -- Attempt to open the last workspace cache file in read-only mode
                                    local fd = vim.loop.fs_open(file, "r", 438)
                                    if not fd then
                                        return callback_result
                                    end

                                    -- Attempt to stat the file and get the file length of the cache file
                                    local stat = vim.loop.fs_stat(file)
                                    if not stat then
                                        return callback_result
                                    end

                                    local read_data = vim.loop.fs_read(fd, stat.size, 0)
                                    if not read_data then
                                        return callback_result
                                    end

                                    vim.loop.fs_close(fd)

                                    local buf = vim.api.nvim_create_buf(false, true)

                                    vim.api.nvim_buf_set_lines(buf, 0, -1, true, vim.split(read_data, "\n", true))

                                    local tree = vim.treesitter.get_parser(buf, "norg"):parse()[1]

                                    if not tree then
                                        return callback_result
                                    end

                                    if not locators[link_type] then
                                        log.error("Locator not present for link type:", link_type)
                                        return callback_result
                                    end

                                    table.insert(best_matches, {
                                        locators[link_type](
                                            tree,
                                            files[#files],
                                            vim.tbl_extend("force", utility, { buf = buf })
                                        ),
                                        file,
                                    })

                                    vim.api.nvim_buf_delete(buf, { force = true })
                                end

                                table.sort(best_matches, function(lhs, rhs)
                                    return lhs[1].similarity < rhs[1].similarity
                                end)

                                callback_result.link_location = best_matches[1][1]
                                callback_result.link_info.file = best_matches[1][2]

                                return callback_result
                            end
                        )

                        if fixed_link.link_location then
                            vim.api.nvim_buf_set_text(
                                0,
                                link.link_info.range.row_start,
                                link.link_info.range.column_start,
                                link.link_info.range.row_end,
                                link.link_info.range.column_end,
                                {
                                    "[" .. fixed_link.link_info.text .. "](" .. (fixed_link.link_info.location:match(
                                        "(:.*:)[%*%#%|]+"
                                    ) or "") .. from_type_to_link_identifier(
                                        fixed_link.link_location.type
                                    ) .. fixed_link.link_location.text .. ")",
                                }
                            )
                            return
                        else
                            vim.notify("Sorry, Neorg couldn't fix that link :(")
                        end
                    end
                end
            end)

            return
        end

        if link then
            if link.link_info.file and vim.fn.expand("%:p") ~= link.link_info.file then
                vim.cmd("e " .. link.link_info.file)
            end

            vim.api.nvim_win_set_cursor(0, { link.link_location.row_start + 1, link.link_location.column_start })
        end
    end,

    locators = {
        strict = {
            generic_heading_find = function(tree, destination, utility, level)
                local result = nil

                utility.ts.tree_map_rec(function(child)
                    if not result and child:type() == "heading" .. tostring(level) then
                        local title = child:named_child(1)

                        if utility.strip(destination) == utility.strip(utility:get_text_as_one(title):sub(1, -2)) then
                            result = utility.ts.get_node_range(title)
                        end
                    end
                end, tree)

                return result
            end,

            link_end_heading1_reference = function(tree, destination, utility)
                return module.public.locators.strict.generic_heading_find(tree, destination, utility, 1)
            end,

            link_end_heading2_reference = function(tree, destination, utility)
                return module.public.locators.strict.generic_heading_find(tree, destination, utility, 2)
            end,

            link_end_heading3_reference = function(tree, destination, utility)
                return module.public.locators.strict.generic_heading_find(tree, destination, utility, 3)
            end,

            link_end_heading4_reference = function(tree, destination, utility)
                return module.public.locators.strict.generic_heading_find(tree, destination, utility, 4)
            end,

            link_end_heading5_reference = function(tree, destination, utility)
                return module.public.locators.strict.generic_heading_find(tree, destination, utility, 5)
            end,

            link_end_heading6_reference = function(tree, destination, utility)
                return module.public.locators.strict.generic_heading_find(tree, destination, utility, 6)
            end,

            link_end_marker_reference = function(tree, destination, utility)
                local result = nil

                utility.ts.tree_map_rec(function(child)
                    if not result and child:type() == "marker" then
                        local marker_title = child:named_child(1)

                        if
                            utility.strip(destination)
                            == utility.strip(utility:get_text_as_one(marker_title):sub(1, -2))
                        then
                            result = utility.ts.get_node_range(marker_title)
                        end
                    end
                end, tree)

                return result
            end,

            link_end_drawer_reference = function(tree, destination, utility)
                local result = nil

                utility.ts.tree_map_rec(function(child)
                    if not result and child:type() == "drawer" then
                        local drawer_title = child:named_child(1)

                        if
                            utility.strip(destination)
                            == utility.strip(utility:get_text_as_one(drawer_title):sub(1, -2))
                        then
                            result = utility.ts.get_node_range(drawer_title)
                        end
                    end
                end, tree)

                return result
            end,

            link_end_generic = function(tree, destination, utility)
                local result = nil

                utility.ts.tree_map_rec(function(child)
                    if
                        not result
                        and vim.tbl_contains({
                            "heading1",
                            "heading2",
                            "heading3",
                            "heading4",
                            "heading5",
                            "heading6",
                            "marker",
                            "drawer",
                        }, child:type())
                    then
                        local title = child:named_child(1)

                        if utility.strip(destination) == utility.strip(utility:get_text_as_one(title):sub(1, -2)) then
                            result = utility.ts.get_node_range(title)
                            result.type = child:type()
                        end
                    end
                end, tree)

                return result
            end,

            link_end_url = function(_, destination, utility)
                vim.cmd("silent !open " .. vim.fn.fnameescape(destination))
                return utility.ts.get_node_range(require("nvim-treesitter.ts_utils").get_node_at_cursor())
            end,
        },

        fuzzy = {
            get_similarity = function(lhs, rhs)
                -- Damerau-levenshtein implementation
                -- NOTE: Taken from https://gist.github.com/Badgerati/3261142
                -- Thank you to whoever made this, you saved me tonnes of effort
                local len1 = string.len(lhs)
                local len2 = string.len(rhs)
                local matrix = {}
                local cost = 0

                -- quick cut-offs to save time
                if len1 == 0 then
                    return len2
                elseif len2 == 0 then
                    return len1
                elseif lhs == rhs then
                    return 0
                end

                -- initialise the base matrix values
                for i = 0, len1, 1 do
                    matrix[i] = {}
                    matrix[i][0] = i
                end
                for j = 0, len2, 1 do
                    matrix[0][j] = j
                end

                -- actual Levenshtein algorithm
                for i = 1, len1, 1 do
                    for j = 1, len2, 1 do
                        if lhs:byte(i) == rhs:byte(j) then
                            cost = 0
                        else
                            cost = 1
                        end

                        matrix[i][j] = math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost)
                    end
                end

                -- Return the last value mixed with our custom similarity checking function
                -- Is it the most efficient? No! It's supposed to be accurate!
                return matrix[len1][len2]
                    / (function()
                        local ret = 1
                        local pattern = ".*"

                        local lhs_escaped = lhs:gsub("\\(\\)?", "%%%1")

                        for i = 1, len1, 1 do
                            if lhs:sub(i, i) == rhs:sub(i, i) then
                                ret = ret + 3
                            end

                            local char = lhs_escaped:sub(i, i)
                            pattern = pattern .. char .. "?"
                        end

                        local match = ({ rhs:match(pattern) })[1]

                        if match then
                            ret = ret + match:len()
                        end

                        return ret
                    end)()
            end,

            fuzzy_find = function(type, tree, destination, utility)
                local results = {}

                utility.ts.tree_map_rec(function(child)
                    if type == child:type() then
                        local title = utility:get_text_as_one(child:named_child(1)):sub(1, -2)

                        local similarity = module.public.locators.fuzzy.get_similarity(
                            utility.strip(destination),
                            utility.strip(title)
                        )

                        table.insert(results, { similarity, child, title })
                    end
                end, tree)

                table.sort(results, function(lhs, rhs)
                    return lhs[1] < rhs[1]
                end)

                local result = utility.ts.get_node_range(results[1][2])
                result.type = results[1][2]:type()
                result.text = results[1][3]
                result.similarity = results[1][1]

                return results[1][1] < module.config.public.fuzzing_threshold and result
            end,

            link_end_heading1_reference = function(tree, destination, utility)
                return module.public.locators.fuzzy.fuzzy_find("heading1", tree, destination, utility)
            end,

            link_end_heading2_reference = function(tree, destination, utility)
                return module.public.locators.fuzzy.fuzzy_find("heading2", tree, destination, utility)
            end,

            link_end_heading3_reference = function(tree, destination, utility)
                return module.public.locators.fuzzy.fuzzy_find("heading3", tree, destination, utility)
            end,

            link_end_heading4_reference = function(tree, destination, utility)
                return module.public.locators.fuzzy.fuzzy_find("heading4", tree, destination, utility)
            end,

            link_end_heading5_reference = function(tree, destination, utility)
                return module.public.locators.fuzzy.fuzzy_find("heading5", tree, destination, utility)
            end,

            link_end_heading6_reference = function(tree, destination, utility)
                return module.public.locators.fuzzy.fuzzy_find("heading6", tree, destination, utility)
            end,

            link_end_marker_reference = function(tree, destination, utility)
                return module.public.locators.fuzzy.fuzzy_find("marker", tree, destination, utility)
            end,

            link_end_drawer_reference = function(tree, destination, utility)
                return module.public.locators.fuzzy.fuzzy_find("drawer", tree, destination, utility)
            end,

            link_end_generic = function(tree, destination, utility)
                local results = {}

                utility.ts.tree_map_rec(function(child)
                    if
                        vim.tbl_contains({
                            "heading1",
                            "heading2",
                            "heading3",
                            "heading4",
                            "heading5",
                            "heading6",
                            "marker",
                            "drawer",
                        }, child:type())
                    then
                        local title = utility:get_text_as_one(child:named_child(1)):sub(1, -2)

                        local similarity = module.public.locators.fuzzy.get_similarity(
                            utility.strip(destination),
                            utility.strip(title)
                        )

                        table.insert(results, { similarity, child, title })
                    end
                end, tree)

                -- TODO: Allow selection when multiple locations have the same similarity
                table.sort(results, function(lhs, rhs)
                    return lhs[1] < rhs[1]
                end)

                local result = utility.ts.get_node_range(results[1][2])
                result.type = results[1][2]:type()
                result.text = results[1][3]
                result.similarity = results[1][1]

                return results[1][1] < module.config.public.fuzzing_threshold and result
            end,
        },
    },
}

module.on_event = function(event)
    if event.type == "core.autocommands.events.bufenter" then
        if event.content.norg then
            if module.config.public.indent then
                vim.opt_local.indentexpr = "v:lua._neorg_indent_expr()"
            end

            -- If folds are enabled then handle them
            if module.config.public.folds.enabled then
                vim.opt_local.foldmethod = "expr"
                vim.opt_local.foldexpr = "nvim_treesitter#foldexpr()"
                vim.opt_local.foldlevel = module.config.public.folds.foldlevel
            end

            if module.config.public.generate_meta_tags then
                -- If the first tag of the document isn't an existing document.meta tag then generate it
                local treesitter = neorg.modules.get_module("core.integrations.treesitter")

                if treesitter then
                    -- Try and query a ranged tag with the name document.meta
                    local query = vim.treesitter.parse_query(
                        "norg",
                        [[
						(foreplay
							(ranged_tag
						  	  (tag_name) @name
						  	  (#eq? @name "document.meta")
							)
						)
					]]
                    )

                    -- If we have not found such a tag then we need to generate one!
                    if not ({ query:iter_matches(vim.treesitter.get_parser(0, "norg"):parse()[1]:root(), 0)() })[2] then
                        module.public.construct_metadata()
                    end
                end
            end
        end
    end

    -- If we have changed some text then attempt to auto-indent the current line
    if
        event.type == "core.autocommands.events.textchangedi" and module.config.public.indent_config.realtime.enabled
    then
        module.public.indent_line()
    end

    --[[ if event.type == "core.autocommands.events.bufwrite" then
-- TODO
    end ]]

    if event.split_type[2] == module.name .. ".goto_link" and module.config.public.goto_links then
        module.public.goto_link()
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
        textchangedi = true,
        bufwrite = false,
    },

    ["core.keybinds"] = {
        [module.name .. ".goto_link"] = true,
    },
}

return module
