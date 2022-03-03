--[[
    File: Syntax
    Title: Syntax Module for Neorg
    Summary: Handles interaction for syntax files for code blocks
    ---
--]]


require('neorg.modules.base')

local module = neorg.modules.create("core.syntax")

local function schedule(func)
    vim.schedule(function()
        if
            module.private.disable_deferred_updates
            or (
                (module.private.debounce_counters[vim.api.nvim_win_get_cursor(0)[1] + 1] or 0)
                >= module.config.public.performance.max_debounce
            )
        then
            return
        end

        func()
    end)
end

module.setup = function()
    return {
        success = true,
        requires = {
            "core.autocommands",
            "core.integrations.treesitter",
        },
    }
end

module.private = {

    largest_change_start = -1,
    largest_change_end = -1,

    last_change = {
        active = false,
        line = 0,
    },

    disable_deferred_updates = false,
    debounce_counters = {},

    code_block_table = {
        -- [[
        -- table is setup like so
        -- {
        --     buf_name_1 = {loaded_regex = {regex_name = {type = "type", range = {start_row1 = end_row1}}}}
        --     buf_name_2 = {loaded_regex = {regex_name = "type"}}
        -- }
        -- ]]
    },

    available_regex = {},
}

module.public = {

    -- fills module.private.loaded_code_blocks with the list of active code blocks in the buffer
    -- stores globally apparently
    check_code_block_type = function(buf, reload, from, to)
        -- TODO test event handling here
        -- local test_event = neorg.events.create(module, "core.norg.concealer.events.test_event_name", "test_content")
        -- neorg.events.create(module, "test_event", "test_content")
        -- for k, v in pairs(test_event) do
        --	print("k: " .. k)
        --	print("v: " .. v)
        -- end

        -- parse the current buffer, and clear out the buffer's loaded code blocks if needed
        -- NOTE: this will need to be replaced by neorg events
        local current_buf = vim.api.nvim_buf_get_name(buf)

        -- load nil table with empty values
        if module.private.code_block_table[current_buf] == nil then
            module.private.code_block_table[current_buf] = { loaded_regex = {} }
        end

        -- recreate table for buffer on buffer change
        -- reason for existence:
        -- [[
        --   user deletes a bunch of code blocks from file, and said code blocks
        --   were the only regex blocks of that language. on a full buffer refresh
        --   like reentering the buffer, this will get cleared to recreate what languages
        --   are loaded. then another function will handle unloading syntax files on next load
        -- ]]
        for key in pairs(module.private.code_block_table) do
            if current_buf ~= key or reload == true then
                for k, _ in pairs(module.private.code_block_table[current_buf].loaded_regex) do
                    module.private.code_block_table[current_buf].loaded_regex[k] = nil
                end
            end
        end

        -- If the tree is valid then attempt to perform the query
        local tree = vim.treesitter.get_parser(buf, "norg"):parse()[1]
        if tree then
            -- get the language node used by the code block
            local code_lang = vim.treesitter.parse_query(
                "norg",
                [[(
                    (ranged_tag (tag_name) @_tagname (tag_parameters) @language)
                    (#eq? @_tagname "code")
                )]]
            )

            -- check for each code block capture in the root with a language paramater
            -- to build a table of all the languages for a given buffer
            local compare_table = {} -- a table to compare to what was loaded
            for id, node in code_lang:iter_captures(tree:root(), buf, from or 0, to or -1) do
                if id == 2 then -- id 2 here refers to the "language" tag

                    -- find the end node of a block so we can grab the row
                    local _, end_node = pcall(node:next_named_sibling():next_sibling())
                    -- get the start and ends of the current capture
                    local start_row = node:range() + 1
                    local end_row

                    -- don't try to parse a nil value
                    if end_row == nil then
                        end_row = 1
                    else
                        end_row = end_node:range() + 1
                    end

                    local regex_lang = vim.treesitter.get_node_text(node, buf)
                    -- local curr_lang
                    local type

                    -- see if parser exists
                    local result = pcall(vim.treesitter.require_language, regex_lang, true)

                    -- mark if its for TS parser or not
                    if result then
                        type = "treesitter"
                    else
                        type = "regex"
                    end

                    -- add language to table
                    -- if type is empty it means this language has never been found
                    if module.private.code_block_table[current_buf].loaded_regex[regex_lang] == nil then
                        module.private.code_block_table[current_buf].loaded_regex[regex_lang] = {
                            type = type,
                            range = {},
                        }
                    end
                    -- else just do what we need to do
                    module.private.code_block_table[current_buf].loaded_regex[regex_lang].range[start_row] = end_row
                    table.insert(compare_table, regex_lang)
                end
            end

            -- compare loaded languages to see if the file actually has the code blocks
            if from == nil then
                for lang in pairs(module.private.code_block_table[current_buf].loaded_regex) do
                    local found_lang = false
                    for _, matched in pairs(compare_table) do
                        if matched == lang then
                            found_lang = true
                            break
                        end
                    end
                    -- if no lang was matched, means we didn't find a language in our parse
                    -- remove the syntax include and region
                    if found_lang == false then
                        -- delete loaded lang from the table
                        module.private.code_block_table[current_buf].loaded_regex[lang] = nil
                        module.public.remove_syntax(
                            string.format("textGroup%s", string.upper(lang)),
                            string.format("textSnip%s", string.upper(lang))
                        )
                    end
                end
            end
        end
    end,

    -- load syntax files for regex code blocks
    trigger_highlight_regex_code_block = function(buf, remove, from, to)
        -- scheduling this function seems to break parsing properly
        -- schedule(function()
        local current_buf = vim.api.nvim_buf_get_name(buf)
        -- only parse from the loaded_code_blocks module, not from the file directly
        if module.private.code_block_table[current_buf] == nil then
            return
        end
        local lang_table = module.private.code_block_table[current_buf].loaded_regex
        for lang_name, curr_table in pairs(lang_table) do
            if curr_table.type == "regex" then
                -- NOTE: the regex fallback code was mostly adapted from Vimwiki
                -- It's a very good implementation of nested vim regex
                local group = string.format("textGroup%s", string.upper(lang_name))
                local snip = string.format("textSnip%s", string.upper(lang_name))
                local start_marker = string.format("@code %s", lang_name)
                local end_marker = "@end"
                local has_syntax = string.format("syntax list @%s", group)

                -- try removing syntax before doing anything
                -- fixes hi link groups from not loading on certain updates
                if remove == true then
                    module.public.remove_syntax(group, snip)
                end

                local ok, result = pcall(vim.api.nvim_exec, has_syntax, true)
                local count = select(2, result:gsub("\n", "\n")) -- get length of result from syn list
                local empty_result = 0
                for line in result:gmatch("([^\n]*)\n?") do
                    empty_result = string.match(line, "textGroup%w+%s+cluster=NONE")
                    if empty_result == nil then
                        empty_result = 0
                    else
                        empty_result = #empty_result
                        break
                    end
                end

                -- see if the syntax files even exist before we try to call them
                -- if syn list was an error, or if it was an empty result
                if ok == false or (ok == true and ((string.sub(result, 1, 1) == "N" and count == 0)) or (empty_result > 0)) then
                    -- absorb all syntax stuff
                    local is_keyword = vim.api.nvim_buf_get_option(buf, "iskeyword")
                    local current_syntax = ""
                    local foldmethod = vim.o.foldmethod
                    local foldexpr = vim.o.foldexpr
                    local foldtext = vim.o.foldtext
                    local foldnestmax = vim.o.foldnestmax
                    local foldcolumn = vim.o.foldcolumn
                    local foldenable = vim.o.foldenable
                    local foldminlines = vim.o.foldminlines
                    if vim.b.current_syntax ~= "" or vim.b.current_syntax ~= nil then
                        vim.b.current_syntax = lang_name
                        current_syntax = vim.b.current_syntax
                        vim.b.current_syntax = nil
                    end

                    local regex = "([^/]*).vim$"
                    for _, syntax in pairs(module.private.available_regex) do
                        for match in string.gmatch(syntax, regex) do
                            if lang_name == match then
                                local command = string.format("syntax include @%s %s", group, syntax)
                                vim.cmd(command)
                            end
                        end
                    end

                    -- reset it after
                    vim.api.nvim_buf_set_option(buf, "iskeyword", is_keyword)
                    if current_syntax ~= "" or current_syntax ~= nil then
                        vim.b.current_syntax = current_syntax
                    else
                        vim.b.current_syntax = ""
                    end

                    has_syntax = string.format("syntax list %s", snip)
                    ok, result = pcall(vim.api.nvim_exec, has_syntax, true)
                    count = select(2, result:gsub("\n", "\n")) -- get length of result from syn list

                    -- if we see "-" it means there potentially is already a region for this lang
                    -- we must have only 1 line, more lines means there is a region already
                    -- see :h syn-list for the format
                    if count == 0 or (string.sub(result, 1, 1) == "-" and count == 0) then
                        -- set highlight groups
                        local regex_fallback_hl = string.format(
                            [[
                                syntax region %s
                                \ matchgroup=Snip
                                \ start="%s" end="%s"
                                \ contains=@%s
                                \ keepend
                            ]],
                            snip,
                            start_marker,
                            end_marker,
                            group
                        )
                        vim.cmd(string.format("%s", regex_fallback_hl))
                    end

                    vim.o.foldmethod = foldmethod
                    vim.o.foldexpr = foldexpr
                    vim.o.foldtext = foldtext
                    vim.o.foldnestmax = foldnestmax
                    vim.o.foldcolumn = foldcolumn
                    vim.o.foldenable = foldenable
                    vim.o.foldminlines = foldminlines
                end

                -- sync everything
                module.public.sync_regex_code_blocks(buf, lang_name, from, to)

                vim.b.current_syntax = ""
            end
        end
        -- end)
    end,

    -- remove loaded syntax include and snip region
    remove_syntax = function(group, snip)
        -- these clears are silent. errors do not matter
        -- errors are assumed to come from the functions that call this
        local group_remove = string.format(
            "silent! syntax clear @%s",
            group
        )
        vim.cmd(group_remove)

        local snip_remove = string.format(
            "silent! syntax clear %s",
            snip
        )
        vim.cmd(snip_remove)
    end,

    -- sync regex code blocks
    sync_regex_code_blocks = function(buf, regex, from, to)
        local current_buf = vim.api.nvim_buf_get_name(buf)
        -- only parse from the loaded_code_blocks module, not from the file directly
        if module.private.code_block_table[current_buf] == nil then
            return
        end
        local lang_table = module.private.code_block_table[current_buf].loaded_regex
        for lang_name, curr_table in pairs(lang_table) do
            -- if we got passed a regex, then we need to only parse the right one
            if regex ~= nil then
                if regex ~= lang_name then
                    goto continue
                end
            end
            if curr_table.type == "regex" then
                -- sync from code block

                -- for incremental syncing
                if from ~= nil then
                    local found_lang = false
                    for start_row, end_row in pairs(curr_table.range) do
                        -- see if the text changes we made included a regex code block
                        if start_row <= from and end_row >= to then
                            found_lang = true
                        end
                    end

                    -- didn't find match from this range of the current language, skip parsing
                    if found_lang == false then
                        goto continue
                    end
                end


                -- local group = string.format("textGroup%s", string.upper(lang_name))
                local snip = string.format("textSnip%s", string.upper(lang_name))
                local start_marker = string.format("@code %s", lang_name)
                local end_marker = "@end"
                -- local has_syntax = string.format("syntax list %s", snip)
                local regex_fallback_hl = string.format(
                    [[
                        syntax sync match %s
                        \ grouphere %s
                        \ "%s"
                    ]],
                    snip,
                    snip,
                    start_marker
                )
                vim.cmd(string.format("silent! %s", regex_fallback_hl))

                -- sync back from end block
                regex_fallback_hl = string.format(
                    [[
                        syntax sync match %s
                        \ groupthere %s
                        \ "%s"
                    ]],
                    snip,
                    snip,
                    end_marker
                )
                -- TODO check groupthere
                -- vim.cmd(string.format("%s", regex_fallback_hl))
                -- vim.cmd("syntax sync maxlines=100")
            end
            ::continue::
        end
    end,
}

module.config.public = {
    -- note that these come from core.norg.concealer
    performance = {
        increment = 1250,
        timeout = 0,
        interval = 500,
        max_debounce = 5,
    }
}

module.load = function()

    -- Enabled the required autocommands
    -- This is generally any potential redraw event
    module.required["core.autocommands"].enable_autocommand("BufEnter")
    module.required["core.autocommands"].enable_autocommand("ColorScheme")

    -- module.required["core.autocommands"].enable_autocommand("InsertEnter")
    module.required["core.autocommands"].enable_autocommand("InsertLeave")
    module.required["core.autocommands"].enable_autocommand("VimLeavePre")

    -- Load available regex languages
    -- get the available regex files for the current session
    local get_regex_files = function()
        local output = {}
        local syntax_files = vim.api.nvim_get_runtime_file("syntax/*.vim", true)
        for _, lang in pairs(syntax_files) do
            table.insert(output, lang)
        end
        syntax_files = vim.api.nvim_get_runtime_file("after/syntax/*.vim", true)
        for _, lang in pairs(syntax_files) do
            table.insert(output, lang)
        end
        return output
    end
    module.private.available_regex = get_regex_files()
end

module.on_event = function(event)
    module.private.debounce_counters[event.cursor_position[1] + 1] = module.private.debounce_counters[event.cursor_position[1] + 1]
        or 0

    local function should_debounce()
        return module.private.debounce_counters[event.cursor_position[1] + 1]
            >= module.config.public.performance.max_debounce
    end

    if event.type == "core.autocommands.events.bufenter" and event.content.norg then
        local buf = event.buffer
        local line_count = vim.api.nvim_buf_line_count(buf)

        -- TODO mess with performance stuff
        if line_count < module.config.public.performance.increment then
            module.public.check_code_block_type(buf, false)
            module.public.trigger_highlight_regex_code_block(buf, true)
        else

            -- don't increment on a bufenter at all
            module.public.check_code_block_type(buf, false)
            module.public.trigger_highlight_regex_code_block(buf, true)
        end
        vim.api.nvim_buf_attach(buf, false, {
            on_lines = function(_, cur_buf, _, start, _end)
                if buf ~= cur_buf then
                    return true
                end

                if should_debounce() then
                    return
                end

                module.private.last_change.active = true

                local mode = vim.api.nvim_get_mode().mode

                if mode ~= "i" then
                    module.private.debounce_counters[event.cursor_position[1] + 1] = module.private.debounce_counters[event.cursor_position[1] + 1]
                        + 1

                    schedule(function()
                        local new_line_count = vim.api.nvim_buf_line_count(buf)

                        -- Sometimes occurs with one-line undos
                        if start == _end then
                            _end = _end + 1
                        end

                        if new_line_count > line_count then
                            _end = _end + (new_line_count - line_count - 1)
                        end

                        line_count = new_line_count

                        local node_range =
                            module.required["core.integrations.treesitter"].get_ts_utils().get_node_at_cursor()

                        if node_range then
                            node_range = module.required["core.integrations.treesitter"].get_node_range(
                                node_range:parent()
                            )
                        end

                        module.public.check_code_block_type(buf, false, start, _end)
                        module.public.trigger_highlight_regex_code_block(buf, true, start, _end)

                        vim.schedule(function()
                            module.private.debounce_counters[event.cursor_position[1] + 1] = module.private.debounce_counters[event.cursor_position[1] + 1]
                                - 1
                        end)
                    end)
                else
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
    elseif event.type == "core.autocommands.events.insertleave" then
        if should_debounce() then
            return
        end

        schedule(function()
            if not module.private.last_change.active or module.private.largest_change_end == -1 then
                module.public.check_code_block_type(
                    event.buffer,
                    false
                    -- module.private.last_change.line,
                    -- module.private.last_change.line + 1
                )
                module.public.trigger_highlight_regex_code_block(
                    event.buffer,
                    false,
                    module.private.last_change.line,
                    module.private.last_change.line + 1
                )
            else
                module.public.check_code_block_type(
                    event.buffer,
                    false,
                    module.private.last_change.line,
                    module.private.last_change.line + 1
                )
                module.public.trigger_highlight_regex_code_block(
                    event.buffer,
                    false,
                    module.private.largest_change_start,
                    module.private.largest_change_end
                )
            end

            module.private.largest_change_start, module.private.largest_change_end = -1, -1
        end)
    elseif event.type == "core.autocommands.events.vimleavepre" then
        module.private.disable_deferred_updates = true
    -- this autocmd is used to fix hi link syntax languages
    elseif event.type == "core.autocommands.events.colorscheme" then
        module.public.trigger_highlight_regex_code_block(event.buffer, true)
    end
end

module.events.subscribed = {
    ["core.autocommands"] = {
        bufenter = true,
        colorscheme = true,
        insertleave = true,
        vimleavepre = true,
    },
}

return module
