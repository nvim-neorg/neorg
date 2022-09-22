--[[
    File: Syntax
    Title: Syntax Module for Neorg
    Summary: Handles interaction for syntax files for code blocks.
    ---
    Author's note:
    This module will appear as spaghetti code at first glance. This is intenional.
    If one needs to edit this module, it is best to talk to me at katawful on GitHub.
    Any edit is assumed to break this module
--]]

require("neorg.modules.base")

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

    -- we need to track the buffers in use
    last_buffer = "",

    disable_deferred_updates = false,
    debounce_counters = {},

    code_block_table = {
        --[[
           table is setup like so
            {
               buf_name_1 = {loaded_regex = {regex_name = {type = "type", range = {start_row1 = end_row1}}}}
               buf_name_2 = {loaded_regex = {regex_name = {type = "type", range = {start_row1 = end_row1}}}}
            }
        --]]
    },

    available_languages = {},
}

module.public = {

    -- fills module.private.loaded_code_blocks with the list of active code blocks in the buffer
    -- stores globally apparently
    check_code_block_type = function(buf, reload, from, to)
        -- parse the current buffer, and clear out the buffer's loaded code blocks if needed
        local current_buf = vim.api.nvim_buf_get_name(buf)

        -- load nil table with empty values
        if module.private.code_block_table[current_buf] == nil then
            module.private.code_block_table[current_buf] = { loaded_regex = {} }
        end

        -- recreate table for buffer on buffer change
        -- reason for existence:
        --[[
            user deletes a bunch of code blocks from file, and said code blocks
            were the only regex blocks of that language. on a full buffer refresh
            like reentering the buffer, this will get cleared to recreate what languages
            are loaded. then another function will handle unloading syntax files on next load
        --]]
        for key in pairs(module.private.code_block_table) do
            if current_buf == key and reload == true then
                for k, _ in pairs(module.private.code_block_table[current_buf].loaded_regex) do
                    module.public.remove_syntax(
                        string.format("textGroup%s", string.upper(k)),
                        string.format("textSnip%s", string.upper(k))
                    )
                    module.private.code_block_table[current_buf].loaded_regex[k] = nil
                end
            end
        end

        -- If the tree is valid then attempt to perform the query
        local tree = module.required["core.integrations.treesitter"].get_document_root(buf)

        if tree then
            -- get the language node used by the code block
            local code_lang = vim.treesitter.parse_query(
                "norg",
                [[(
                    (ranged_tag (tag_name) @_tagname (tag_parameters) @language)
                    (#any-of? @_tagname "code" "embed")
                )]]
            )

            -- check for each code block capture in the root with a language paramater
            -- to build a table of all the languages for a given buffer
            local compare_table = {} -- a table to compare to what was loaded
            for id, node in code_lang:iter_captures(tree:root(), buf, from or 0, to or -1) do
                if id == 2 then -- id 2 here refers to the "language" tag
                    -- find the end node of a block so we can grab the row
                    local end_node = node:next_named_sibling():next_sibling()
                    -- get the start and ends of the current capture
                    local start_row = node:range() + 1
                    local end_row

                    -- don't try to parse a nil value
                    if end_node == nil then
                        end_row = start_row + 1
                    else
                        end_row = end_node:range() + 1
                    end

                    local regex_lang = vim.treesitter.get_node_text(node, buf)

                    -- make sure that the language is actually valid
                    local type_func = function()
                        return module.private.available_languages[regex_lang].type
                    end
                    local ok, type = pcall(type_func)

                    if not ok then
                        type = "null" -- null type will never get parsed like treesitter languages
                    end

                    -- add language to table
                    -- if type is empty it means this language has never been found
                    if module.private.code_block_table[current_buf].loaded_regex[regex_lang] == nil then
                        module.private.code_block_table[current_buf].loaded_regex[regex_lang] = {
                            type = type,
                            range = {},
                            cluster = "",
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
    trigger_highlight_regex_code_block = function(buf, remove, ignore_buf, from, to)
        -- scheduling this function seems to break parsing properly
        -- schedule(function()
        local current_buf = vim.api.nvim_buf_get_name(buf)
        -- only parse from the loaded_code_blocks module, not from the file directly
        if module.private.code_block_table[current_buf] == nil then
            return
        end
        local lang_table = module.private.code_block_table[current_buf].loaded_regex
        for lang_name, curr_table in pairs(lang_table) do
            if curr_table.type == "syntax" then
                -- NOTE: the regex fallback code was originally mostly adapted from Vimwiki
                -- In its current form it has been intensely expanded upon
                local group = string.format("textGroup%s", string.upper(lang_name))
                local snip = string.format("textSnip%s", string.upper(lang_name))
                local start_marker = string.format("@code %s", lang_name)
                local end_marker = "@end"
                local has_syntax = string.format("syntax list @%s", group)

                -- sync groups when needed
                if ignore_buf == false and vim.api.nvim_buf_get_name(buf) == module.private.last_buffer then
                    module.public.sync_regex_code_blocks(buf, lang_name, from, to)
                end

                -- try removing syntax before doing anything
                -- fixes hi link groups from not loading on certain updates
                if remove == true then
                    module.public.remove_syntax(group, snip)
                end

                local ok, result = pcall(vim.api.nvim_exec, has_syntax, true)
                local count = select(2, result:gsub("\n", "\n")) -- get length of result from syn list
                local empty_result = 0
                -- look to see if the textGroup is actually empty
                -- clusters don't delete when they're clear
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
                if
                    ok == false
                    or (
                        ok == true and ((string.sub(result, 1, 1) == ("N" or "V") and count == 0) or (empty_result > 0))
                    )
                then
                    -- absorb all syntax stuff
                    -- potentially needs to be expanded upon as bad values come in
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

                    -- include the cluster that will put inside the region
                    -- source using the available languages
                    for syntax, table in pairs(module.private.available_languages) do
                        if table.type == "syntax" then
                            if lang_name == syntax then
                                if empty_result == 0 then
                                    -- get the file name for the syntax file
                                    local file =
                                        vim.api.nvim_get_runtime_file(string.format("syntax/%s.vim", syntax), false)
                                    if file == nil then
                                        file = vim.api.nvim_get_runtime_file(
                                            string.format("after/syntax/%s.vim", syntax),
                                            false
                                        )
                                    end
                                    file = file[1]
                                    local command = string.format("syntax include @%s %s", group, file)
                                    vim.cmd(command)

                                    -- make sure that group has things when needed
                                    local regex = group .. "%s+cluster=(.+)"
                                    local _, found_cluster =
                                        pcall(vim.api.nvim_exec, string.format("syntax list @%s", group), true)
                                    local actual_cluster
                                    for match in found_cluster:gmatch(regex) do
                                        actual_cluster = match
                                    end
                                    if actual_cluster ~= nil then
                                        module.private.code_block_table[current_buf].loaded_regex[lang_name].cluster =
                                            actual_cluster
                                    end
                                elseif
                                    module.private.code_block_table[current_buf].loaded_regex[lang_name].cluster ~= nil
                                then
                                    local command = string.format(
                                        "silent! syntax cluster %s add=%s",
                                        group,
                                        module.private.code_block_table[current_buf].loaded_regex[lang_name].cluster
                                    )
                                    vim.cmd(command)
                                end
                            end
                        end
                    end

                    -- reset some values after including
                    vim.api.nvim_buf_set_option(buf, "iskeyword", is_keyword)
                    if current_syntax ~= "" or current_syntax ~= nil then
                        vim.b.current_syntax = current_syntax
                    else
                        vim.b.current_syntax = ""
                    end

                    has_syntax = string.format("syntax list %s", snip)
                    _, result = pcall(vim.api.nvim_exec, has_syntax, true)
                    count = select(2, result:gsub("\n", "\n")) -- get length of result from syn list

                    --[[
                        if we see "-" it means there potentially is already a region for this lang
                        we must have only 1 line, more lines means there is a region already
                        see :h syn-list for the format
                    --]]
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
                        -- sync everything
                        module.public.sync_regex_code_blocks(buf, lang_name, from, to)
                    end

                    vim.o.foldmethod = foldmethod
                    vim.o.foldexpr = foldexpr
                    vim.o.foldtext = foldtext
                    vim.o.foldnestmax = foldnestmax
                    vim.o.foldcolumn = foldcolumn
                    vim.o.foldenable = foldenable
                    vim.o.foldminlines = foldminlines
                end

                vim.b.current_syntax = ""
                module.private.last_buffer = vim.api.nvim_buf_get_name(buf)
            end
        end
        -- end)
    end,

    -- remove loaded syntax include and snip region
    remove_syntax = function(group, snip)
        -- these clears are silent. errors do not matter
        -- errors are assumed to come from the functions that call this
        local group_remove = string.format("silent! syntax clear @%s", group)
        vim.cmd(group_remove)

        local snip_remove = string.format("silent! syntax clear %s", snip)
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
            if curr_table.type == "syntax" then
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

                local snip = string.format("textSnip%s", string.upper(lang_name))
                local start_marker = string.format("@code %s", lang_name)
                -- local end_marker = "@end"
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

                -- NOTE: this is kept as a just in case
                -- sync back from end block
                -- regex_fallback_hl = string.format(
                --     [[
                --         syntax sync match %s
                --         \ groupthere %s
                --         \ "%s"
                --     ]],
                --     snip,
                --     snip,
                --     end_marker
                -- )
                -- TODO check groupthere, a slower process
                -- vim.cmd(string.format("silent! %s", regex_fallback_hl))
                -- vim.cmd("syntax sync maxlines=100")
            end
            ::continue::
        end
    end,
}

module.config.public = {
    -- note that these come from core.norg.concealer as well
    performance = {
        increment = 1250,
        timeout = 0,
        interval = 500,
        max_debounce = 5,
    },
}

module.load = function()
    -- Enabled the required autocommands
    -- This is generally any potential redraw event
    module.required["core.autocommands"].enable_autocommand("BufEnter")
    module.required["core.autocommands"].enable_autocommand("ColorScheme")
    module.required["core.autocommands"].enable_autocommand("TextChanged")
    -- module.required["core.autocommands"].enable_autocommand("TextChangedI")

    -- module.required["core.autocommands"].enable_autocommand("InsertEnter")
    module.required["core.autocommands"].enable_autocommand("InsertLeave")
    module.required["core.autocommands"].enable_autocommand("VimLeavePre")

    -- Load available regex languages
    -- get the available regex files for the current session
    module.private.available_languages = require("neorg.external.helpers").get_language_list(false)
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

        if line_count < module.config.public.performance.increment then
            module.public.check_code_block_type(buf, false)
            module.public.trigger_highlight_regex_code_block(buf, false, false)
        else
            -- This bit of code gets triggered if the line count of the file is bigger than one increment level
            -- provided by the user.
            -- In this case, the syntax trigger enters a block mode and splits up the file into chunks. It then goes through each
            -- chunk at a set interval and applies the syntax that way to reduce load and improve performance.

            -- This points to the current block the user's cursor is in
            local block_current =
                math.floor((line_count / module.config.public.performance.increment) % event.cursor_position[1])

            local function trigger_syntax_for_block(block)
                local line_begin = block == 0 and 0 or block * module.config.public.performance.increment - 1
                local line_end = math.min(
                    block * module.config.public.performance.increment + module.config.public.performance.increment - 1,
                    line_count
                )

                module.public.check_code_block_type(buf, false, line_begin, line_end)
                module.public.trigger_highlight_regex_code_block(buf, false, false, line_begin, line_end)
            end

            trigger_syntax_for_block(block_current)

            local block_bottom, block_top = block_current - 1, block_current + 1

            local timer = vim.loop.new_timer()

            timer:start(
                module.config.public.performance.timeout,
                module.config.public.performance.interval,
                vim.schedule_wrap(function()
                    local block_bottom_valid = block_bottom == 0
                        or (block_bottom * module.config.public.performance.increment - 1 >= 0)
                    local block_top_valid = block_top * module.config.public.performance.increment - 1 < line_count

                    if not block_bottom_valid and not block_top_valid then
                        timer:stop()
                        return
                    end

                    if block_bottom_valid then
                        trigger_syntax_for_block(block_bottom)
                        block_bottom = block_bottom - 1
                    end

                    if block_top_valid then
                        trigger_syntax_for_block(block_top)
                        block_top = block_top + 1
                    end
                end)
            )
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
                    true,
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
                    true,
                    module.private.largest_change_start,
                    module.private.largest_change_end
                )
            end

            module.private.largest_change_start, module.private.largest_change_end = -1, -1
        end)
    elseif event.type == "core.autocommands.events.vimleavepre" then
        module.private.disable_deferred_updates = true
        -- this autocmd is used to fix hi link syntax languages
        -- TEMP(vhyrro): Temporarily removed for testing - executes code twice when it should not.
        -- elseif event.type == "core.autocommands.events.textchanged" then
        -- module.private.trigger_highlight_regex_code_block(event.buffer, false, true)
        -- elseif event.type == "core.autocommands.events.textchangedi" then
        --     module.private.trigger_highlight_regex_code_block(event.buffer, false, true)
    elseif event.type == "core.autocommands.events.colorscheme" then
        module.public.trigger_highlight_regex_code_block(event.buffer, true, false)
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
