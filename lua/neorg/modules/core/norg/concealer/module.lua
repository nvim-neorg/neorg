--[[
    File: Concealer
    Title: Concealer Module for Neorg
    Summary: Enhances the basic Neorg experience by using icons instead of text.
    ---
This module handles the iconification and concealing of several different
syntax elements in your document.

It's also directly responsible for displaying completion levels
in situations like this:
```norg
* Do Some Things
- [ ] Thing A
- [ ] Thing B
```

Where it will display this instead:
```norg
* Do Some Things (0 of 2) [0% complete]
- [ ] Thing A
- [ ] Thing B
```
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.concealer")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.autocommands",
            "core.keybinds",
            "core.integrations.treesitter",
        },
        imports = {
            "preset_basic",
            "preset_varied",
            "preset_diamond",
            "preset_safe",
            "preset_brave",
        },
    }
end

module.private = {
    icon_namespace = vim.api.nvim_create_namespace("neorg-conceals"),
    markup_namespace = vim.api.nvim_create_namespace("neorg-markup"),
    code_block_namespace = vim.api.nvim_create_namespace("neorg-code-blocks"),
    completion_level_namespace = vim.api.nvim_create_namespace("neorg-completion-level"),
    icons = {},
    markup = {},

    completion_level_base = {
        {
            "(",
        },
        {
            "<done>",
            "TSField",
        },
        {
            " of ",
        },
        {
            "<total>",
            "NeorgTodoItem1Done",
        },
        {
            ") [<percentage>% complete]",
        },
    },

    any_todo_item = function(index)
        local result = "["

        for i = index, 6 do
            result = result
                .. string.format(
                    [[
                (todo_item%d
                    state: [
                        (todo_item_undone) @undone
                        (todo_item_pending) @pending
                        (todo_item_done) @done
                        (todo_item_cancelled) @cancelled
                        (todo_item_urgent) @urgent
                        (todo_item_on_hold) @onhold
                        (todo_item_recurring) @recurring
                        (todo_item_uncertain) @uncertain
                    ]
                )
            ]],
                    i
                )
        end

        return result .. "]"
    end,

    todo_list_query = [[
(generic_list
    [
        (todo_item1
            state: [
                (todo_item_undone) @undone
                (todo_item_pending) @pending
                (todo_item_done) @done
                (todo_item_cancelled) @cancelled
                (todo_item_urgent) @urgent
                (todo_item_on_hold) @onhold
                (todo_item_recurring) @recurring
                (todo_item_uncertain) @uncertain
            ]
        )
        (todo_item2
            state: [
                (todo_item_undone) @undone
                (todo_item_pending) @pending
                (todo_item_done) @done
                (todo_item_cancelled) @cancelled
                (todo_item_urgent) @urgent
                (todo_item_on_hold) @onhold
                (todo_item_recurring) @recurring
                (todo_item_uncertain) @uncertain
            ]
        )
        (todo_item3
            state: [
                (todo_item_undone) @undone
                (todo_item_pending) @pending
                (todo_item_done) @done
                (todo_item_cancelled) @cancelled
                (todo_item_urgent) @urgent
                (todo_item_on_hold) @onhold
                (todo_item_recurring) @recurring
                (todo_item_uncertain) @uncertain
            ]
        )
        (todo_item4
            state: [
                (todo_item_undone) @undone
                (todo_item_pending) @pending
                (todo_item_done) @done
                (todo_item_cancelled) @cancelled
                (todo_item_urgent) @urgent
                (todo_item_on_hold) @onhold
                (todo_item_recurring) @recurring
                (todo_item_uncertain) @uncertain
            ]
        )
        (todo_item5
            state: [
                (todo_item_undone) @undone
                (todo_item_pending) @pending
                (todo_item_done) @done
                (todo_item_cancelled) @cancelled
                (todo_item_urgent) @urgent
                (todo_item_on_hold) @onhold
                (todo_item_recurring) @recurring
                (todo_item_uncertain) @uncertain
            ]
        )
        (todo_item6
            state: [
                (todo_item_undone) @undone
                (todo_item_pending) @pending
                (todo_item_done) @done
                (todo_item_cancelled) @cancelled
                (todo_item_urgent) @urgent
                (todo_item_on_hold) @onhold
                (todo_item_recurring) @recurring
                (todo_item_uncertain) @uncertain
            ]
        )
    ]
)
    ]],

    largest_change_start = -1,
    largest_change_end = -1,
    last_change = {
        active = false,
        line = 0,
    },
}

module.public = {

    -- @Summary Activates icons for the current window
    -- @Description Parses the user configuration and enables concealing for the current window.
    -- @Param icon_set (table) - the icon set to trigger
    -- @Param namespace
    -- @Param from (number) - the line number that we should start at (defaults to 0)
    trigger_icons = function(icon_set, namespace, from, to)
        -- Clear all the conceals beforehand (so no overlaps occur)
        module.public.clear_icons(namespace, from, to)

        -- Get the root node of the document (required to iterate over query captures)
        local document_root = module.required["core.integrations.treesitter"].get_document_root()

        -- Loop through all icons that the user has enabled
        for _, icon_data in ipairs(icon_set) do
            if icon_data.query then
                -- Attempt to parse the query provided by `icon_data.query`
                -- A query must have at least one capture, e.g. "(test_node) @icon"
                local query = vim.treesitter.parse_query("norg", icon_data.query)

                local ok_ts_query, nvim_ts_query = pcall(require, "nvim-treesitter.query")
                local ok_ts_locals, nvim_locals = pcall(require, "nvim-treesitter.locals")

                if not ok_ts_query or not ok_ts_locals then
                    log.error("Unable to trigger icons - nvim-treesitter is not loaded.")
                    return
                end

                -- Go through every found node and try to apply an icon to it
                for match in nvim_ts_query.iter_prepared_matches(query, document_root, 0, from or 0, to or -1) do
                    nvim_locals.recurse_local_nodes(match, function(_, node, capture)
                        if capture == "icon" then
                            -- Extract both the text and the range of the node
                            local text = module.required["core.integrations.treesitter"].get_node_text(node)
                            local range = module.required["core.integrations.treesitter"].get_node_range(node)

                            -- Set the offset to 0 here. The offset is a special value that, well, offsets
                            -- the location of the icon column-wise
                            -- It's used in scenarios where the node spans more than what we want to iconify.
                            -- A prime example of this is the todo item, whose content looks like this: "[x]".
                            -- We obviously don't want to iconify the entire thing, this is why we will tell Neorg
                            -- to use an offset of 1 to start the icon at the "x"
                            local offset = 0

                            -- The extract function is used exactly to calculate this offset
                            -- If that function is present then run it and grab the return value
                            if icon_data.extract then
                                offset = icon_data.extract(text, node) or 0
                            end

                            -- Every icon can also implement a custom "render" function that can allow for things like multicoloured icons
                            -- This is primarily used in nested quotes
                            -- The "render" function must return a table of this structure: { { "text", "highlightgroup1" }, { "optionally more text", "higlightgroup2" } }
                            if not icon_data.render then
                                module.public._set_extmark(
                                    icon_data.icon,
                                    icon_data.highlight,
                                    namespace,
                                    range.row_start,
                                    range.row_end,
                                    range.column_start + offset,
                                    range.column_end,
                                    false,
                                    "combine"
                                )
                            else
                                module.public._set_extmark(
                                    icon_data:render(text, node),
                                    icon_data.highlight,
                                    namespace,
                                    range.row_start,
                                    range.row_end,
                                    range.column_start + offset,
                                    range.column_end,
                                    false,
                                    "combine"
                                )
                            end
                        end
                    end)
                end
            end
        end
    end,

    trigger_highlight_regex_code_block = function(from)
        -- The next block of code will be responsible for dimming code blocks accordingly
        local tree = vim.treesitter.get_parser(0, "norg"):parse()[1]

        -- If the tree is valid then attempt to perform the query
        if tree then
            -- Query all code blocks
            local ok, query = pcall(
                vim.treesitter.parse_query,
                "norg",
                [[(
                    (ranged_tag (tag_name) @_name) @tag
                    (#eq? @_name "code")
                )]]
            )

            -- If something went wrong then go bye bye
            if not ok or not query then
                return
            end

            -- get the language used by the code block
            local code_lang = vim.treesitter.parse_query(
                "norg",
                [[(
                    (ranged_tag (tag_name) @_tagname (tag_parameters) @language)
                )]]
            )

            -- look for language name in code blocks
            -- this will not finish if a treesitter parser exists for the current language found
            for id, node in code_lang:iter_captures(tree:root(), 0, from or 0, -1) do
                local lang_name = code_lang.captures[id]

                -- only look at nodes that have the language query
                if lang_name == "language" then
                    local regex_language = vim.treesitter.get_node_text(node, 0)
                    -- see if parser exists
                    local ok, result = pcall(vim.treesitter.require_language, regex_language, true)

                    -- if pcall was true we had parser, skip the rest
                    if ok and result then
                        goto continue
                    end

                    -- NOTE: the regex fallback code was mostly adapted from Vimwiki
                    -- It's a very good implementation of nested vim regex
                    regex_language = regex_language:gsub("%s+", "") -- need to trim out whitespace
                    local group = "textGroup" .. string.upper(regex_language)
                    local snip = "textSnip" .. string.upper(regex_language)
                    local start_marker = "@code " .. regex_language
                    local end_marker = "@end"
                    local has_syntax = "syntax list " .. snip

                    ok, result = pcall(vim.api.nvim_exec, has_syntax, true)
                    local count = select(2, result:gsub("\n", "\n")) -- get length of result from syn list
                    if ok == true and count > 0 then
                        goto continue
                    end

                    -- pass off the current syntax buffer var so things can load
                    local current_syntax = ""
                    if vim.b.current_syntax ~= "" or vim.b.current_syntax ~= nil then
                        vim.b.current_syntax = regex_language
                        current_syntax = vim.b.current_syntax
                        vim.b.current_syntax = nil
                    end

                    -- temporarily pass off keywords in case they get messed up
                    local is_keyword = vim.api.nvim_buf_get_option(0, "iskeyword")

                    -- see if the syntax files even exist before we try to call them
                    -- if syn list was an error, or if it was an empty result
                    if ok == false or (ok == true and (string.sub(result, 1, 1) == "N" or count == 0)) then
                        local output = vim.api.nvim_get_runtime_file("syntax/" .. regex_language .. ".vim", false)
                        if output[1] ~= nil then
                            local command = "syntax include @" .. group .. " " .. output[1]
                            vim.cmd(command)
                        end
                        output = vim.api.nvim_get_runtime_file("after/syntax/" .. regex_language .. ".vim", false)
                        if output[1] ~= nil then
                            local command = "syntax include @" .. group .. " " .. output[1]
                            vim.cmd(command)
                        end
                    end

                    vim.api.nvim_buf_set_option(0, "iskeyword", is_keyword)

                    -- reset it after
                    if current_syntax ~= "" or current_syntax ~= nil then
                        vim.b.current_syntax = current_syntax
                    else
                        vim.b.current_syntax = ""
                    end

                    -- set highlight groups
                    local regex_fallback_hl = "syntax region "
                        .. snip
                        .. ' matchgroup=Snip start="'
                        .. start_marker
                        .. "\" end='"
                        .. end_marker
                        .. "' contains=@"
                        .. group
                        .. " keepend"
                    vim.cmd(regex_fallback_hl)

                    -- resync syntax, fixes some slow loading
                    vim.cmd("syntax sync fromstart")
                    vim.b.current_syntax = ""
                end

                -- continue on from for loop if a language with parser is found or another syntax might be loaded
                ::continue::
            end
        end
    end,

    trigger_code_block_highlights = function(from)
        -- If the code block dimming is disabled, return right away.
        if not module.config.public.dim_code_blocks then
            return
        end

        module.public.clear_icons(module.private.code_block_namespace, from)

        -- The next block of code will be responsible for dimming code blocks accordingly
        local tree = vim.treesitter.get_parser(0, "norg"):parse()[1]

        -- If the tree is valid then attempt to perform the query
        if tree then
            -- Query all code blocks
            local ok, query = pcall(
                vim.treesitter.parse_query,
                "norg",
                [[(
                    (ranged_tag (tag_name) @_name) @tag
                    (#eq? @_name "code")
                )]]
            )

            -- If something went wrong then go bye bye
            if not ok or not query then
                return
            end

            -- Go through every found capture
            for id, node in query:iter_captures(tree:root(), 0, from or 0, -1) do
                local id_name = query.captures[id]

                -- If the capture name is "tag" then that means we're dealing with our ranged_tag;
                if id_name == "tag" then
                    -- Get the range of the code block
                    local range = module.required["core.integrations.treesitter"].get_node_range(node)

                    -- Go through every line in the code block and give it a magical highlight
                    for i = range.row_start, range.row_end >= vim.api.nvim_buf_line_count(0) and 0 or range.row_end, 1 do
                        local line = vim.api.nvim_buf_get_lines(0, i, i + 1, true)[1]

                        -- If our buffer is modifiable or if our line is too short then try to fill in the line
                        -- (this fixes broken syntax highlights automatically)
                        if vim.bo.modifiable and line:len() < range.column_start then
                            vim.api.nvim_buf_set_lines(0, i, i + 1, true, { string.rep(" ", range.column_start) })
                        end

                        -- If our line is valid and it's not too short then apply the dimmed highlight
                        if line and line:len() >= range.column_start then
                            module.public._set_extmark(
                                nil,
                                "NeorgCodeBlock",
                                module.private.code_block_namespace,
                                i,
                                i + 1,
                                range.column_start,
                                nil,
                                true,
                                "blend"
                            )
                        end
                    end
                end
            end
        end
    end,

    toggle_markup = function()
        if module.config.public.markup.enabled then
            module.public.clear_icons(module.private.markup_namespace)
            module.config.public.markup.enabled = false
        else
            module.config.public.markup.enabled = true
            module.public.trigger_icons(module.private.markup, module.private.markup_namespace)
        end
    end,

    -- @Summary Sets an extmark in the buffer
    -- @Description Mostly a wrapper around vim.api.nvim_buf_set_extmark in order to make it more safe
    -- @Param  text (string|table) - the virtual text to overlay (usually the icon)
    -- @Param  highlight (string) - the name of a highlight to use for the icon
    -- @Param  line_number (number) - the line number to apply the extmark in
    -- @Param  end_line (number) - the last line number to apply the extmark to (useful if you want an extmark to exist for more than one line)
    -- @Param  start_column (number) - the start column of the conceal
    -- @Param  end_column (number) - the end column of the conceal
    -- @Param  whole_line (boolean) - if true will highlight the whole line (like in diffs)
    -- @Param  mode (string: "replace"/"combine"/"blend") - the highlight mode for the extmark
    _set_extmark = function(text, highlight, ns, line_number, end_line, start_column, end_column, whole_line, mode)
        -- If the text type is a string then convert it into something that Neovim's extmark API can understand
        if type(text) == "string" then
            text = { { text, highlight } }
        end

        -- Attempt to call vim.api.nvim_buf_set_extmark with all the parameters
        local ok, result = pcall(vim.api.nvim_buf_set_extmark, 0, ns, line_number, start_column, {
            end_col = end_column,
            hl_group = highlight,
            end_line = end_line,
            virt_text = text or nil,
            virt_text_pos = "overlay",
            hl_mode = mode,
            hl_eol = whole_line,
        })

        -- If we have encountered an error then log it
        if not ok then
            log.error("Unable to create custom conceal for highlight:", highlight, "-", result)
        end
    end,

    -- @Summary Clears all the conceals that neorg has defined
    -- @Description Simply clears the Neorg extmark namespace
    -- @Param from (number) - the line number to start clearing from
    clear_icons = function(namespace, from, to)
        vim.api.nvim_buf_clear_namespace(0, namespace, from or 0, to or -1)
    end,

    trigger_completion_levels = function(from)
        from = from or 0

        module.public.clear_completion_levels(from)

        -- Get the root node of the document (required to iterate over query captures)
        local document_root = module.required["core.integrations.treesitter"].get_document_root()

        if not document_root then
            return
        end

        for _, query in ipairs(module.config.public.completion_level.queries) do
            local query_object = vim.treesitter.parse_query("norg", query.query)

            local nodes = {}
            local last_node

            local total, done, pending, undone, uncertain, urgent, recurring, onhold, cancelled =
                0, 0, 0, 0, 0, 0, 0, 0, 0

            for id, node in query_object:iter_captures(document_root, 0, from, -1) do
                local name = query_object.captures[id]

                if name == "progress" then
                    if last_node and node ~= last_node then
                        table.insert(nodes, {
                            node = last_node,
                            total = total,
                            done = done,
                            pending = pending,
                            undone = undone,
                            uncertain = uncertain,
                            urgen = urgent,
                            recurring = recurring,
                            onhold = onhold,
                            cancelled = cancelled,
                        })

                        total, done, pending, undone, uncertain, urgent, recurring, onhold, cancelled =
                            0, 0, 0, 0, 0, 0, 0, 0, 0
                    end

                    last_node = node
                elseif name == "done" then
                    done = done + 1
                    total = total + 1
                elseif name == "undone" then
                    undone = undone + 1
                    total = total + 1
                elseif name == "pending" then
                    pending = pending + 1
                    total = total + 1
                elseif name == "uncertain" then
                    uncertain = uncertain + 1
                    total = total + 1
                elseif name == "urgent" then
                    urgent = urgent + 1
                    total = total + 1
                elseif name == "recurring" then
                    recurring = recurring + 1
                    total = total + 1
                elseif name == "onhold" then
                    onhold = onhold + 1
                    total = total + 1
                elseif name == "cancelled" then
                    cancelled = cancelled + 1
                    -- total = total + 1
                end
            end

            if total > 0 then
                table.insert(nodes, {
                    node = last_node,
                    total = total,
                    done = done,
                    pending = pending,
                    undone = undone,
                    uncertain = uncertain,
                    urgent = urgent,
                    recurring = recurring,
                    onhold = onhold,
                    cancelled = cancelled,
                })

                for _, node_information in ipairs(nodes) do
                    if node_information.total > 0 then
                        local node_range = module.required["core.integrations.treesitter"].get_node_range(
                            node_information.node
                        )
                        local text = vim.deepcopy(query.text)

                        local function format_query_text(data)
                            data = data:gsub("<total>", tostring(node_information.total))
                            data = data:gsub("<done>", tostring(node_information.done))
                            data = data:gsub("<pending>", tostring(node_information.pending))
                            data = data:gsub("<undone>", tostring(node_information.undone))
                            data = data:gsub("<uncertain>", tostring(node_information.uncertain))
                            data = data:gsub("<urgent>", tostring(node_information.urgent))
                            data = data:gsub("<recurring>", tostring(node_information.recurring))
                            data = data:gsub("<onhold>", tostring(node_information.onhold))
                            data = data:gsub("<cancelled>", tostring(node_information.cancelled))
                            data = data:gsub(
                                "<percentage>",
                                tostring(math.floor(node_information.done / node_information.total * 100))
                            )

                            return data
                        end

                        -- Format query text
                        if type(text) == "string" then
                            text = format_query_text(text)
                        else
                            for _, tbl in ipairs(text) do
                                tbl[1] = format_query_text(tbl[1])

                                tbl[2] = tbl[2] or query.highlight
                            end
                        end

                        vim.api.nvim_buf_set_extmark(
                            0,
                            module.private.completion_level_namespace,
                            node_range.row_start,
                            -1,
                            {
                                virt_text = type(text) == "string" and { { text, query.highlight } } or text,
                                priority = 250,
                                hl_mode = "combine",
                            }
                        )
                    end
                end
            end
        end
    end,

    clear_completion_levels = function(from)
        vim.api.nvim_buf_clear_namespace(0, module.private.completion_level_namespace, from or 0, -1)
    end,

    -- VARIABLES
    concealing = {
        ordered = {
            get_index = function(node, level)
                local sibling = node:parent():prev_named_sibling()
                local count = 1

                while sibling and sibling:type() == level do
                    sibling = sibling:prev_named_sibling()
                    count = count + 1
                end

                return count
            end,

            enumerator = {
                numeric = function(count)
                    return tostring(count)
                end,

                latin_lowercase = function(count)
                    return string.char(96 + count)
                end,

                latin_uppercase = function(count)
                    return string.char(64 + count)
                end,

                -- NOTE: only supports number up to 12
                roman_lowercase = function(count)
                    local chars = {
                        [1] = "ⅰ",
                        [2] = "ⅱ",
                        [3] = "ⅲ",
                        [4] = "ⅳ",
                        [5] = "ⅴ",
                        [6] = "ⅵ",
                        [7] = "ⅶ",
                        [8] = "ⅷ",
                        [9] = "ⅸ",
                        [10] = "ⅹ",
                        [11] = "ⅺ",
                        [12] = "ⅻ",
                        [50] = "ⅼ",
                        [100] = "ⅽ",
                        [500] = "ⅾ",
                        [1000] = "ⅿ",
                    }
                    return chars[count]
                end,

                -- NOTE: only supports number up to 12
                roman_uppwercase = function(count)
                    local chars = {
                        [1] = "Ⅰ",
                        [2] = "Ⅱ",
                        [3] = "Ⅲ",
                        [4] = "Ⅳ",
                        [5] = "Ⅴ",
                        [6] = "Ⅵ",
                        [7] = "Ⅶ",
                        [8] = "Ⅷ",
                        [9] = "Ⅸ",
                        [10] = "Ⅹ",
                        [11] = "Ⅺ",
                        [12] = "Ⅻ",
                        [50] = "Ⅼ",
                        [100] = "Ⅽ",
                        [500] = "Ⅾ",
                        [1000] = "Ⅿ",
                    }
                    return chars[count]
                end,
            },

            punctuation = {
                dot = function(renderer)
                    return function(count)
                        return renderer(count) .. "."
                    end
                end,

                parenthesis = function(renderer)
                    return function(count)
                        return renderer(count) .. ")"
                    end
                end,

                double_parenthesis = function(renderer)
                    return function(count)
                        return "(" .. renderer(count) .. ")"
                    end
                end,

                -- NOTE: only supports arabic numbers up to 20
                unicode_dot = function(renderer)
                    return function(count)
                        local chars = {
                            ["1"] = "⒈",
                            ["2"] = "⒉",
                            ["3"] = "⒊",
                            ["4"] = "⒋",
                            ["5"] = "⒌",
                            ["6"] = "⒍",
                            ["7"] = "⒎",
                            ["8"] = "⒏",
                            ["9"] = "⒐",
                            ["10"] = "⒑",
                            ["11"] = "⒒",
                            ["12"] = "⒓",
                            ["13"] = "⒔",
                            ["14"] = "⒕",
                            ["15"] = "⒖",
                            ["16"] = "⒗",
                            ["17"] = "⒘",
                            ["18"] = "⒙",
                            ["19"] = "⒚",
                            ["20"] = "⒛",
                        }
                        return chars[renderer(count)]
                    end
                end,

                -- NOTE: only supports arabic numbers up to 20 or lowercase latin characters
                unicode_double_parenthesis = function(renderer)
                    return function(count)
                        local chars = {
                            ["1"] = "⑴",
                            ["2"] = "⑵",
                            ["3"] = "⑶",
                            ["4"] = "⑷",
                            ["5"] = "⑸",
                            ["6"] = "⑹",
                            ["7"] = "⑺",
                            ["8"] = "⑻",
                            ["9"] = "⑼",
                            ["10"] = "⑽",
                            ["11"] = "⑾",
                            ["12"] = "⑿",
                            ["13"] = "⒀",
                            ["14"] = "⒁",
                            ["15"] = "⒂",
                            ["16"] = "⒃",
                            ["17"] = "⒄",
                            ["18"] = "⒅",
                            ["19"] = "⒆",
                            ["20"] = "⒇",
                            ["a"] = "⒜",
                            ["b"] = "⒝",
                            ["c"] = "⒞",
                            ["d"] = "⒟",
                            ["e"] = "⒠",
                            ["f"] = "⒡",
                            ["g"] = "⒢",
                            ["h"] = "⒣",
                            ["i"] = "⒤",
                            ["j"] = "⒥",
                            ["k"] = "⒦",
                            ["l"] = "⒧",
                            ["m"] = "⒨",
                            ["n"] = "⒩",
                            ["o"] = "⒪",
                            ["p"] = "⒫",
                            ["q"] = "⒬",
                            ["r"] = "⒭",
                            ["s"] = "⒮",
                            ["t"] = "⒯",
                            ["u"] = "⒰",
                            ["v"] = "⒱",
                            ["w"] = "⒲",
                            ["x"] = "⒳",
                            ["y"] = "⒴",
                            ["z"] = "⒵",
                        }
                        return chars[renderer(count)]
                    end
                end,

                -- NOTE: only supports arabic numbers up to 20 or latin characters
                unicode_circle = function(renderer)
                    return function(count)
                        local chars = {
                            ["1"] = "①",
                            ["2"] = "②",
                            ["3"] = "③",
                            ["4"] = "④",
                            ["5"] = "⑤",
                            ["6"] = "⑥",
                            ["7"] = "⑦",
                            ["8"] = "⑧",
                            ["9"] = "⑨",
                            ["10"] = "⑩",
                            ["11"] = "⑪",
                            ["12"] = "⑫",
                            ["13"] = "⑬",
                            ["14"] = "⑭",
                            ["15"] = "⑮",
                            ["16"] = "⑯",
                            ["17"] = "⑰",
                            ["18"] = "⑱",
                            ["19"] = "⑲",
                            ["20"] = "⑳",
                            ["A"] = "Ⓐ",
                            ["B"] = "Ⓑ",
                            ["C"] = "Ⓒ",
                            ["D"] = "Ⓓ",
                            ["E"] = "Ⓔ",
                            ["F"] = "Ⓕ",
                            ["G"] = "Ⓖ",
                            ["H"] = "Ⓗ",
                            ["I"] = "Ⓘ",
                            ["J"] = "Ⓙ",
                            ["K"] = "Ⓚ",
                            ["L"] = "Ⓛ",
                            ["M"] = "Ⓜ",
                            ["N"] = "Ⓝ",
                            ["O"] = "Ⓞ",
                            ["P"] = "Ⓟ",
                            ["Q"] = "Ⓠ",
                            ["R"] = "Ⓡ",
                            ["S"] = "Ⓢ",
                            ["T"] = "Ⓣ",
                            ["U"] = "Ⓤ",
                            ["V"] = "Ⓥ",
                            ["W"] = "Ⓦ",
                            ["X"] = "Ⓧ",
                            ["Y"] = "Ⓨ",
                            ["Z"] = "Ⓩ",
                            ["a"] = "ⓐ",
                            ["b"] = "ⓑ",
                            ["c"] = "ⓒ",
                            ["d"] = "ⓓ",
                            ["e"] = "ⓔ",
                            ["f"] = "ⓕ",
                            ["g"] = "ⓖ",
                            ["h"] = "ⓗ",
                            ["i"] = "ⓘ",
                            ["j"] = "ⓙ",
                            ["k"] = "ⓚ",
                            ["l"] = "ⓛ",
                            ["m"] = "ⓜ",
                            ["n"] = "ⓝ",
                            ["o"] = "ⓞ",
                            ["p"] = "ⓟ",
                            ["q"] = "ⓠ",
                            ["r"] = "ⓡ",
                            ["s"] = "ⓢ",
                            ["t"] = "ⓣ",
                            ["u"] = "ⓤ",
                            ["v"] = "ⓥ",
                            ["w"] = "ⓦ",
                            ["x"] = "ⓧ",
                            ["y"] = "ⓨ",
                            ["z"] = "ⓩ",
                        }
                        return chars[renderer(count)]
                    end
                end,
            },
        },
    },

    foldtext = function()
        local foldstart = vim.v.foldstart
        local line = vim.api.nvim_buf_get_lines(0, foldstart - 1, foldstart, true)[1]
        local line_length = vim.api.nvim_strwidth(line)

        local icon_extmarks = vim.api.nvim_buf_get_extmarks(
            0,
            module.private.icon_namespace,
            { foldstart - 1, 0 },
            { foldstart - 1, line_length },
            {
                details = true,
            }
        )

        for _, extmark in ipairs(icon_extmarks) do
            local extmark_details = extmark[4]
            local extmark_column = extmark[3] + (line_length - line:len())

            for _, virt_text in ipairs(extmark_details.virt_text or {}) do
                line = line:sub(1, extmark_column)
                    .. virt_text[1]
                    .. line:sub(extmark_column + vim.api.nvim_strwidth(virt_text[1]) + 1)
                line_length = vim.api.nvim_strwidth(line) - line_length + vim.api.nvim_strwidth(virt_text[1])
            end
        end

        local completion_extmarks = vim.api.nvim_buf_get_extmarks(
            0,
            module.private.completion_level_namespace,
            { foldstart - 1, 0 },
            { foldstart - 1, vim.api.nvim_strwidth(line) },
            {
                details = true,
            }
        )

        if not vim.tbl_isempty(completion_extmarks) then
            line = line .. " "

            for _, extmark in ipairs(completion_extmarks) do
                for _, virt_text in ipairs(extmark[4].virt_text or {}) do
                    line = line .. virt_text[1]
                end
            end
        end

        return line
    end,
}

module.config.public = {
    icon_preset = "basic",

    icons = {
        todo = {
            enabled = true,

            done = {
                enabled = true,
                icon = "",
                highlight = "NeorgTodoItemDoneMark",
                query = "(todo_item_done) @icon",
                extract = function()
                    return 1
                end,
            },

            pending = {
                enabled = true,
                icon = "",
                highlight = "NeorgTodoItemPendingMark",
                query = "(todo_item_pending) @icon",
                extract = function()
                    return 1
                end,
            },

            undone = {
                enabled = true,
                icon = "×",
                highlight = "NeorgTodoItemUndoneMark",
                query = "(todo_item_undone) @icon",
                extract = function()
                    return 1
                end,
            },

            uncertain = {
                enabled = true,
                icon = "",
                highlight = "NeorgTodoItemUncertainMark",
                query = "(todo_item_uncertain) @icon",
                extract = function()
                    return 1
                end,
            },

            on_hold = {
                enabled = true,
                icon = "",
                highlight = "NeorgTodoItemOnHoldMark",
                query = "(todo_item_on_hold) @icon",
                extract = function()
                    return 1
                end,
            },

            cancelled = {
                enabled = true,
                icon = "",
                highlight = "NeorgTodoItemCancelledMark",
                query = "(todo_item_cancelled) @icon",
                extract = function()
                    return 1
                end,
            },

            recurring = {
                enabled = true,
                icon = "⟳",
                highlight = "NeorgTodoItemRecurringMark",
                query = "(todo_item_recurring) @icon",
                extract = function()
                    return 1
                end,
            },

            urgent = {
                enabled = true,
                icon = "⚠",
                highlight = "NeorgTodoItemUrgentMark",
                query = "(todo_item_urgent) @icon",
                extract = function()
                    return 1
                end,
            },
        },

        list = {
            enabled = true,

            level_1 = {
                enabled = true,
                icon = "•",
                highlight = "NeorgUnorderedList1",
                query = "(unordered_list1_prefix) @icon",
            },

            level_2 = {
                enabled = true,
                icon = " •",
                highlight = "NeorgUnorderedList2",
                query = "(unordered_list2_prefix) @icon",
            },

            level_3 = {
                enabled = true,
                icon = "  •",
                highlight = "NeorgUnorderedList3",
                query = "(unordered_list3_prefix) @icon",
            },

            level_4 = {
                enabled = true,
                icon = "   •",
                highlight = "NeorgUnorderedList4",
                query = "(unordered_list4_prefix) @icon",
            },

            level_5 = {
                enabled = true,
                icon = "    •",
                highlight = "NeorgUnorderedList5",
                query = "(unordered_list5_prefix) @icon",
            },

            level_6 = {
                enabled = true,
                icon = "     •",
                highlight = "NeorgUnorderedList6",
                query = "(unordered_list6_prefix) @icon",
            },
        },

        link = {
            enabled = true,
            level_1 = {
                enabled = true,
                icon = " ",
                highlight = "NeorgUnorderedLink1",
                query = "(unordered_link1_prefix) @icon",
            },
            level_2 = {
                enabled = true,
                icon = "  ",
                highlight = "NeorgUnorderedLink2",
                query = "(unordered_link2_prefix) @icon",
            },
            level_3 = {
                enabled = true,
                icon = "   ",
                highlight = "NeorgUnorderedLink3",
                query = "(unordered_link3_prefix) @icon",
            },
            level_4 = {
                enabled = true,
                icon = "    ",
                highlight = "NeorgUnorderedLink4",
                query = "(unordered_link4_prefix) @icon",
            },
            level_5 = {
                enabled = true,
                icon = "     ",
                highlight = "NeorgUnorderedLink5",
                query = "(unordered_link5_prefix) @icon",
            },
            level_6 = {
                enabled = true,
                icon = "      ",
                highlight = "NeorgUnorderedLink6",
                query = "(unordered_link6_prefix) @icon",
            },
        },

        ordered = {
            enabled = require("neorg.external.helpers").is_minimum_version(0, 6, 0),

            --[[
Once anticonceal (https://github.com/neovim/neovim/pull/9496) is
a thing, punctuation can be added (without removing the whitespace
between the icon and actual text) like so:

```lua
icon = module.private.ordered_concealing.punctuation.dot(
module.private.ordered_concealing.icon_renderer.numeric
),
```

Note: this will produce icons like `1.`, `2.`, etc.

You can even chain multiple punctuation wrappers like so:

```lua
icon = module.private.ordered_concealing.punctuation.parenthesis(
module.private.ordered_concealing.punctuation.dot(
module.private.ordered_concealing.icon_renderer.numeric
)
),
```

Note: this will produce icons like `1.)`, `2.)`, etc.
--]]

            level_1 = {
                enabled = true,
                icon = module.public.concealing.ordered.punctuation.unicode_dot(
                    module.public.concealing.ordered.enumerator.numeric
                ),
                highlight = "NeorgOrderedList1",
                query = "(ordered_list1_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_list1")
                    return {
                        { self.icon(count), self.highlight },
                    }
                end,
            },

            level_2 = {
                enabled = true,
                icon = module.public.concealing.ordered.enumerator.latin_uppercase,
                highlight = "NeorgOrderedList2",
                query = "(ordered_list2_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_list2")
                    return {
                        { " " .. self.icon(count), self.highlight },
                    }
                end,
            },

            level_3 = {
                enabled = true,
                icon = module.public.concealing.ordered.enumerator.latin_lowercase,
                highlight = "NeorgOrderedList3",
                query = "(ordered_list3_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_list3")
                    return {
                        { "  " .. self.icon(count), self.highlight },
                    }
                end,
            },

            level_4 = {
                enabled = true,
                icon = module.public.concealing.ordered.punctuation.unicode_double_parenthesis(
                    module.public.concealing.ordered.enumerator.numeric
                ),
                highlight = "NeorgOrderedList4",
                query = "(ordered_list4_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_list4")
                    return {
                        { "   " .. self.icon(count), self.highlight },
                    }
                end,
            },

            level_5 = {
                enabled = true,
                icon = module.public.concealing.ordered.enumerator.latin_uppercase,
                highlight = "NeorgOrderedList5",
                query = "(ordered_list5_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_list5")
                    return {
                        { "    " .. self.icon(count), self.highlight },
                    }
                end,
            },

            level_6 = {
                enabled = true,
                icon = module.public.concealing.ordered.punctuation.unicode_double_parenthesis(
                    module.public.concealing.ordered.enumerator.latin_lowercase
                ),
                highlight = "NeorgOrderedList6",
                query = "(ordered_list6_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_list6")
                    return {
                        { "     " .. self.icon(count), self.highlight },
                    }
                end,
            },
        },

        ordered_link = {
            enabled = true,
            level_1 = {
                enabled = true,
                icon = module.public.concealing.ordered.punctuation.unicode_circle(
                    module.public.concealing.ordered.enumerator.numeric
                ),
                highlight = "NeorgOrderedLink1",
                query = "(ordered_link1_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_link1")
                    return {
                        { " " .. self.icon(count), self.highlight },
                    }
                end,
            },
            level_2 = {
                enabled = true,
                icon = module.public.concealing.ordered.punctuation.unicode_circle(
                    module.public.concealing.ordered.enumerator.latin_uppercase
                ),
                highlight = "NeorgOrderedLink2",
                query = "(ordered_link2_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_link2")
                    return {
                        { "  " .. self.icon(count), self.highlight },
                    }
                end,
            },
            level_3 = {
                enabled = true,
                icon = module.public.concealing.ordered.punctuation.unicode_circle(
                    module.public.concealing.ordered.enumerator.latin_lowercase
                ),
                highlight = "NeorgOrderedLink3",
                query = "(ordered_link3_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_link3")
                    return {
                        { "   " .. self.icon(count), self.highlight },
                    }
                end,
            },
            level_4 = {
                enabled = true,
                icon = module.public.concealing.ordered.punctuation.unicode_circle(
                    module.public.concealing.ordered.enumerator.numeric
                ),
                highlight = "NeorgOrderedLink4",
                query = "(ordered_link4_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_link4")
                    return {
                        { "    " .. self.icon(count), self.highlight },
                    }
                end,
            },
            level_5 = {
                enabled = true,
                icon = module.public.concealing.ordered.punctuation.unicode_circle(
                    module.public.concealing.ordered.enumerator.latin_uppercase
                ),
                highlight = "NeorgOrderedLink5",
                query = "(ordered_link5_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_link5")
                    return {
                        { "     " .. self.icon(count), self.highlight },
                    }
                end,
            },
            level_6 = {
                enabled = true,
                icon = module.public.concealing.ordered.punctuation.unicode_circle(
                    module.public.concealing.ordered.enumerator.latin_lowercase
                ),
                highlight = "NeorgOrderedLink6",
                query = "(ordered_link6_prefix) @icon",
                render = function(self, _, node)
                    local count = module.public.concealing.ordered.get_index(node, "ordered_link6")
                    return {
                        { "      " .. self.icon(count), self.highlight },
                    }
                end,
            },
        },

        quote = {
            enabled = true,

            level_1 = {
                enabled = true,
                icon = "│",
                highlight = "NeorgQuote1",
                query = "(quote1_prefix) @icon",
            },

            level_2 = {
                enabled = true,
                icon = "│",
                highlight = "NeorgQuote2",
                query = "(quote2_prefix) @icon",
                render = function(self)
                    return {
                        { self.icon, module.config.public.icons.quote.level_1.highlight },
                        { self.icon, self.highlight },
                    }
                end,
            },

            level_3 = {
                enabled = true,
                icon = "│",
                highlight = "NeorgQuote3",
                query = "(quote3_prefix) @icon",
                render = function(self)
                    return {
                        { self.icon, module.config.public.icons.quote.level_1.highlight },
                        { self.icon, module.config.public.icons.quote.level_2.highlight },
                        { self.icon, self.highlight },
                    }
                end,
            },

            level_4 = {
                enabled = true,
                icon = "│",
                highlight = "NeorgQuote4",
                query = "(quote4_prefix) @icon",
                render = function(self)
                    return {
                        { self.icon, module.config.public.icons.quote.level_1.highlight },
                        { self.icon, module.config.public.icons.quote.level_2.highlight },
                        { self.icon, module.config.public.icons.quote.level_3.highlight },
                        { self.icon, self.highlight },
                    }
                end,
            },

            level_5 = {
                enabled = true,
                icon = "│",
                highlight = "NeorgQuote5",
                query = "(quote5_prefix) @icon",
                render = function(self)
                    return {
                        { self.icon, module.config.public.icons.quote.level_1.highlight },
                        { self.icon, module.config.public.icons.quote.level_2.highlight },
                        { self.icon, module.config.public.icons.quote.level_3.highlight },
                        { self.icon, module.config.public.icons.quote.level_4.highlight },
                        { self.icon, self.highlight },
                    }
                end,
            },

            level_6 = {
                enabled = true,
                icon = "│",
                highlight = "NeorgQuote6",
                query = "(quote6_prefix) @icon",
                render = function(self)
                    return {
                        { self.icon, module.config.public.icons.quote.level_1.highlight },
                        { self.icon, module.config.public.icons.quote.level_2.highlight },
                        { self.icon, module.config.public.icons.quote.level_3.highlight },
                        { self.icon, module.config.public.icons.quote.level_4.highlight },
                        { self.icon, module.config.public.icons.quote.level_5.highlight },
                        { self.icon, self.highlight },
                    }
                end,
            },
        },

        heading = {
            enabled = true,

            level_1 = {
                enabled = true,
                icon = "◉",
                highlight = "NeorgHeading1",
                query = "(heading1_prefix) @icon",
            },

            level_2 = {
                enabled = true,
                icon = " ◎",
                highlight = "NeorgHeading2",
                query = "(heading2_prefix) @icon",
            },

            level_3 = {
                enabled = true,
                icon = "  ○",
                highlight = "NeorgHeading3",
                query = "(heading3_prefix) @icon",
            },

            level_4 = {
                enabled = true,
                icon = "   ✺",
                highlight = "NeorgHeading4",
                query = "(heading4_prefix) @icon",
            },

            level_5 = {
                enabled = true,
                icon = "    ▶",
                highlight = "NeorgHeading5",
                query = "(heading5_prefix) @icon",
            },

            level_6 = {
                enabled = true,
                icon = "     ⤷",
                highlight = "NeorgHeading6",
                query = "(heading6_prefix) @icon",
                render = function(self, text)
                    return {
                        {
                            string.rep(" ", text:len() - string.len("******") - string.len(" ")) .. self.icon,
                            self.highlight,
                        },
                    }
                end,
            },
        },

        marker = {
            enabled = true,
            icon = "",
            highlight = "NeorgMarker",
            query = "(marker_prefix) @icon",
        },

        definition = {
            enabled = true,

            single = {
                enabled = true,
                icon = "≡",
                highlight = "NeorgDefinition",
                query = "(single_definition_prefix) @icon",
            },
            multi_prefix = {
                enabled = true,
                icon = "⋙ ",
                highlight = "NeorgDefinition",
                query = "(multi_definition_prefix) @icon",
            },
            multi_suffix = {
                enabled = true,
                icon = "⋘ ",
                highlight = "NeorgDefinition",
                query = "(multi_definition_suffix) @icon",
            },
        },

        delimiter = {
            enabled = true,

            weak = {
                enabled = true,
                icon = "⟨",
                highlight = "NeorgWeakParagraphDelimiter",
                query = "(weak_paragraph_delimiter) @icon",
                render = function(self, text)
                    return {
                        { string.rep(self.icon, text:len()), self.highlight },
                    }
                end,
            },

            strong = {
                enabled = true,
                icon = "⟪",
                highlight = "NeorgStrongParagraphDelimiter",
                query = "(strong_paragraph_delimiter) @icon",
                render = function(self, text)
                    return {
                        { string.rep(self.icon, text:len()), self.highlight },
                    }
                end,
            },

            horizontal_line = {
                enabled = true,
                icon = "─",
                highlight = "NeorgHorizontalLine",
                query = "(horizontal_line) @icon",
                render = function(self, _, node)
                    -- Get the length of the Neovim window (used to render to the edge of the screen)
                    local resulting_length = vim.api.nvim_win_get_width(0)

                    -- If we are running at least 0.6 (which has the prev_sibling() function) then
                    if require("neorg.external.helpers").is_minimum_version(0, 6, 0) then
                        -- Grab the sibling before our current node in order to later
                        -- determine how much space it occupies in the buffer vertically
                        local prev_sibling = node:prev_sibling()
                        local double_prev_sibling = prev_sibling:prev_sibling()
                        local ts = module.required["core.integrations.treesitter"].get_ts_utils()

                        if prev_sibling then
                            -- Get the text of the previous sibling and store its longest line width-wise
                            local text = ts.get_node_text(prev_sibling)
                            local longest = 3

                            if
                                prev_sibling:parent()
                                and double_prev_sibling
                                and double_prev_sibling:type() == "marker_prefix"
                            then
                                local range_of_prefix = module.required["core.integrations.treesitter"].get_node_range(
                                    double_prev_sibling
                                )
                                local range_of_title = module.required["core.integrations.treesitter"].get_node_range(
                                    prev_sibling
                                )
                                resulting_length = (range_of_prefix.column_end - range_of_prefix.column_start)
                                    + (range_of_title.column_end - range_of_title.column_start)
                            else
                                -- Go through each line and remove its surrounding whitespace,
                                -- we do this because some inconsistencies tend to occur with
                                -- the way whitespace is handled.
                                for _, line in ipairs(text) do
                                    line = vim.trim(line)

                                    -- If the line even has any "normal" characters
                                    -- and its length is a new record then update the
                                    -- `longest` variable
                                    if line:match("%w") and line:len() > longest then
                                        longest = line:len()
                                    end
                                end
                            end

                            -- If we've set a longest value then override the resulting length
                            -- with that longest value (to make it render only up until that point)
                            if longest > 0 then
                                resulting_length = longest
                            end
                        end
                    end

                    return {
                        {
                            string.rep(self.icon, resulting_length),
                            self.highlight,
                        },
                    }
                end,
            },
        },
    },

    markup_preset = "safe",

    markup = {
        enabled = true,
        icon = " ",

        bold = {
            enabled = true,
            highlight = "NeorgMarkupBold",
            query = '(bold (["_open" "_close"]) @icon)',
        },

        italic = {
            enabled = true,
            highlight = "NeorgMarkupItalic",
            query = '(italic (["_open" "_close"]) @icon)',
        },

        underline = {
            enabled = true,
            highlight = "NeorgMarkupUnderline",
            query = '(underline (["_open" "_close"]) @icon)',
        },

        strikethrough = {
            enabled = true,
            highlight = "NeorgMarkupStrikethrough",
            query = '(strikethrough (["_open" "_close"]) @icon)',
        },

        subscript = {
            enabled = true,
            highlight = "NeorgMarkupSubscript",
            query = '(subscript (["_open" "_close"]) @icon)',
        },

        superscript = {
            enabled = true,
            highlight = "NeorgMarkupSuperscript",
            query = '(superscript (["_open" "_close"]) @icon)',
        },

        verbatim = {
            enabled = true,
            highlight = "NeorgMarkupVerbatim",
            query = '(verbatim (["_open" "_close"]) @icon)',
        },

        comment = {
            enabled = true,
            highlight = "NeorgMarkupInlineComment",
            query = '(inline_comment (["_open" "_close"]) @icon)',
        },

        math = {
            enabled = true,
            highlight = "NeorgMarkupInlineMath",
            query = '(inline_math (["_open" "_close"]) @icon)',
        },

        variable = {
            enabled = true,
            highlight = "NeorgMarkupVariable",
            query = '(variable (["_open" "_close"]) @icon)',
        },

        spoiler = {
            enabled = true,
            icon = "●",
            -- NOTE: as you can see, you can still overwrite the parent-icon
            -- inherited from above.
            highlight = "NeorgSpoiler",
            query = "(spoiler) @icon",
            render = function(self, text, node)
                return {
                    { string.rep(self.icon, #text), self.highlight },
                }
            end,
        },

        link_modifier = {
            enabled = true,
            highlight = "NeorgLinkModifier",
            query = "(link_modifier) @icon",
        },

        trailing_modifier = {
            enabled = true,
            highlight = "NeorgTrailingModifier",
            query = '("_trailing_modifier") @icon',
        },

        url = {
            enabled = true,

            link = {
                enabled = true,

                unnamed = {
                    enabled = true,
                    highlight = "NeorgLinkLocationDelimiter",
                    query = [[
                    (link
                        (link_location
                            (["_begin" "_end"]) @icon
                        )
                        .
                    )
                    ]],
                },

                named = {
                    enabled = true,

                    location = {
                        enabled = true,
                        highlight = "NeorgLinkLocationDelimiter",
                        query = [[
                            (link
                                (link_location) @icon
                                (link_description)
                            )
                        ]],
                        render = function(self, text)
                            return {
                                { string.rep(self.icon, #text), self.highlight },
                            }
                        end,
                    },

                    text = {
                        enabled = true,
                        highlight = "NeorgLinkTextDelimiter",
                        query = [[
                            (link
                                (link_description (["_begin" "_end"]) @icon)
                            )
                        ]],
                    },
                },
            },

            anchor = {
                enabled = true,

                declaration = {
                    enabled = true,
                    highlight = "NeorgAnchorDeclarationDelimiter",
                    query = [[
                    (anchor_declaration
                        (link_description
                            (["_begin" "_end"]) @icon
                        )
                    )
                    ]],
                },

                definition = {
                    enabled = true,

                    description = {
                        enabled = true,
                        highlight = "NeorgAnchorDeclarationDelimiter",
                        query = [[(
                            (link_description
                                (["_begin" "_end"]) @icon
                            ) @_description
                            (#has-parent? @_description "anchor_definition")
                        )]],
                        -- NOTE: right now this is a duplicate of the above but
                        -- we could envision concealing these two scenarios
                        -- differently.
                    },

                    location = {
                        enabled = true,
                        highlight = "NeorgAnchorDefinitionDelimiter",
                        query = [[
                        (anchor_definition
                            (link_location) @icon
                        )
                        ]],
                        render = function(self, text)
                            return {
                                { string.rep(self.icon, #text), self.highlight },
                            }
                        end,
                    },
                },
            },
        },
    },

    dim_code_blocks = true,

    folds = {
        enable = true,
        foldlevel = 999,
    },

    completion_level = {
        enabled = true,

        queries = {
            {
                query = string.format(
                    [[
                        [
                            (heading1
                                content: (_)*
                                content: [
                                    %s
                                    (carryover_tag_set
                                        (carryover_tag)
                                        target: %s
                                    )
                                ]
                            )
                            (heading2
                                content: (_)*
                                content: [
                                    %s
                                    (carryover_tag_set
                                        (carryover_tag)
                                        target: %s
                                    )
                                ]
                            )
                            (heading3
                                content: (_)*
                                content: [
                                    %s
                                    (carryover_tag_set
                                        (carryover_tag)
                                        target: %s
                                    )
                                ]
                            )
                            (heading4
                                content: (_)*
                                content: [
                                    %s
                                    (carryover_tag_set
                                        (carryover_tag)
                                        target: %s
                                    )
                                ]
                            )
                            (heading5
                                content: (_)*
                                content: [
                                    %s
                                    (carryover_tag_set
                                        (carryover_tag)
                                        target: %s
                                    )
                                ]
                            )
                            (heading6
                                content: (_)*
                                content: [
                                    %s
                                    (carryover_tag_set
                                        (carryover_tag)
                                        target: %s
                                    )
                                ]
                            )
                        ] @progress
                ]],
                    neorg.lib.reparg(module.private.todo_list_query, 6 * 2)
                ),
                text = module.private.completion_level_base,
                highlight = "DiagnosticVirtualTextHint",
            },
            {
                query = string.format(
                    [[
                    [
                        (todo_item1
                            %s
                        )
                    ] @progress
                ]],
                    module.private.any_todo_item(2)
                ),
                text = "[<done>/<total>]",
                highlight = "DiagnosticVirtualTextHint",
            },
            {
                query = string.format(
                    [[
                    [
                        (todo_item2
                            %s
                        )
                    ] @progress
                ]],
                    module.private.any_todo_item(3)
                ),
                text = "[<done>/<total>]",
                highlight = "DiagnosticVirtualTextHint",
            },
            {
                query = string.format(
                    [[
                    [
                        (todo_item3
                            %s
                        )
                    ] @progress
                ]],
                    module.private.any_todo_item(4)
                ),
                text = "[<done>/<total>]",
                highlight = "DiagnosticVirtualTextHint",
            },
            {
                query = string.format(
                    [[
                    [
                        (todo_item4
                            %s
                        )
                    ] @progress
                ]],
                    module.private.any_todo_item(5)
                ),
                text = "[<done>/<total>]",
                highlight = "DiagnosticVirtualTextHint",
            },
            {
                query = string.format(
                    [[
                    [
                        (todo_item5
                            %s
                        )
                    ] @progress
                ]],
                    module.private.any_todo_item(6)
                ),
                text = "[<done>/<total>]",
                highlight = "DiagnosticVirtualTextHint",
            },
        },
    },
}

module.load = function()
    if not module.config.private["icon_preset_" .. module.config.public.icon_preset] then
        log.error(
            string.format(
                "Unable to load icon preset '%s' - such a preset does not exist",
                module.config.public.icon_preset
            )
        )
        return
    end

    module.config.public.icons = vim.tbl_deep_extend(
        "force",
        module.config.public.icons,
        module.config.private["icon_preset_" .. module.config.public.icon_preset] or {},
        module.config.custom
    )

    if not module.config.private["markup_preset_" .. module.config.public.markup_preset] then
        log.error(
            string.format(
                "Unable to load markup preset '%s' - such a preset does not exist",
                module.config.public.markup_preset
            )
        )
        return
    end

    module.config.public.markup = vim.tbl_deep_extend(
        "force",
        module.config.public.markup,
        module.config.private["markup_preset_" .. module.config.public.markup_preset] or {},
        module.config.custom
    )

    -- @Summary Returns all the enabled icons from a table
    -- @Param  tbl (table) - the table to parse
    -- @Param parent_icon (string) - Is used to pass icons from parents down to their table children to handle inheritance.
    -- @Param rec_name (string) - should not be set manually. Is used for Neorg to have information about all other previous recursions
    local function get_enabled_icons(tbl, parent_icon, rec_name)
        rec_name = rec_name or ""

        -- Create a result that we will return at the end of the function
        local result = {}

        -- If the current table isn't enabled then don't parser any further - simply return the empty result
        if vim.tbl_isempty(tbl) or (tbl.enabled ~= nil and tbl.enabled == false) then
            return result
        end

        -- Go through every icon
        for name, icons in pairs(tbl) do
            -- If we're dealing with a table (which we should be) and if the current icon set is enabled then
            if type(icons) == "table" and icons.enabled then
                -- If we have defined a query value then add that icon to the result
                if icons.query then
                    result[rec_name .. name] = icons
                    if icons.icon == nil then
                        result[rec_name .. name].icon = parent_icon
                    end
                else
                    -- If we don't have an icon variable then we need to descend further down the lua table.
                    -- To do this we recursively call this very function and merge the results into the result table
                    result = vim.tbl_deep_extend(
                        "force",
                        result,
                        get_enabled_icons(icons, parent_icon, rec_name .. name)
                    )
                end
            end
        end

        return result
    end

    -- Set the module.private.icons variable to the values of the enabled icons
    module.private.icons = vim.tbl_values(get_enabled_icons(module.config.public.icons))
    module.private.markup = vim.tbl_values(
        get_enabled_icons(module.config.public.markup, module.config.public.markup.icon)
    )

    -- Register keybinds
    module.required["core.keybinds"].register_keybinds(module.name, { "toggle-markup" })

    -- Enable the required autocommands (these will be used to determine when to update conceals in the buffer)
    module.required["core.autocommands"].enable_autocommand("BufEnter")

    module.required["core.autocommands"].enable_autocommand("InsertEnter")
    module.required["core.autocommands"].enable_autocommand("InsertLeave")
end

module.on_event = function(event)
    if event.type == "core.autocommands.events.bufenter" and event.content.norg then
        local buf = event.buffer
        local line_count = vim.api.nvim_buf_line_count(buf)

        module.public.trigger_icons(module.private.icons, module.private.icon_namespace)

        vim.api.nvim_buf_attach(buf, false, {
            on_lines = function(_, _, _, start, _end)
                if buf ~= vim.api.nvim_get_current_buf() then
                    return true
                end

                module.private.last_change.active = true

                vim.schedule(function()
                    local mode = vim.api.nvim_get_mode().mode

                    if mode == "n" or mode == "no" then
                        local new_line_count = vim.api.nvim_buf_line_count(buf)

                        -- Sometimes occurs with one-line undos
                        if start == _end then
                            _end = _end + 1
                        end

                        if new_line_count > line_count then
                            _end = _end + (new_line_count - line_count - 1)
                        end

                        module.public.trigger_icons(module.private.icons, module.private.icon_namespace, start, _end)
                        line_count = new_line_count
                    end
                end)

                do
                    if module.private.largest_change_start == -1 then
                        module.private.largest_change_start = start
                    end

                    if module.private.largest_change_end == -1 then
                        module.private.largest_change_end = _end
                    end

                    module.private.largest_change_start = start < module.private.largest_change_start and start
                        or module.private.largest_change_start
                    module.private.largest_change_end = _end > module.private.largest_change_end and _end
                        or module.private.largest_change_end
                end
            end,
        })
    elseif event.type == "core.autocommands.events.insertenter" then
        vim.schedule(function()
            module.private.last_change = {
                active = false,
                line = event.cursor_position[1] - 1,
            }
            vim.api.nvim_buf_clear_namespace(
                0,
                module.private.icon_namespace,
                event.cursor_position[1] - 1,
                event.cursor_position[1]
            )
            vim.api.nvim_buf_clear_namespace(
                0,
                module.private.markup_namespace,
                event.cursor_position[1] - 1,
                event.cursor_position[1]
            )
            vim.api.nvim_buf_clear_namespace(
                0,
                module.private.completion_level_namespace,
                event.cursor_position[1] - 1,
                event.cursor_position[1]
            )
        end)
    elseif event.type == "core.autocommands.events.insertleave" then
        vim.schedule(function()
            if not module.private.last_change.active or module.private.largest_change_end == -1 then
                module.public.trigger_icons(
                    module.private.icons,
                    module.private.icon_namespace,
                    module.private.last_change.line,
                    module.private.last_change.line + 1
                )
            else
                module.public.trigger_icons(
                    module.private.icons,
                    module.private.icon_namespace,
                    module.private.largest_change_start,
                    module.private.largest_change_end
                )
            end
        end)
    elseif event.type == "core.keybinds.events.core.norg.concealer.toggle-markup" then
        module.public.toggle_markup()
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
        insertenter = true,
        insertleave = true,
    },
    ["core.keybinds"] = {
        ["core.norg.concealer.toggle-markup"] = true,
    },
}

return module
