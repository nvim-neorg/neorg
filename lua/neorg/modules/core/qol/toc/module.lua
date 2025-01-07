--[[
    file: TOC
    title: A Bird's Eye View of Norg Documents
    description: The TOC module generates a table of contents for a given Norg buffer.
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
local modules, utils, log = neorg.modules, neorg.utils, neorg.log

local module = modules.create("core.qol.toc")

module.setup = function()
    return {
        requires = { "core.integrations.treesitter", "core.ui" },
    }
end

---Track if the next TOC open was automatic. Used to determine if we should enter the TOC or not.
local next_open_is_auto = false
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

    if module.config.public.auto_toc.open then
        vim.api.nvim_create_autocmd("BufWinEnter", {
            pattern = "*.norg",
            callback = function()
                vim.schedule(function()
                    if vim.bo.filetype == "norg" then
                        next_open_is_auto = true
                        vim.cmd([[Neorg toc]])
                    end
                end)
            end,
        })
    end
end

module.config.public = {
    -- close the Table of Contents after an entry in the table is picked
    close_after_use = false,

    -- width of the Table of Contents window will automatically fit its longest line, up to
    -- `max_width`
    fit_width = true,

    -- max width of the ToC window when `fit_width = true` (in columns)
    max_width = 30,

    -- when set, the ToC window will always be this many cols wide.
    -- will override `fit_width` and ignore `max_width`
    fixed_width = nil,

    -- enable `cursorline` in the ToC window, and sync the cursor position between ToC and content
    -- window
    sync_cursorline = true,

    -- Enter a ToC window opened manually (any ToC window not opened by auto_toc)
    enter = true,

    -- options for automatically opening/entering the ToC window
    auto_toc = {
        -- automatically open a ToC window when entering any `norg` buffer
        open = false,
        -- enter an automatically opened ToC window
        enter = false,
        -- automatically close the ToC window when there is no longer an open norg buffer
        close = true,
        -- will exit nvim if the ToC is the last buffer on the screen, similar to help windows
        exit_nvim = true,
    },
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

---@class core.qol.toc
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
                    title = nil
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

        if not vim.api.nvim_buf_is_valid(ui_buffer) then
            log.error("update_toc called with invalid ui buffer")
            return
        end

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

        ---@type vim.treesitter.Query
        toc_query = toc_query
            or utils.ts_parse_query(
                "norg",
                [[ (
                  [(heading1_prefix)
                   (heading2_prefix)
                   (heading3_prefix)
                   (heading4_prefix)
                   (heading5_prefix)
                   (heading6_prefix)
                  ] @prefix
                  state: (detached_modifier_extension . (_)@modifier)?
                  title: (paragraph_segment) @title
                ) ]]
            )

        local norg_root = module.required["core.integrations.treesitter"].get_document_root(norg_buffer)
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
                if norg_window == -1 then
                    local toc_window = vim.fn.bufwinid(ui_data.buffer)
                    local buf_width = nil
                    if toc_window ~= -1 then
                        buf_width = vim.api.nvim_win_get_width(toc_window) - module.private.get_toc_width(ui_data)
                        if buf_width < 1 then
                            buf_width = nil
                        end
                    end
                    norg_window =
                        vim.api.nvim_open_win(norg_buffer, true, { win = 0, vertical = true, width = buf_width })
                else
                    vim.api.nvim_set_current_win(norg_window)
                    vim.api.nvim_set_current_buf(norg_buffer)
                end
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

module.private = {
    ---get the width of the ToC window
    ---@param ui_data table
    ---@return number
    get_toc_width = function(ui_data)
        if type(module.config.public.fixed_width) == "number" then
            return module.config.public.fixed_width
        end
        local max_virtcol_1bex = module.private.get_max_virtcol(ui_data.window)
        local current_winwidth = vim.api.nvim_win_get_width(ui_data.window)
        local new_winwidth = math.min(current_winwidth, module.config.public.max_width, max_virtcol_1bex - 1)
        return new_winwidth + 1
    end,

    get_max_virtcol = function(win)
        local n_line = vim.fn.line("$", win)
        local result = 1
        for i = 1, n_line do
            result = math.max(result, vim.fn.virtcol({ i, "$" }, 0, win))
        end
        return result
    end,
}

local function get_norg_ui(norg_buffer)
    local tabpage = vim.api.nvim_win_get_tabpage(vim.fn.bufwinid(norg_buffer))
    return ui_data_of_tabpage[tabpage]
end

---Guard an autocommand callback function with a check that the ToC is still open
---@param listener function
---@return function
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

---Create a split window and buffer for the table of contents. Set buffer and window options
---accordingly
---@param tabpage number
---@param split_dir "left" | "right"
---@param enter boolean
---@return table
local function create_ui(tabpage, split_dir, enter)
    assert(tabpage == vim.api.nvim_get_current_tabpage())

    toc_namespace = toc_namespace or vim.api.nvim_create_namespace("neorg/toc")
    local ui_buffer, ui_window = module.required["core.ui"].create_vsplit(
        ("toc-%d"):format(tabpage),
        enter,
        { ft = "norg" },
        { split = split_dir, win = 0, style = "minimal" }
    )

    local ui_wo = vim.wo[ui_window]
    ui_wo.scrolloff = 999
    ui_wo.conceallevel = 0
    ui_wo.foldmethod = "expr"
    ui_wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    ui_wo.foldlevel = 99
    ui_wo.winfixbuf = true

    if module.config.public.sync_cursorline then
        ui_wo.cursorline = true
    end

    local ui_data = {
        buffer = ui_buffer,
        tabpage = tabpage,
        window = ui_window,
    }

    ui_data_of_tabpage[tabpage] = ui_data

    return ui_data
end

--- should we enter the ToC window?
local function enter_toc_win()
    local do_enter = module.config.public.enter
    if next_open_is_auto then
        do_enter = module.config.public.auto_toc.enter
    end
    return do_enter
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
        if norg_buffer == ui_data_of_tabpage[tabpage].buffer then
            return
        end
        module.public.update_toc(toc_title, ui_data_of_tabpage[tabpage], norg_buffer)

        if enter_toc_win() then
            vim.api.nvim_set_current_win(ui_data_of_tabpage[tabpage].window)
        end
        return
    end

    local ui_data = create_ui(tabpage, event.content[1] or "left", enter_toc_win())
    next_open_is_auto = false

    module.public.update_toc(toc_title, ui_data_of_tabpage[tabpage], norg_buffer)

    if module.config.public.fit_width then
        vim.api.nvim_win_set_width(ui_data.window, module.private.get_toc_width(ui_data))
    end

    local close_buffer_callback = function()
        -- Check if ui_buffer exists before deleting it
        if vim.api.nvim_buf_is_loaded(ui_data.buffer) then
            vim.api.nvim_buf_delete(ui_data.buffer, { force = true })
        end
        ui_data_of_tabpage[tabpage] = nil
    end

    vim.keymap.set("n", "q", close_buffer_callback, { buffer = ui_data.buffer })

    --- WinClosed matches against the win number as a string, not the buf number
    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(ui_data.window),
        callback = close_buffer_callback,
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

    if module.config.public.auto_toc.exit_nvim then
        vim.api.nvim_create_autocmd("WinEnter", {
            buffer = ui_data.buffer,
            callback = unlisten_if_closed(function(_, _)
                vim.schedule(function()
                    -- count the number of 'real' (non-floating) windows. This avoids noice popups
                    -- and nvim notify popups causing nvim to stay open
                    local real_windows = vim.iter(vim.api.nvim_list_wins())
                        :filter(function(win)
                            return vim.api.nvim_win_get_config(win).relative == ""
                        end)
                        :totable()
                    if #real_windows == 1 then
                        vim.schedule(vim.cmd.q)
                    end
                end)
            end),
        })
    end

    if module.config.public.auto_toc.close then
        vim.api.nvim_create_autocmd("BufWinLeave", {
            pattern = "*.norg",
            callback = unlisten_if_closed(function(_buf, ui)
                vim.schedule(function()
                    if vim.fn.winnr("$") > 1 then
                        local win = vim.fn.bufwinid(ui.buffer)
                        if win ~= -1 then
                            vim.api.nvim_win_close(win, true)
                            close_buffer_callback()
                        end
                    end
                end)
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
