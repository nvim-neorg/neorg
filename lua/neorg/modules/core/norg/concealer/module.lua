--[[
    CONCEALER MODULE FOR NEORG.
    This module is supposed to enhance the neorg editing experience
    by abstracting away certain bits of text and concealing it into one easy-to-recognize
    icon. Icons can be easily changed and every element can be disabled.

USAGE: (TODO: update)
    This module does not come bundled by default with the core.defaults metamodule.
    Make sure to manually enable it in neorg's setup function.

    The module comes with several config options, and they are listed here:
    icons = {
        todo = {
            enabled = true, -- Conceal TODO items

            done = {
                enabled = true, -- Conceal whenever an item is marked as done
                icon = ""
            },
            pending = {
                enabled = true, -- Conceal whenever an item is marked as pending
                icon = ""
            },
            undone = {
                enabled = true, -- Conceal whenever an item is marked as undone
                icon = "×"
            }
        },
        quote = {
            enabled = true, -- Conceal quotes
            icon = "│"
        },
        heading = {
            enabled = true, -- Enable beautified headings

            -- Define icons for all the different heading levels
            level_1 = {
                enabled = true,
                icon = "◉",
            },

            level_2 = {
                enabled = true,
                icon = "○",
            },

            level_3 = {
                enabled = true,
                icon = "✿",
            },

            level_4 = {
                enabled = true,
                icon = "•",
            },
        },

        marker = {
            enabled = true, -- Enable the beautification of markers
            icon = "",
        },
    }

    You can also add your own custom conceals with their own custom icons, however this is a tad more complex.

    Note that those are probably the configuration options that you are *going* to use.
    There are a lot more configuration options per element than that, however.

    Here are the more advanced parameters you may be interested in:

    pattern - the pattern to match. If this pattern isn't matched then the conceal isn't applied.

    whitespace_index - this one is a bit funny to explain. Basically, this is the index of a capture from
    the "pattern" variable representing the leading whitespace. This whitespace is then used to calculate
    where to place the icon. If your pattern specifies only one capture, set this to 1

    highlight - the highlight to apply to the icon

    padding_before - the amount of padding (in the form of spaces) to apply before the icon

NOTE: When defining your own icons be sure to set *all* the above variables plus the "icon" and "enabled" variables.
      If you don't you will get errors.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.concealer")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.autocommands",
            "core.integrations.treesitter",
        },
        imports = {
            "preset_basic",
            "preset_varied",
            "preset_diamond",
        },
    }
end

module.private = {
    icon_namespace = vim.api.nvim_create_namespace("neorg-conceals"),
    code_block_namespace = vim.api.nvim_create_namespace("neorg-code-blocks"),
    completion_level_namespace = vim.api.nvim_create_namespace("neorg-completion-level"),
    extmarks = {},
    icons = {},

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
            ]
        )
        (todo_item2
            state: [
                (todo_item_undone) @undone
                (todo_item_pending) @pending
                (todo_item_done) @done
            ]
        )
        (todo_item3
            state: [
                (todo_item_undone) @undone
                (todo_item_pending) @pending
                (todo_item_done) @done
            ]
        )
        (todo_item4
            state: [
                (todo_item_undone) @undone
                (todo_item_pending) @pending
                (todo_item_done) @done
            ]
        )
        (todo_item5
            state: [
                (todo_item_undone) @undone
                (todo_item_pending) @pending
                (todo_item_done) @done
            ]
        )
        (todo_item6
            state: [
                (todo_item_undone) @undone
                (todo_item_pending) @pending
                (todo_item_done) @done
            ]
        )
    ]+
)+
    ]],
}

module.public = {

    -- @Summary Activates icons for the current window
    -- @Description Parses the user configuration and enables concealing for the current window.
    -- @Param from (number) - the line number that we should start at (defaults to 0)
    trigger_icons = function(from)
        -- Clear all the conceals beforehand (so no overlaps occur)
        module.public.clear_icons(from)

        -- Get the root node of the document (required to iterate over query captures)
        local document_root = module.required["core.integrations.treesitter"].get_document_root()

        -- Loop through all icons that the user has enabled
        for _, icon_data in ipairs(module.private.icons) do
            if icon_data.query then
                -- Attempt to parse the query provided by `icon_data.query`
                -- A query must have at least one capture, e.g. "(test_node) @icon"
                local query = vim.treesitter.parse_query("norg", icon_data.query)

                -- Go through every found node and try to apply an icon to it
                for id, node in query:iter_captures(document_root, 0, from and from - 1 or 0, -1) do
                    local capture = query.captures[id]

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
                            offset = icon_data.extract(text) or 0
                        end

                        -- Every icon can also implement a custom "render" function that can allow for things like multicoloured icons
                        -- This is primarily used in nested quotes
                        -- The "render" function must return a table of this structure: { { "text", "highlightgroup1" }, { "optionally more text", "higlightgroup2" } }
                        if not icon_data.render then
                            module.public._set_extmark(
                                icon_data.icon,
                                icon_data.highlight,
                                "icon",
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
                                "icon",
                                range.row_start,
                                range.row_end,
                                range.column_start + offset,
                                range.column_end,
                                false,
                                "combine"
                            )
                        end
                    end
                end
            end
        end
    end,

    trigger_code_block_highlights = function(from)
        -- If the code block dimming is disabled, return right away.
        if not module.config.public.dim_code_blocks then
            return
        end

        module.public.clear_code_block_dimming(from)

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
					local ok, result = pcall(
						vim.treesitter.require_language,
						regex_language,
						true
					)

					-- if pcall was true we had parser, skip the rest
					if ok and result then
						goto continue
					end

					-- NOTE: the regex fallback code was mostly adapted from Vimwiki
					-- It's a very good implementation of nested vim regex
					regex_language = regex_language:gsub("%s+", "") -- need to trim out whitespace
					local group = "textGroup" .. string.upper(regex_language)
					local snip = "textSnip"..string.upper(regex_language)
					local start_marker = "@code "..regex_language
					local end_marker = "@end"

					-- if our region syntax group exists, quit out
					-- this stops repeat groups from forming on text update
					-- NOTE: potenial nvim api call can be used here
					if vim.fn.hlexists(snip) == 1 then
						goto continue
					end

					-- pass off the current syntax buffer var so things can load
					local current_syntax = ""
					if vim.b.current_syntax ~= '' or vim.b.current_syntax ~= nil then
						vim.b.current_syntax = regex_language
					    current_syntax = vim.b.current_syntax
						vim.b.current_syntax = nil
					end

					-- temporarily pass off keywords in case they get messed up
					local is_keyword = vim.api.nvim_buf_get_option(0, "iskeyword")

					-- see if the syntax files even exist before we try to call them
					-- NOTE: this is what fails for the second language
					-- TODO: replace with non-vimL functions
					local output = vim.fn.globpath(vim.api.nvim_get_option("runtimepath"), "syntax/"..regex_language..".vim", false, true)
					if output[1] ~= nil then
						local command = "syntax include @"..group.." "..output[1]
						vim.cmd(command)
					end
					local output = vim.fn.globpath(vim.api.nvim_get_option("runtimepath"), "after/syntax/"..regex_language..".vim", false, true)
					if output[1] ~= nil then
						local command = "syntax include @"..group.." "..output[1]
						vim.cmd(command)
					end

					vim.api.nvim_buf_set_option(0, "iskeyword", is_keyword)

					-- reset it after
					if current_syntax ~= '' or current_syntax ~= nil then
						vim.b.current_syntax = current_syntax
					else
						vim.b.current_syntax = ''
					end

					-- set highlight groups
					local regex_fallback_hl = "syntax region "..snip.." matchgroup=Snip start=\""..start_marker.."\" end='"..end_marker.."' contains=@"..group.." keepend"
					vim.cmd(regex_fallback_hl)

					-- resync syntax, fixes some slow loading
					vim.cmd("syntax sync fromstart")
					vim.b.current_syntax = ''

					-- continue on from for loop if a language with parser is found or another syntax might be loaded
					::continue::
				end
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
                                "code_block",
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
        local ok, result = pcall(
            vim.api.nvim_buf_set_extmark,
            0,
            module.private[ns .. "_namespace"],
            line_number,
            start_column,
            {
                end_col = end_column,
                hl_group = highlight,
                end_line = end_line,
                virt_text = text or nil,
                virt_text_pos = "overlay",
                hl_mode = mode,
                hl_eol = whole_line,
            }
        )

        -- If we have encountered an error then log it
        if not ok then
            log.error("Unable to create custom conceal for highlight:", highlight, "-", result)
        end
    end,

    -- @Summary Clears all the conceals that neorg has defined
    -- @Description Simply clears the Neorg extmark namespace
    -- @Param from (number) - the line number to start clearing from
    clear_icons = function(from)
        vim.api.nvim_buf_clear_namespace(0, module.private.icon_namespace, from or 0, -1)
    end,

    --- Clears all dimming applied to code blocks in the current buffer
    --- @param from number #The line number to start clearing from
    clear_code_block_dimming = function(from)
        vim.api.nvim_buf_clear_namespace(0, module.private.code_block_namespace, from or 0, -1)
    end,

    -- @Summary Triggers conceals for the current buffer
    -- @Description Reads through the user configuration and enables concealing for the current buffer
    trigger_conceals = function()
        local conceals = module.config.public.conceals

        if conceals.url then
            vim.schedule(function()
                vim.cmd(
                    'syn region NeorgConcealURLValue matchgroup=mkdDelimiter start="(" end=")" contained oneline conceal'
                )
                vim.cmd(
                    'syn region NeorgConcealURL matchgroup=mkdDelimiter start="\\([^\\\\]\\|\\_^\\)\\@<=\\[\\%\\(\\%\\(\\\\\\=[^\\]]\\)\\+\\](\\)\\@=" end="[^\\\\]\\@<=\\]" nextgroup=NeorgConcealURLValue oneline skipwhite concealends'
                )
            end)
        end

        if conceals.bold then
            vim.schedule(function()
                vim.cmd([[
                syn region NeorgConcealBold matchgroup=Normal start="\([?!:;,.<>()\[\]{}'"/#%&$£€\-_\~`\W \t\n]\&[^\\]\|^\)\@<=\*\%\([^ \t\n\*]\)\@=" end="[^ \t\n\\]\@<=\*\%\([?!:;,.<>()\[\]{}\*'"/#%&$£\-_\~`\W \t\n]\)\@=" oneline concealends
                ]])
            end)
        end

        if conceals.italic then
            vim.schedule(function()
                vim.cmd([[
                syn region NeorgConcealItalic matchgroup=Normal start="\([?!:;,.<>()\[\]{}\*'"#%&$£€\-_\~`\W \t\n]\&[^\\]\|^\)\@<=/\%\([^ \t\n/]\)\@=" end="[^ \t\n\\]\@<=/\%\([?!:;,.<>()\[\]{}\*'"/#%&$£\-_\~`\W \t\n]\)\@=" oneline concealends
                ]])
            end)
        end

        if conceals.underline then
            vim.schedule(function()
                vim.cmd([[
                syn region NeorgConcealUnderline matchgroup=Normal start="\([?!:;,.<>()\[\]{}\*'"/#%&$£€\-\~`\W \t\n]\&[^\\]\|^\)\@<=_\%\([^ \t\n_]\)\@=" end="[^ \t\n\\]\@<=_\%\([?!:;,.<>()\[\]{}\*'"/#%&$£\-_\~`\W \t\n]\)\@=" oneline concealends
                ]])
            end)
        end

        if conceals.strikethrough then
            vim.schedule(function()
                vim.cmd([[
                syn region NeorgConcealStrikethrough matchgroup=Normal start="\([?!:;,.<>()\[\]{}\*'"/#%&$£€\-_\~`\W \t\n]\&[^\\]\|^\)\@<=\-\%\([^ \t\n\-]\)\@=" end="[^ \t\n\\]\@<=\-\%\([?!:;,.<>()\[\]{}\*'"/#%&$£\-_\~`\W \t\n]\)\@=" oneline concealends
                ]])
            end)
        end

        if conceals.verbatim then
            vim.schedule(function()
                vim.cmd([[
                syn region NeorgConcealMonospace matchgroup=Normal start="\([?!:;,.<>()\[\]{}\*'"/#%&$£€\-_\~\W \t\n]\&[^\\]\|^\)\@<=`\%\([^ \t\n`]\)\@=" end="[^ \t\n\\]\@<=`\%\([?!:;,.<>()\[\]{}\*'"/#%&$£\-_\~`\W \t\n]\)\@=" contains=@NoSpell oneline concealends
                ]])
            end)
        end

        if conceals.comment then
            vim.schedule(function()
                vim.cmd([[
                syn region NeorgConcealComment matchgroup=Normal start="\([?!:;,.<>()\[\]{}\*'"/%&$£€\-_\~`\W \t\n]\&[^\\]\|^\)\@<=#\%\([^ \t\n#]\)\@=" end="[^ \t\n\\]\@<=#\%\([?!:;,.<>()\[\]{}\*'"/#%&$£\-_\~`\W \t\n]\)\@=" oneline concealends
                ]])
            end)
        end

        if conceals.trailing then
            vim.schedule(function()
                vim.cmd([[
                syn match NeorgConcealTrailing /[^\s]\@=\~$/ conceal
                ]])
            end)
        end

        if conceals.link then
            vim.schedule(function()
                vim.cmd([[
                syn region NeorgConcealLink matchgroup=Normal start=":[\*/_\-`]\@=" end="[\*/_\-`]\@<=:" contains=NeorgConcealBold,NeorgConcealItalic,NeorgConcealUnderline,NeorgConcealStrikethrough,NeorgConcealMonospace oneline concealends
                ]])
            end)
        end
    end,

    -- @Summary Clears conceals for the current buffer
    -- @Description Clears all highlight groups related to the Neorg conceal higlight groups
    clear_conceals = function()
        vim.cmd([[
            silent! syn clear NeorgConcealURL
            silent! syn clear NeorgConcealURLValue
            silent! syn clear NeorgConcealItalic
            silent! syn clear NeorgConcealBold
            silent! syn clear NeorgConcealUnderline
            silent! syn clear NeorgConcealMonospace
            silent! syn clear NeorgConcealComment
            silent! syn clear NeorgConcealStrikethrough
            silent! syn clear NeorgConcealTrailing
            silent! syn clear NeorgConcealLink
        ]])
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

            local total, done, pending, undone = 0, 0, 0, 0

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
                        })

                        total, done, pending, undone = 0, 0, 0, 0
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
                end
            end

            if total > 0 then
                table.insert(nodes, {
                    node = last_node,
                    total = total,
                    done = done,
                    pending = pending,
                    undone = undone,
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

local function reparg(value, index)
    if index == 1 then
        return value
    end

    return value, reparg(value, index - 1)
end

module.config.public = {
    icon_preset = "basic",

    icons = {},

    conceals = {
        url = true,
        bold = true,
        italic = true,
        underline = true,
        strikethrough = true,
        verbatim = true,
        comment = true,
        trailing = true,
        link = true,
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
                                        (carryover_tag)+
                                        target: %s
                                    )
                                ]+
                            )+
                            (heading2
                                content: (_)*
                                content: [
                                    %s
                                    (carryover_tag_set
                                        (carryover_tag)+
                                        target: %s
                                    )
                                ]
                            )+
                            (heading3
                                content: (_)*
                                content: [
                                    %s
                                    (carryover_tag_set
                                        (carryover_tag)+
                                        target: %s
                                    )
                                ]
                            )+
                            (heading4
                                content: (_)*
                                content: [
                                    %s
                                    (carryover_tag_set
                                        (carryover_tag)+
                                        target: %s
                                    )
                                ]
                            )+
                            (heading5
                                content: (_)*
                                content: [
                                    %s
                                    (carryover_tag_set
                                        (carryover_tag)+
                                        target: %s
                                    )
                                ]
                            )+
                            (heading6
                                content: (_)*
                                content: [
                                    %s
                                    (carryover_tag_set
                                        (carryover_tag)+
                                        target: %s
                                    )
                                ]
                            )+
                        ] @progress
                ]],
                    reparg(module.private.todo_list_query, 6 * 2)
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
        "keep",
        module.config.public.icons,
        module.config.private["icon_preset_" .. module.config.public.icon_preset]
    )

    -- @Summary Returns all the enabled icons from a table
    -- @Param  tbl (table) - the table to parse
    -- @Param rec_name (string) - should not be set manually. Is used for Neorg to have information about all other previous recursions
    local function get_enabled_icons(tbl, rec_name)
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
                -- If we have defined an icon value then add that icon to the result
                if icons.icon then
                    result[rec_name .. name] = icons
                else
                    -- If we don't have an icon variable then we need to descend further down the lua table.
                    -- To do this we recursively call this very function and merge the results into the result table
                    result = vim.tbl_deep_extend("force", result, get_enabled_icons(icons, rec_name .. name))
                end
            end
        end

        return result
    end

    -- Set the module.private.icons variable to the values of the enabled icons
    module.private.icons = vim.tbl_values(get_enabled_icons(module.config.public.icons))

    -- Enable the required autocommands (these will be used to determine when to update conceals in the buffer)
    module.required["core.autocommands"].enable_autocommand("BufEnter")

    module.required["core.autocommands"].enable_autocommand("TextChanged")
    module.required["core.autocommands"].enable_autocommand("TextChangedI")
    module.required["core.autocommands"].enable_autocommand("InsertEnter")
    module.required["core.autocommands"].enable_autocommand("InsertLeave")
end

module.on_event = function(event)
    -- If we have just entered a .norg buffer then apply all conceals
    -- TODO: Remove (or at least provide a reason) as to why there are so many vim.schedules
    -- Explain priorities and how we only schedule less important things to improve the average user
    -- experience
    if event.type == "core.autocommands.events.bufenter" and event.content.norg then
        if module.config.public.conceals then
            module.public.trigger_conceals()
        end

        module.public.trigger_code_block_highlights()
        module.public.trigger_completion_levels()
        module.public.trigger_icons()

        if module.config.public.folds.enable then
            vim.opt_local.foldmethod = "expr"
            vim.opt_local.foldlevel = module.config.public.folds.foldlevel
            vim.opt_local.foldexpr = "nvim_treesitter#foldexpr()"
            vim.opt_local.foldtext = "v:lua.neorg.modules.get_module('" .. module.name .. "').foldtext()"
        end
    elseif event.type == "core.autocommands.events.textchanged" then
        -- If the content of a line has changed in normal mode then reparse the file
        module.public.trigger_icons()
        module.public.trigger_code_block_highlights()
        vim.schedule(module.public.trigger_completion_levels)
    elseif event.type == "core.autocommands.events.insertenter" then
        vim.api.nvim_buf_clear_namespace(
            0,
            module.private.icon_namespace,
            event.cursor_position[1] - 1,
            event.cursor_position[1]
        )
        vim.api.nvim_buf_clear_namespace(
            0,
            module.private.completion_level_namespace,
            event.cursor_position[1] - 1,
            event.cursor_position[1]
        )
    elseif event.type == "core.autocommands.events.insertleave" then
        vim.schedule(function()
            module.public.trigger_icons()
            module.public.trigger_completion_levels()
        end)
    elseif event.type == "core.autocommands.events.textchangedi" then
        vim.schedule(module.public.trigger_code_block_highlights)
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
        textchanged = true,
        textchangedi = true,
        insertenter = true,
        insertleave = true,
    },
}

return module
