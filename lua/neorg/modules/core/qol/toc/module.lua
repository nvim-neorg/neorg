--[[
    file: TOC
    title: A Bird's Eye View of Norg Documents
    description: The TOC module geneates a table of contents for a given Norg buffer.
    summary: Generates a table of contents for a given Norg buffer.
    ---
<!-- TODO: make nested objects also appear nested within the TOC view (i.e. headings in headings) -->

The TOC module exposes a single command - `:Neorg toc`. This command can be executed with one of three
optional arguments: `left`, `right` and `qflist`.

When `left` or `right` is supplied, the Table of Contents split is placed on that side of the screen.
When the `qflist` argument is provided, the whole table of contents is sent to the Neovim quickfix list,
should that be more convenient for you.

When in the TOC view, `<CR>` can be pressed on any of the entries to move to that location in the respective
Norg document. The TOC view updates automatically when switching buffers.
--]]

local neorg = require("neorg.core")
local modules, utils = neorg.modules, neorg.utils

local module = modules.create("core.qol.toc")

module.setup = function()
    return {
        requires = { "core.integrations.treesitter", "core.ui" },
    }
end

module.load = function()
    modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            toc = {
                name = "core.qol.toc",
                max_args = 1,
                condition = "norg",
                complete = {
                    { "left", "right", "qflist" },
                },
            },
        })
    end)
end

module.config.public = {
    -- If `true`, will close the Table of Contents after an entry in the table
    -- is picked.
    close_after_use = false,

    -- If `true`, the width of the Table of Contents window will automatically
    -- fit its longest line
    fit_width = true,

    -- A function that takes node type as argument and returns true if this
    -- type of node should appear in the Table of Contents
    toc_filter = function(node_type)
        return node_type:match("^heading")
    end,

    -- If `true`, `cursurline` will be enabled (highlighted) in the ToC window,
    -- and the cursor position between ToC and content window will be synchronized.
    sync_cursorline = true,
}

local data_of_ui_buf = {}
local data_of_norg_win = {}
local toc_namespace

local function upper_bound(array, v)
    -- assume array is sorted
    -- find index of first element in array that is > v
    local l = 1
    local r = #array

    while l <= r do
        local m = math.floor((l + r) / 2)
        if v >= array[m] then
            l = m + 1
        else
            r = m - 1
        end
    end

    return l
end

local function get_target_location_under_cursor(ui_buffer, original_buffer)
    local ui_window = vim.fn.bufwinid(ui_buffer)
    local original_window = vim.fn.bufwinid(original_buffer)

    local curline = vim.api.nvim_win_get_cursor(ui_window)[1]
    local offset = data_of_ui_buf[ui_buffer].start_lines.offset
    local extmark_lookup = data_of_norg_win[original_window].extmarks[curline - offset]

    if not extmark_lookup then
        return
    end

    return vim.api.nvim_buf_get_extmark_by_id(original_buffer, toc_namespace, extmark_lookup, {})
end

module.public = {
    parse_toc_macro = function(buffer)
        local toc, toc_name = false, nil

        local success = module.required["core.integrations.treesitter"].execute_query(
            [[
        (infirm_tag
            (tag_name) @name
            (tag_parameters)? @parameters)
        ]],
            function(query, id, node)
                local capture_name = query.captures[id]

                if
                    capture_name == "name"
                    and module.required["core.integrations.treesitter"].get_node_text(node, buffer):lower() == "toc"
                then
                    toc = true
                elseif capture_name == "parameters" and toc then
                    toc_name = module.required["core.integrations.treesitter"].get_node_text(node, buffer)
                    return true
                end
            end,
            buffer
        )

        if not success then
            return
        end

        return toc_name
    end,

    generate_qflist = function(original_buffer)
        local prefix, title
        local qflist_data = {}

        local success = module.required["core.integrations.treesitter"].execute_query(
            [[
            (_
              .
              (_) @prefix
              .
              title: (paragraph_segment) @title)
            ]],
            function(query, id, node)
                local capture = query.captures[id]

                if capture == "prefix" then
                    if node:type():match("_prefix$") then
                        prefix = node
                    else
                        prefix = nil
                    end
                elseif capture == "title" then
                    title = node
                end

                if prefix and title then
                    local prefix_text =
                        module.required["core.integrations.treesitter"].get_node_text(prefix, original_buffer)
                    local title_text =
                        module.required["core.integrations.treesitter"].get_node_text(title, original_buffer)

                    if prefix_text:sub(1, 1) ~= "*" and prefix_text:match("^%W%W") then
                        prefix_text = table.concat({ prefix_text:sub(1, 1), " " })
                    end

                    table.insert(qflist_data, {
                        bufnr = original_buffer,
                        lnum = (prefix:start()) + 1,
                        text = table.concat({ prefix_text, title_text }),
                    })

                    prefix, title = nil, nil
                end
            end,
            original_buffer
        )

        if not success then
            return
        end

        return qflist_data
    end,

    update_cursor = function(original_buffer, ui_buffer)
        local original_window = vim.fn.bufwinid(original_buffer)
        local ui_window = vim.fn.bufwinid(ui_buffer)

        local current_row_1b = vim.fn.line(".", original_window)
        if data_of_norg_win[original_window].last_row == current_row_1b then
            return
        end
        data_of_norg_win[original_window].last_row = current_row_1b

        local start_lines = data_of_ui_buf[ui_buffer].start_lines
        assert(start_lines)

        local current_toc_item_idx = upper_bound(start_lines, current_row_1b - 1) - 1
        local current_toc_row = (
            current_toc_item_idx == 0 and math.max(1, start_lines.offset)
            or current_toc_item_idx + start_lines.offset
        )
        vim.api.nvim_win_set_cursor(ui_window, { current_toc_row, 0 })
    end,

    update_toc = function(toc_title, original_buffer, original_window, ui_buffer, ui_window)
        vim.bo[ui_buffer].modifiable = true
        vim.api.nvim_buf_clear_namespace(original_buffer, toc_namespace, 0, -1)

        table.insert(toc_title, "")
        vim.api.nvim_buf_set_lines(ui_buffer, 0, -1, true, toc_title)
        local ui_buf_data = {}
        data_of_ui_buf[ui_buffer] = ui_buf_data

        local norg_win_data = {}
        data_of_norg_win[original_window] = norg_win_data

        local prefix, title
        local extmarks = {}
        norg_win_data.extmarks = extmarks

        local offset = vim.api.nvim_buf_line_count(ui_buffer)
        local start_lines = { offset = offset }
        ui_buf_data.start_lines = start_lines

        local toc_filter = module.config.public.toc_filter

        local success = module.required["core.integrations.treesitter"].execute_query(
            [[
            (_
              .
              (_) @prefix
              (detached_modifier_extension
                (todo_item_cancelled))? @cancelled
              title: (paragraph_segment) @title)
            ]],
            function(query, id, node)
                local capture = query.captures[id]

                if capture == "prefix" then
                    if
                        node:type():match("_prefix$") and (type(toc_filter) ~= "function" or toc_filter(node:type()))
                    then
                        prefix = node
                    else
                        prefix = nil
                    end
                    title = nil
                elseif capture == "title" then
                    title = node
                elseif capture == "cancelled" then
                    prefix = nil
                end

                if prefix and title then
                    local _, column = title:start()

                    table.insert(
                        extmarks,
                        vim.api.nvim_buf_set_extmark(original_buffer, toc_namespace, (prefix:start()), column, {})
                    )

                    table.insert(start_lines, (prefix:start()))

                    local prefix_text =
                        module.required["core.integrations.treesitter"].get_node_text(prefix, original_buffer)
                    local title_text =
                        vim.trim(module.required["core.integrations.treesitter"].get_node_text(title, original_buffer))

                    if prefix_text:sub(1, 1) ~= "*" and prefix_text:match("^%W%W") then
                        prefix_text = table.concat({ prefix_text:sub(1, 1), " " })
                    end

                    vim.api.nvim_buf_set_lines(
                        ui_buffer,
                        -1,
                        -1,
                        true,
                        { table.concat({ prefix_text, title_text }) }
                    )

                    prefix, title = nil, nil
                end
            end,
            original_buffer
        )

        vim.bo[ui_buffer].modifiable = false

        if not success then
            return
        end

        vim.api.nvim_buf_set_keymap(ui_buffer, "n", "<CR>", "", {
            callback = function()
                local location = get_target_location_under_cursor(ui_buffer, original_buffer)
                if not location then
                    return
                end

                vim.api.nvim_set_current_win(original_window)
                vim.api.nvim_set_current_buf(original_buffer)
                vim.api.nvim_win_set_cursor(original_window, { location[1] + 1, location[2] })

                if module.config.public.close_after_use then
                    vim.api.nvim_buf_delete(ui_buffer, { force = true })
                end
            end,
        })
    end,
}

local function get_max_virtcol()
    local n_line = vim.fn.line("$")
    local result = 1
    for i = 1, n_line do
        -- FIXME: for neovim <=0.9.*, virtcol() doesn't accept winid argument
        result = math.max(result, vim.fn.virtcol({ i, "$" }))
    end
    return result
end

local function unlisten_if_closed(ui_buffer, listener)
    return function(ev)
        if not vim.api.nvim_buf_is_valid(ui_buffer) or not vim.api.nvim_buf_is_loaded(ui_buffer) then
            return true
        end

        return listener(ev)
    end
end

module.on_event = function(event)
    if event.split_type[2] ~= module.name then
        return
    end

    local toc_title = vim.split(module.public.parse_toc_macro(event.buffer) or "Table of Contents", "\n")

    if event.content and event.content[1] == "qflist" then
        local qflist = module.public.generate_qflist(event.buffer)

        if not qflist then
            utils.notify("An error occurred and the qflist could not be generated", vim.log.levels.WARN)
            return
        end

        vim.fn.setqflist(qflist, "r")
        vim.fn.setqflist({}, "a", { title = toc_title[1] })
        vim.cmd.copen()

        return
    end

    -- FIXME(vhyrro): When the buffer already exists then simply refresh the buffer
    -- instead of erroring out.
    toc_namespace = toc_namespace or vim.api.nvim_create_namespace("neorg/toc")
    local ui_buffer, ui_window =
        module.required["core.ui"].create_vsplit("toc", { ft = "norg" }, (event.content[1] or "left") == "left")

    vim.wo[ui_window].scrolloff = 999
    vim.wo[ui_window].conceallevel = 0
    vim.wo[ui_window].foldmethod = "expr"
    vim.wo[ui_window].foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.wo[ui_window].foldlevel = 99

    if module.config.public.sync_cursorline then
        vim.api.nvim_win_set_option(ui_window, "cursorline", true)
    end

    module.public.update_toc(toc_title, event.buffer, event.window, ui_buffer, ui_window)
    if module.config.public.sync_cursorline then
        module.public.update_cursor(event.buffer, ui_buffer)
    end

    if module.config.public.fit_width then
        local max_virtcol_1bex = get_max_virtcol()
        local current_winwidth = vim.fn.winwidth(ui_window)
        local new_winwidth = math.min(current_winwidth, math.max(30, max_virtcol_1bex - 1))
        vim.cmd(("vertical resize %d"):format(new_winwidth + 1)) -- +1 for margin
    end

    local close_buffer_callback = function()
        -- Check if ui_buffer exists before deleting it
        if vim.api.nvim_buf_is_loaded(ui_buffer) then
            vim.api.nvim_buf_delete(ui_buffer, { force = true })
        end
    end

    vim.api.nvim_buf_set_keymap(ui_buffer, "n", "q", "", {
        callback = close_buffer_callback,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = ui_buffer,
        once = true,
        callback = close_buffer_callback,
    })

    do
        local norg_buffer, norg_window = event.buffer, event.window
        local ui_cursor_start_moving = false

        vim.api.nvim_create_autocmd("BufWritePost", {
            pattern = "*.norg",
            callback = unlisten_if_closed(ui_buffer, function(_ev)
                toc_title = vim.split(module.public.parse_toc_macro(norg_buffer) or "Table of Contents", "\n")
                module.public.update_toc(toc_title, norg_buffer, norg_window, ui_buffer, ui_window)
                if module.config.public.sync_cursorline then
                    data_of_norg_win[norg_window].last_row = nil -- invalidate cursor cache
                    module.public.update_cursor(norg_buffer, ui_buffer)
                end
            end),
        })

        vim.api.nvim_create_autocmd("BufEnter", {
            pattern = "*.norg",
            callback = unlisten_if_closed(ui_buffer, function(_ev)
                local buf = vim.api.nvim_get_current_buf()

                if buf == ui_buffer or norg_buffer == buf then
                    return
                end

                norg_buffer = buf
                local norg_window = vim.fn.bufwinid(norg_buffer)

                toc_title = vim.split(module.public.parse_toc_macro(buf) or "Table of Contents", "\n")
                module.public.update_toc(toc_title, norg_buffer, norg_window, ui_buffer, ui_window)
                if module.config.public.sync_cursorline then
                    module.public.update_cursor(norg_buffer, ui_buffer)
                end
            end),
        })

        -- Sync cursor: ToC -> content
        if module.config.public.sync_cursorline then
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                buffer = ui_buffer,
                callback = function(ev)
                    assert(ev.buf == ui_buffer)

                    if not norg_buffer then
                        return
                    end

                    -- Ignore the first (fake) CursorMoved coming together with BufEnter of the ToC buffer
                    if ui_cursor_start_moving then
                        local location = get_target_location_under_cursor(ui_buffer, norg_buffer)
                        if location then
                            local ui_window = vim.fn.bufwinid(ui_buffer)
                            local norg_window = vim.fn.bufwinid(norg_buffer)
                            vim.api.nvim_win_set_cursor(norg_window, { location[1] + 1, location[2] })
                            vim.api.nvim_set_current_win(norg_window)
                            vim.cmd("normal! zz")
                            vim.api.nvim_set_current_win(ui_window)
                        end
                    end
                    ui_cursor_start_moving = true
                end,
            })

            -- Sync cursor: content -> ToC
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                pattern = "*.norg",
                callback = unlisten_if_closed(ui_buffer, function(ev)
                    if ev.buf ~= norg_buffer then
                        return
                    end

                    if not data_of_norg_win[vim.fn.bufwinid(norg_buffer)] then
                        -- toc not yet created because BufEnter is not yet triggered
                        return
                    end

                    module.public.update_cursor(norg_buffer, ui_buffer)
                end),
            })

            -- Ignore the first (fake) CursorMoved coming together with BufEnter of the ToC buffer
            vim.api.nvim_create_autocmd("BufEnter", {
                buffer = ui_buffer,
                callback = function(_ev)
                    ui_cursor_start_moving = false
                end,
            })

            -- When leaving the content buffer, add its last cursor position to jump list
            vim.api.nvim_create_autocmd("BufLeave", {
                pattern = "*.norg",
                callback = unlisten_if_closed(ui_buffer, function(_ev)
                    vim.cmd("normal! m'")
                end),
            })

            vim.api.nvim_create_autocmd("BufHidden", {
                pattern = "*.norg",
                callback = unlisten_if_closed(ui_buffer, function(ev)
                    if ev.buf == norg_buffer then
                        norg_buffer = nil
                        norg_window = nil
                        return
                    end
                end),
            })
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        [module.name] = true,
    },
}

return module
