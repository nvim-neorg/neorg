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

module.setup = function()
    return {
        success = true,
        requires = {
            "core.autocommands",
            "core.keybinds",
            "core.norg.dirman",
            "core.scanner",
            "core.integrations.treesitter",
        },
    }
end

module.config.public = {
    folds = {
        enabled = true,
        foldlevel = 99,
    },

    goto_links = true,
    fuzzing_threshold = 1,
}

module.load = function()
    module.required["core.autocommands"].enable_autocommand("BufEnter")
    module.required["core.autocommands"].enable_autocommand("BufWrite")

    module.required["core.keybinds"].register_keybind(module.name, "goto_link")
end

module.public = {

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
                    return table.concat(self.ts.get_ts_utils().get_node_text(node, self.buf), "\n")
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

            -- TODO(vhyrro): This new implementation is awesome, however can be cleaned up
            -- We should extract a lot of stuff into its own functions
            -- to prevent code duplication

            -- This variable will be true if we're searching for a destination in a file other than the current file
            local searching_in_foreign_file = link.link_info.file and link.link_info.file ~= vim.fn.expand("%:p")

            --- Returns the type of node we should search for from a link type
            --- @param link_type string the type of link we're dealing with
            local function extract_node_type(link_type)
                if vim.startswith(link_type, "link_end_heading") then
                    local start = ("link_end_heading"):len()
                    return "heading" .. link_type:sub(start + 1, start + 1)
                elseif link_type:find("marker") then
                    return "marker"
                else
                    return "any"
                end
            end

            local ts = neorg.modules.get_module("core.integrations.treesitter")

            if not ts then
                log.error("Unable to perform operations on the syntax tree, treesitter integrations module not loaded")
                return
            end

            local selection = ui.begin_selection(ui.create_split("Link not found"))
                :options({
                    text = {
                        highlight = "TSComment",
                    },
                })
                :listener("destroy", { "<Esc>" }, function(self)
                    self:destroy()
                end)
                :listener("go-back", { "<BS>" }, function(self)
                    self:pop_page()
                end)

            selection
                :title("Link not found - what do we do now?")
                :blank()
                :text("General actions:")
                :flag("n", "Nothing")
                :rflag("f", "Attempt to fix the link", function()
                    selection
                        :title("Fixing method")
                        :blank()
                        :flag("f", "Fuzzy fixing (search for any element)", function()
                            selection:destroy()
                            module.private.fix_link(link, "fuzzy")
                        end)
                        :flag("s", "Strict fixing (search for element matching the link type)", function()
                            selection:destroy()
                            module.private.fix_link(link, "strict")
                        end)
                end)
                :blank()
                :text("Locations:")

            if not searching_in_foreign_file then
                selection
                    :flag("a", "Place above parent node", function()
                        selection:destroy()

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

                        vim.fn.append(range.row_start, {
                            (" "):rep(range.column_start) .. link.link_info.location:gsub("^([%#%*%|]+)", "%1 "),
                            "",
                        })
                    end)
                    :flag("b", "Place below parent node", function()
                        selection:destroy()

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
                    end)
            end

            selection
                :flag("A", "Place at the top of the document", function()
                    selection:destroy()

                    if link.link_info.file and link.link_info.file:len() > 0 then
                        vim.cmd("e " .. link.link_info.file)
                    end

                    local document_tree = vim.treesitter.get_parser(0, "norg"):parse()[1]

                    if not document_tree then
                        log.error("Unable to parse current document, what a bummer")
                        return
                    end

                    local document = document_tree:root()

                    -- Get the range of the document content (skip the foreplay)
                    local range = ts.get_node_range(document:named_child(document:named_child_count() == 1 and 0 or 1))

                    local line

                    -- Depending on whether we have foreplay or not place the linkable at either the start of the file
                    -- or at the start of the document content
                    if document:named_child_count() == 1 then
                        line = vim.api.nvim_buf_get_lines(0, 0, 1, true)[1]
                    else
                        line = vim.api.nvim_buf_get_lines(0, range.row_start - 1, range.row_start, true)[1]
                    end

                    -- If we're not at the start of the document and the current line has a non-whitespace character
                    -- then prepend an extra newline (\n)
                    if range.row_start > 0 and line:match("%S") then
                        vim.fn.append(range.row_start, {
                            "",
                            (" "):rep(range.column_start) .. link.link_info.location:gsub("^([%#%*%|]+)", "%1 "),
                            "",
                        })
                    else -- Else don't lol
                        vim.fn.append(range.row_start, {
                            (" "):rep(range.column_start) .. link.link_info.location:gsub("^([%#%*%|]+)", "%1 "),
                            "",
                        })
                    end

                    vim.cmd("w")
                end)
                :flag("B", "Place at the bottom of the document", function()
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

                    -- Get the range of the document content (skip the foreplay)
                    local range = ts.get_node_range(document:named_child(document:named_child_count() == 1 and 0 or 1))

                    local line = vim.api.nvim_buf_get_lines(0, range.row_end - 1, range.row_end, true)[1]

                    -- Same as above, if the line has a non-whitespace character
                    -- then prepend an extra newline
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

                    vim.cmd("w")
                end)
                :blank()
                :text("Custom:")
                :text("Custom stuff not yet supported :(", "TSStrike")
        elseif link then
            vim.cmd("normal m'")
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

                        if utility.strip(destination) == utility.strip(utility:get_text_as_one(title)) then
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

                        if utility.strip(destination) == utility.strip(utility:get_text_as_one(marker_title)) then
                            result = utility.ts.get_node_range(marker_title)
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
                        }, child:type())
                    then
                        local title = child:named_child(1)

                        if utility.strip(destination) == utility.strip(utility:get_text_as_one(title)) then
                            result = utility.ts.get_node_range(title)
                            result.type = child:type()
                        end
                    end
                end, tree)

                return result
            end,

            link_end_url = function(_, destination, utility)
                if neorg.configuration.os_info == "linux" then
                    vim.cmd('silent !xdg-open "' .. vim.fn.fnameescape(destination) .. '"')
                elseif neorg.configuration.os_info == "mac" then
                    vim.cmd('silent !open "' .. vim.fn.fnameescape(destination) .. '"')
                else
                    vim.cmd('silent !start "' .. vim.fn.fnameescape(destination) .. '"')
                end

                return utility.ts.get_node_range(utility.ts.get_ts_utils().get_node_at_cursor())
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
                        local title = utility:get_text_as_one(child:named_child(1))

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
                        }, child:type())
                    then
                        local title = utility:get_text_as_one(child:named_child(1))

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
            -- If folds are enabled then handle them
            if module.config.public.folds.enabled then
                vim.opt_local.foldmethod = "expr"
                vim.opt_local.foldexpr = "nvim_treesitter#foldexpr()"
                vim.opt_local.foldtext = "v:lua.neorg.utils.foldtext()"
                vim.opt_local.foldlevel = module.config.public.folds.foldlevel
            end
        end
    end

    -- If we have changed some text then attempt to auto-indent the current line
    --[[ if
        event.type == "core.autocommands.events.textchangedi" and module.config.public.indents.realtime.enabled
    then
        module.public.indent_line()
    end ]]

    --[[ if event.type == "core.autocommands.events.bufwrite" then
-- TODO
    end ]]

    if event.split_type[2] == module.name .. ".goto_link" and module.config.public.goto_links then
        module.public.goto_link()
    end
end

module.private = {
    fix_link = function(link, _type)
        --- Converts a node type (like "heading1" or "marker") into a char
        --- representation ("*"/"|" etc.)
        --- @param type string a node type
        local function from_type_to_link_identifier(type)
            if vim.startswith(type, "heading") then
                local start = ("heading"):len()
                return ("*"):rep(tonumber(type:sub(start + 1, start + 1)))
            elseif type == "marker" then
                return "|"
            else
                return "#"
            end
        end

        local fixed_link = module.public.locate_link(
            _type == "fuzzy" and "link_end_generic" or nil,
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
                        locators[link_type](tree, files[#files], vim.tbl_extend("force", utility, { buf = buf })),
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
                    "["
                        .. fixed_link.link_info.text
                        .. "]("
                        .. (fixed_link.link_info.location:match("(:.*:)[%*%#%|]+") or "")
                        .. from_type_to_link_identifier(fixed_link.link_location.type)
                        .. fixed_link.link_location.text
                        .. ")",
                }
            )
            return
        else
            vim.notify("Sorry, Neorg couldn't fix that link :(")
        end
    end,
}

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
