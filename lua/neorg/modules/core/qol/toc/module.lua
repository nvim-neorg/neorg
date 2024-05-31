--[[
    file: TOC
    title: A Bird's Eye View of Norg Documents
    description: The TOC module geneates a table of contents for a given Norg buffer.
    summary: Generates a table of contents for a given Norg buffer.
    ---

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
        requires = { "core.treesitter", "core.ui" },
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

    -- If `true`, `cursurline` will be enabled (highlighted) in the ToC window,
    -- and the cursor position between ToC and content window will be synchronized.
    sync_cursorline = true,
}

local ui_data_of_tabpage = {}
local data_of_norg_buf = {}
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

local function get_target_location_under_cursor(ui_data)
    local ui_window = vim.fn.bufwinid(ui_data.buffer)
    local curline = vim.api.nvim_win_get_cursor(ui_window)[1]
    local offset = ui_data.start_lines.offset
    local extmark_lookup = data_of_norg_buf[ui_data.norg_buffer].extmarks[curline - offset]

    if not extmark_lookup then
        return
    end

    return vim.api.nvim_buf_get_extmark_by_id(ui_data.norg_buffer, toc_namespace, extmark_lookup, {})
end

local toc_query

module.public = {
    parse_toc_macro = function(buffer)
        local toc, toc_name = false, nil

        local success = module.required["core.treesitter"].execute_query(
            [[
        (infirm_tag
            (tag_name) @name
            (tag_parameters)? @parameters)
        ]],
            function(query, id, node)
                local capture_name = query.captures[id]

                if
                    capture_name == "name"
                    and module.required["core.treesitter"].get_node_text(node, buffer):lower() == "toc"
                then
                    toc = true
                elseif capture_name == "parameters" and toc then
                    toc_name = module.required["core.treesitter"].get_node_text(node, buffer)
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

        local success = module.required["core.treesitter"].execute_query(
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
                    title = nil
                elseif capture == "title" then
                    title = node
                end

                if prefix and title then
                    local prefix_text =
                        module.required["core.treesitter"].get_node_text(prefix, original_buffer)
                    local title_text =
                        module.required["core.treesitter"].get_node_text(title, original_buffer)

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

    -- Update ui cursor according to norg cursor
    update_cursor = function(ui_data)
        local norg_window = vim.fn.bufwinid(ui_data.norg_buffer)
        local norg_data = data_of_norg_buf[ui_data.norg_buffer]
        local ui_window = vim.fn.bufwinid(ui_data.buffer)
        assert(ui_window ~= -1)

        local current_row_1b = vim.fn.line(".", norg_window)
        if norg_data.last_row == current_row_1b then
            return
        end
        norg_data.last_row = current_row_1b

        local start_lines = ui_data.start_lines
        assert(start_lines)

        local current_toc_item_idx = upper_bound(start_lines, current_row_1b - 1) - 1
        local current_toc_row = (
            current_toc_item_idx == 0 and math.max(1, start_lines.offset)
            or current_toc_item_idx + start_lines.offset
        )
        vim.api.nvim_win_set_cursor(ui_window, { current_toc_row, 0 })
    end,

    update_toc = function(toc_title, ui_data, norg_buffer)
        local ui_buffer = ui_data.buffer
        ui_data.norg_buffer = norg_buffer

        vim.bo[ui_buffer].modifiable = true
        vim.api.nvim_buf_clear_namespace(norg_buffer, toc_namespace, 0, -1)

        table.insert(toc_title, "")
        vim.api.nvim_buf_set_lines(ui_buffer, 0, -1, true, toc_title)

        local norg_data = {}
        data_of_norg_buf[norg_buffer] = norg_data

        local extmarks = {}
        norg_data.extmarks = extmarks

        local offset = vim.api.nvim_buf_line_count(ui_buffer)
        local start_lines = { offset = offset }
        ui_data.start_lines = start_lines

        toc_query = toc_query
            or utils.ts_parse_query(
                "norg",
                [[
        (
            [(heading1_prefix)(heading2_prefix)(heading3_prefix)(heading4_prefix)(heading5_prefix)(heading6_prefix)]@prefix
            .
            state: (detached_modifier_extension (_)@modifier)?
            .
            title: (paragraph_segment)@title
        )]]
            )

        local norg_root = module.required["core.treesitter"].get_document_root(norg_buffer)
        if not norg_root then
            return
        end

        local current_capture
        local heading_nodes = {}
        for id, node in toc_query:iter_captures(norg_root, norg_buffer) do
            local type = toc_query.captures[id]
            if type == "prefix" then
                current_capture = {}
                table.insert(heading_nodes, current_capture)
            end
            current_capture[type] = node
        end

        local heading_texts = {}
        for _, capture in ipairs(heading_nodes) do
            if capture.modifier and capture.modifier:type() == "todo_item_cancelled" then
                goto continue
            end

            local row_start_0b, col_start_0b, _, _ = capture.prefix:range()
            local _, _, row_end_0bin, col_end_0bex = capture.title:range()

            table.insert(start_lines, row_start_0b)
            table.insert(
                extmarks,
                vim.api.nvim_buf_set_extmark(norg_buffer, toc_namespace, row_start_0b, col_start_0b, {})
            )

            for _, line in
                ipairs(
                    vim.api.nvim_buf_get_text(norg_buffer, row_start_0b, col_start_0b, row_end_0bin, col_end_0bex, {})
                )
            do
                table.insert(heading_texts, line)
            end

            ::continue::
        end

        vim.api.nvim_buf_set_lines(ui_buffer, -1, -1, true, heading_texts)

        vim.bo[ui_buffer].modifiable = false

        vim.api.nvim_buf_set_keymap(ui_buffer, "n", "<CR>", "", {
            callback = function()
                local location = get_target_location_under_cursor(ui_data)
                if not location then
                    return
                end

                local norg_window = vim.fn.bufwinid(norg_buffer)
                vim.api.nvim_set_current_win(norg_window)
                vim.api.nvim_set_current_buf(norg_buffer)
                vim.api.nvim_win_set_cursor(norg_window, { location[1] + 1, location[2] })

                if module.config.public.close_after_use then
                    vim.api.nvim_buf_delete(ui_buffer, { force = true })
                end
            end,
        })

        if module.config.public.sync_cursorline then
            module.public.update_cursor(ui_data)
        end
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

local function get_norg_ui(norg_buffer)
    local tabpage = vim.api.nvim_win_get_tabpage(vim.fn.bufwinid(norg_buffer))
    return ui_data_of_tabpage[tabpage]
end

local function unlisten_if_closed(listener)
    return function(ev)
        if vim.tbl_isempty(ui_data_of_tabpage) then
            return true
        end

        local norg_buffer = ev.buf
        local ui_data = get_norg_ui(norg_buffer)
        if not ui_data or vim.fn.bufwinid(ui_data.buffer) == -1 then
            return
        end

        return listener(norg_buffer, ui_data)
    end
end

local function create_ui(tabpage, mode)
    assert(tabpage == vim.api.nvim_get_current_tabpage())

    toc_namespace = toc_namespace or vim.api.nvim_create_namespace("neorg/toc")
    local ui_buffer, ui_window =
        module.required["core.ui"].create_vsplit(("toc-%d"):format(tabpage), { ft = "norg" }, mode)

    local ui_wo = vim.wo[ui_window]
    ui_wo.scrolloff = 999
    ui_wo.conceallevel = 0
    ui_wo.foldmethod = "expr"
    ui_wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    ui_wo.foldlevel = 99

    if module.config.public.sync_cursorline then
        ui_wo.cursorline = true
    end

    local ui_data = {
        buffer = ui_buffer,
        tabpage = tabpage,
    }

    ui_data_of_tabpage[tabpage] = ui_data

    return ui_data
end

module.on_event = function(event)
    if event.split_type[2] ~= module.name then
        return
    end

    local toc_title = vim.split(module.public.parse_toc_macro(event.buffer) or "Table of Contents", "\n")
    local norg_buffer = event.buffer

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

    local tabpage = vim.api.nvim_win_get_tabpage(vim.fn.bufwinid(norg_buffer))
    if ui_data_of_tabpage[tabpage] then
        module.public.update_toc(toc_title, ui_data_of_tabpage[tabpage], norg_buffer)
        return
    end

    local ui_data = ui_data_of_tabpage[tabpage] or create_ui(tabpage, (event.content[1] or "left") == "left")

    module.public.update_toc(toc_title, ui_data_of_tabpage[tabpage], norg_buffer)

    if module.config.public.fit_width then
        local max_virtcol_1bex = get_max_virtcol()
        local current_winwidth = vim.fn.winwidth(vim.fn.bufwinid(ui_data.buffer))
        local new_winwidth = math.min(current_winwidth, math.max(30, max_virtcol_1bex - 1))
        vim.cmd(("vertical resize %d"):format(new_winwidth + 1)) -- +1 for margin
    end

    local close_buffer_callback = function()
        -- Check if ui_buffer exists before deleting it
        if vim.api.nvim_buf_is_loaded(ui_data.buffer) then
            vim.api.nvim_buf_delete(ui_data.buffer, { force = true })
        end
        ui_data_of_tabpage[tabpage] = nil
    end

    vim.api.nvim_buf_set_keymap(ui_data.buffer, "n", "q", "", {
        callback = close_buffer_callback,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = "*",
        callback = function(ev)
            if ev.buf == ui_data.buffer then
                close_buffer_callback()
            end
        end,
    })

    vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = "*.norg",
        callback = unlisten_if_closed(function(buf, ui)
            toc_title = vim.split(module.public.parse_toc_macro(buf) or "Table of Contents", "\n")
            data_of_norg_buf[buf].last_row = nil -- invalidate cursor cache
            module.public.update_toc(toc_title, ui, buf)
        end),
    })

    vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "*.norg",
        callback = unlisten_if_closed(function(buf, ui)
            if buf == ui.buffer or buf == ui.norg_buffer then
                return
            end

            toc_title = vim.split(module.public.parse_toc_macro(buf) or "Table of Contents", "\n")
            module.public.update_toc(toc_title, ui, buf)
        end),
    })

    -- Sync cursor: ToC -> content
    if module.config.public.sync_cursorline then
        -- Ignore the first (fake) CursorMoved coming together with BufEnter of the ToC buffer
        vim.api.nvim_create_autocmd("BufEnter", {
            buffer = ui_data.buffer,
            callback = function(_ev)
                ui_data.cursor_start_moving = false
            end,
        })

        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
            buffer = ui_data.buffer,
            callback = function(ev)
                assert(ev.buf == ui_data.buffer)

                if vim.fn.bufwinid(ui_data.norg_buffer) == -1 then
                    return
                end

                -- Ignore the first (fake) CursorMoved coming together with BufEnter of the ToC buffer
                if ui_data.cursor_start_moving then
                    local location = get_target_location_under_cursor(ui_data)
                    if location then
                        local norg_window = vim.fn.bufwinid(ui_data.norg_buffer)
                        vim.api.nvim_win_set_cursor(norg_window, { location[1] + 1, location[2] })
                        vim.api.nvim_buf_call(ui_data.norg_buffer, function()
                            vim.cmd("normal! zz")
                        end)
                    end
                end
                ui_data.cursor_start_moving = true
            end,
        })

        -- Sync cursor: content -> ToC
        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
            pattern = "*.norg",
            callback = unlisten_if_closed(function(buf, ui)
                if buf ~= ui.norg_buffer then
                    return
                end

                if not data_of_norg_buf[buf] then
                    -- toc not yet created because BufEnter is not yet triggered
                    return
                end

                module.public.update_cursor(ui)
            end),
        })

        -- When leaving the content buffer, add its last cursor position to jump list
        vim.api.nvim_create_autocmd("BufLeave", {
            pattern = "*.norg",
            callback = unlisten_if_closed(function(_norg_buffer, _ui_data)
                vim.cmd("normal! m'")
            end),
        })
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        [module.name] = true,
    },
}

return module
