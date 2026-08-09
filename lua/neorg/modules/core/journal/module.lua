--[[
    file: Journal
    title: Dear diary...
    description: The journal module allows you to take personal notes with zero friction.
    summary: Easily track a journal within Neorg.
    ---
The journal module exposes a total of seven commands.
The first three, `:Neorg journal today|yesterday|tomorrow`, allow you to access entries
for a given time relative to today. A file will be opened with the respective date as a `.norg` file.

The fourth command, `:Neorg journal custom`, allows you to specify a custom date as an argument.
The date must be formatted according to the `YYYY-mm-dd` format, e.g. `2023-01-01`.

The `:Neorg journal template` command creates a template file which will be used as the base whenever
a new journal entry is created.

The `:Neorg journal toc open|update` commands open or create/update a Table of Contents
file found in the root of the journal. This file contains links to all other journal entries, alongside
their titles.

Finally, `:Neorg journal agenda [range] [qflist]` opens a read-only, aggregated view of every journal
entry whose date falls within `range`, anchored on today. `range` may be `day`, `week` (Monday-Sunday),
`month` (the current calendar month), or a bare integer `N` meaning "the last N days including today";
it defaults to `agenda_default_range` when omitted. Unlike the table of contents, the agenda view shows
each entry's full body content, not just its title, in chronological order. Press `<CR>` on any line to
jump to that exact location in the source journal file, or `q` to close the view. Press `f`/`b` to page
the view forward/backward by one span (e.g. one week, for a `week` range), or `.` to jump back to today
-- mirroring Emacs org-agenda's `org-agenda-later`/`org-agenda-earlier`/`org-agenda-goto-today`. Passing
`qflist` as a second argument sends a one-line-per-entry summary to the quickfix list instead of opening
a buffer (this mode does not support paging).
--]]

local neorg = require("neorg.core")
local config, lib, log, modules, utils = neorg.config, neorg.lib, neorg.log, neorg.modules, neorg.utils

local module = modules.create("core.journal")

module.examples = {
    ["Changing TOC format to divide year in quarters"] = function()
        -- In your ["core.journal"] options, change toc_format to a function like this:

        require("neorg").setup({
            load = {
                -- ...
                ["core.journal"] = {
                    config = {
                        -- ...
                        toc_format = function(entries)
                            -- Convert the entries into a certain format

                            local output = {}
                            local current_year
                            local current_quarter
                            local last_quarter
                            local current_month
                            for _, entry in ipairs(entries) do
                                -- Don't print the year if it hasn't changed
                                if not current_year or current_year < entry[1] then
                                    current_year = entry[1]
                                    current_month = nil
                                    table.insert(output, "* " .. current_year)
                                end

                                -- Check to which quarter the current month corresponds to
                                if entry[2] <= 3 then
                                    current_quarter = 1
                                elseif entry[2] <= 6 then
                                    current_quarter = 2
                                elseif entry[2] <= 9 then
                                    current_quarter = 3
                                else
                                    current_quarter = 4
                                end

                                -- If the current month corresponds to another quarter, print it
                                if current_quarter ~= last_quarter then
                                    table.insert(output, "** Quarter " .. current_quarter)
                                    last_quarter = current_quarter
                                end

                                -- Don't print the month if it hasn't changed
                                if not current_month or current_month < entry[2] then
                                    current_month = entry[2]
                                    table.insert(output, "*** Month " .. current_month)
                                end

                                -- Prints the file link
                                table.insert(output, "   " .. entry[4] .. string.format("[%s]", entry[5]))
                            end

                            return output
                        end,
                        -- ...
                    },
                },
            },
        })
    end,
}

module.setup = function()
    return {
        success = true,
        requires = {
            "core.dirman",
            "core.integrations.treesitter",
            "core.ui",
        },
    }
end

---@type core.integrations.treesitter
local ts
module.load = function()
    ts = module.required["core.integrations.treesitter"] --[[@as core.integrations.treesitter]]

    if module.config.private.strategies[module.config.public.strategy] then
        module.config.public.strategy = module.config.private.strategies[module.config.public.strategy]
    end

    modules.await("core.neorgcmd", function(neorgcmd)
        neorgcmd.add_commands_from_table({
            journal = {
                min_args = 1,
                max_args = 2,
                subcommands = {
                    tomorrow = { args = 0, name = "journal.tomorrow" },
                    yesterday = { args = 0, name = "journal.yesterday" },
                    today = { args = 0, name = "journal.today" },
                    custom = { max_args = 1, name = "journal.custom" }, -- format :yyyy-mm-dd
                    template = { args = 0, name = "journal.template" },
                    toc = {
                        args = 1,
                        name = "journal.toc",
                        subcommands = {
                            open = { args = 0, name = "journal.toc.open" },
                            update = { args = 0, name = "journal.toc.update" },
                        },
                    },
                    agenda = {
                        min_args = 0,
                        max_args = 2,
                        name = "journal.agenda",
                        -- content[1] = range ("day"|"week"|"month"|"<N>"), content[2] = "qflist" (optional)
                        complete = { { "day", "week", "month" }, { "qflist" } },
                    },
                },
            },
        })
    end)
end

module.config.public = {
    -- Which workspace to use for the journal files, the default behaviour
    -- is to use the current workspace.
    --
    -- It is recommended to set this to a static workspace, but the most optimal
    -- behaviour may vary from workflow to workflow.
    workspace = nil,

    -- The name for the folder in which the journal files are put.
    journal_folder = "journal",

    -- The strategy to use to create directories.
    -- May be "flat" (`2022-03-02.norg`), "nested" (`2022/03/02.norg`),
    -- a lua string with the format given to `os.date()` or a lua function
    -- that returns a lua string with the same format.
    strategy = "nested",

    -- The name of the template file to use when running `:Neorg journal template`.
    template_name = "template.norg",

    -- Whether to apply the template file to new journal entries.
    use_template = true,

    -- Formatter function used to generate the toc file.
    -- Receives a table that contains tables like { yy, mm, dd, link, title }.
    --
    -- The function must return a table of strings.
    toc_format = nil,

    -- The default range for `:Neorg journal agenda` when no range argument is given.
    -- May be "day", "week", "month", or a lua string containing a positive integer
    -- (interpreted as "last N days including today").
    agenda_default_range = "week",

    -- Formatter function used to generate the heading for each entry in the agenda view.
    -- Receives a table `{ year, month, day, title }` for the entry, where `title` is nil
    -- if the entry has no `title` in its `@document.meta` block.
    --
    -- The function must return a single string (heading text, without a leading `*`).
    agenda_heading_format = nil,
}

module.config.private = {
    strategies = {
        flat = "%Y-%m-%d.norg",
        nested = "%Y" .. config.pathsep .. "%m" .. config.pathsep .. "%d.norg",
    },
}

-- ===== Agenda: internal state =====
---@type { buffer: integer, window: integer, source_win: integer?, line_map: table, range_kind: string?, anchor_time: number? }?
local agenda_ui

---Recursively walks the journal folder honoring both the "nested" (YYYY/MM/DD.norg)
---and "flat" (YYYY-MM-DD.norg) layouts, invoking `on_entry` for every matched day file.
---Unlike `create_toc`'s scan (which uses the async callback form of `vim.loop.fs_scandir`
---at the top level, forcing every subsequent buffer/treesitter call into `vim.schedule`),
---this walk uses the *synchronous* form throughout, so callers can safely call `vim.api`/
---treesitter functions directly inside `on_entry`.
---@param workspace_path PathlibPath
---@param folder_name string
---@param on_entry fun(year: number, month: number, day: number, relpath: string)
local function walk_journal_entries(workspace_path, folder_name, on_entry)
    local function scandir(subpath)
        local handle = vim.loop.fs_scandir(tostring(workspace_path / folder_name / (subpath or "")))
        return type(handle) == "userdata" and handle or nil
    end

    local top = scandir()
    if not top then
        return
    end

    while true do
        local name, ftype = vim.loop.fs_scandir_next(top)
        if not name then
            break
        end

        if ftype == "directory" and name:match("^%d%d%d%d$") then
            -- nested strategy: YYYY/
            local months = scandir(name)
            while months do
                local mname, mtype = vim.loop.fs_scandir_next(months)
                if not mname then
                    break
                end
                if mtype == "directory" then
                    local days = scandir(name .. config.pathsep .. mname)
                    while days do
                        local dname, dtype = vim.loop.fs_scandir_next(days)
                        if not dname then
                            break
                        end
                        local day = dtype == "file" and dname:match("^(%d%d)%.norg$")
                        if day then
                            on_entry(
                                tonumber(name),
                                tonumber(mname),
                                tonumber(day),
                                name .. config.pathsep .. mname .. config.pathsep .. dname
                            )
                        end
                    end
                end
            end
        elseif ftype == "file" then
            -- flat strategy: YYYY-MM-DD.norg
            local y, m, d = name:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%.norg$")
            if y then
                on_entry(tonumber(y), tonumber(m), tonumber(d), name)
            end
        end
    end
end

---Strips the `@document.meta ... @end` block (if present) from a buffer and returns the
---remaining body lines, plus the 0-based row at which they start in the source buffer
---(used to build accurate jump targets).
---@param bufnr integer
---@return string[] lines, integer start_row
local function get_body_lines(bufnr)
    local meta_end_row
    ts.execute_query([[ (ranged_verbatim_tag) @tag ]], function(_, _, node)
        local name_node = node:named_child(0)
        if name_node and name_node:type() == "tag_name" and ts.get_node_text(name_node, bufnr) == "document.meta" then
            local _, _, end_row = node:range()
            meta_end_row = end_row
            return true -- stop after the first (only) meta tag
        end
    end, bufnr)

    local start_row = meta_end_row and (meta_end_row + 1) or 0
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, -1, false)
    while lines[1] and lines[1]:match("^%s*$") do
        table.remove(lines, 1)
        start_row = start_row + 1
    end
    return lines, start_row
end

---Sends one line per agenda entry (title only, jumping to the top of the file) to the
---quickfix list. This is intentionally a lighter-weight summary than the full-body buffer
---view -- the quickfix list is for quick navigation between entries, not for reading content.
---@param entries table[]
local function agenda_qflist(entries)
    local qf = {}
    for _, entry in ipairs(entries) do
        local meta = ts.get_document_metadata(entry.abs_path)
        local title = meta and meta.title ~= vim.NIL and meta.title or nil
        local date = string.format("%04d-%02d-%02d", entry.year, entry.month, entry.day)
        table.insert(qf, {
            filename = entry.abs_path,
            lnum = 1,
            text = title and (date .. " - " .. title) or date,
        })
    end
    vim.fn.setqflist(qf, "r")
    vim.fn.setqflist({}, "a", { title = "Journal Agenda" })
    vim.cmd.copen()
end

---Computes the next anchor time for the `f`/`b` agenda navigation keymaps, stepping
---forward (`direction = 1`) or backward (`direction = -1`) by one span of `range_kind`.
---Mirrors Emacs org-agenda's `org-agenda-later`/`org-agenda-earlier`.
---@param range_kind string
---@param anchor_time number
---@param direction 1 | -1
---@return number
local function shift_agenda_anchor(range_kind, anchor_time, direction)
    if range_kind == "month" then
        local a = os.date("*t", anchor_time)
        return os.time({ year = a.year, month = a.month + direction, day = 1, hour = 12 })
    end

    local days = range_kind == "day" and 1 or range_kind == "week" and 7 or tonumber(range_kind) or 1
    return anchor_time + direction * days * 24 * 60 * 60
end

---Computes the entries for `range_kind`/`anchor_time`, (re)creates the read-only agenda
---scratch buffer if needed, and writes the result into it. Also wires up `<CR>` (jump to
---source), `q` (close), and `f`/`b`/`.` (page forward/backward through the range, or jump
---back to today) -- mirroring Emacs org-agenda's `org-agenda-later`/`-earlier`/`-goto-today`.
---@param range_kind string
---@param anchor_time number
local function render_agenda_buffer(range_kind, anchor_time)
    local from, to = module.public.parse_agenda_range(range_kind, anchor_time)
    if not from then
        return
    end

    local entries = module.public.get_entries_in_range(from, to)
    local body_lines, body_line_map = module.public.build_agenda_lines(entries)

    local header = string.format(
        "Journal Agenda: %s to %s (%s)%s",
        os.date("%Y-%m-%d", from),
        os.date("%Y-%m-%d", to),
        range_kind,
        vim.tbl_isempty(entries) and " -- no entries" or ""
    )

    local lines = { header, "" }
    vim.list_extend(lines, body_lines)

    local line_map = {}
    for lnum, target in pairs(body_line_map) do
        line_map[lnum + #lines - #body_lines] = target
    end

    local source_win = vim.api.nvim_get_current_win()

    if not agenda_ui or not vim.api.nvim_buf_is_valid(agenda_ui.buffer) then
        local buf, win = module.required["core.ui"].create_vsplit(
            "journal-agenda",
            true,
            { ft = "norg" },
            { split = "right", win = 0 }
        )
        agenda_ui = { buffer = buf, window = win }

        local function close()
            if agenda_ui and vim.api.nvim_buf_is_valid(agenda_ui.buffer) then
                vim.api.nvim_buf_delete(agenda_ui.buffer, { force = true })
            end
            agenda_ui = nil
        end

        vim.keymap.set("n", "q", close, { buffer = buf })
        vim.api.nvim_create_autocmd("WinClosed", { pattern = tostring(win), once = true, callback = close })

        vim.keymap.set("n", "<CR>", function()
            local lnum = vim.api.nvim_win_get_cursor(0)[1]
            local target = agenda_ui.line_map[lnum]
            if not target then
                return
            end

            local win2 = agenda_ui.source_win
            if not win2 or not vim.api.nvim_win_is_valid(win2) then
                win2 = vim.api.nvim_open_win(0, true, { win = 0, vertical = true })
            end
            vim.api.nvim_set_current_win(win2)
            vim.cmd.edit(vim.fn.fnameescape(target.path))
            vim.api.nvim_win_set_cursor(0, { target.row + 1, target.col })
        end, { buffer = buf })

        vim.keymap.set("n", "f", function()
            render_agenda_buffer(
                agenda_ui.range_kind,
                shift_agenda_anchor(agenda_ui.range_kind, agenda_ui.anchor_time, 1)
            )
        end, { buffer = buf, desc = "Journal agenda: later" })

        vim.keymap.set("n", "b", function()
            render_agenda_buffer(
                agenda_ui.range_kind,
                shift_agenda_anchor(agenda_ui.range_kind, agenda_ui.anchor_time, -1)
            )
        end, { buffer = buf, desc = "Journal agenda: earlier" })

        vim.keymap.set("n", ".", function()
            render_agenda_buffer(agenda_ui.range_kind, os.time())
        end, { buffer = buf, desc = "Journal agenda: jump to today" })
    else
        vim.api.nvim_set_current_win(agenda_ui.window)
    end

    agenda_ui.source_win = source_win
    agenda_ui.range_kind = range_kind
    agenda_ui.anchor_time = anchor_time
    agenda_ui.line_map = line_map

    vim.bo[agenda_ui.buffer].modifiable = true
    vim.api.nvim_buf_set_lines(agenda_ui.buffer, 0, -1, true, lines)
    vim.bo[agenda_ui.buffer].modifiable = false

    -- Agenda entries should read fully expanded by default, unlike regular journal
    -- entries (which may be configured to start folded via core.concealer's
    -- `init_open_folds`). The concealer computes folds asynchronously, so defer.
    local win_to_open = agenda_ui.window
    vim.schedule(function()
        if vim.api.nvim_win_is_valid(win_to_open) then
            vim.api.nvim_win_call(win_to_open, function()
                pcall(vim.cmd, "normal! zR")
            end)
        end
    end)
end

---@class core.journal
module.public = {
    version = "0.0.9",

    --- Opens a diary entry at the given time
    ---@param time? number #The time to open the journal entry at as returned by `os.time()`
    ---@param custom_date? string #A YYYY-mm-dd string that specifies a date to open the diary at instead
    open_diary = function(time, custom_date)
        -- TODO(vhyrro): Change this to use Norg dates!
        local workspace = module.config.public.workspace or module.required["core.dirman"].get_current_workspace()[1]
        local folder_name = module.config.public.journal_folder
        local template_name = module.config.public.template_name

        if custom_date then
            local year, month, day = custom_date:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")

            if not year or not month or not day then
                log.error("Wrong date format: use YYYY-mm-dd")
                return
            end

            time = os.time({
                year = year,
                month = month,
                day = day,
            })
        end

        local path = os.date(
            type(module.config.public.strategy) == "function" and module.config.public.strategy(os.date("*t", time))
                or module.config.public.strategy,
            time
        )

        local workspace_path = module.required["core.dirman"].get_workspace(workspace)

        local journal_file_exists =
            module.required["core.dirman"].file_exists(workspace_path .. "/" .. folder_name .. config.pathsep .. path)

        module.required["core.dirman"].create_file(folder_name .. config.pathsep .. path, workspace)

        module.required["core.dirman"].create_file(folder_name .. config.pathsep .. path, workspace)

        if
            not journal_file_exists
            and module.config.public.use_template
            and module.required["core.dirman"].file_exists(workspace_path .. "/" .. folder_name .. "/" .. template_name)
        then
            vim.cmd("$read " .. workspace_path .. "/" .. folder_name .. "/" .. template_name .. "| 1d | w")
        end
    end,

    --- Opens a diary entry for tomorrow's date
    diary_tomorrow = function()
        module.public.open_diary(os.time() + 24 * 60 * 60)
    end,

    --- Opens a diary entry for yesterday's date
    diary_yesterday = function()
        module.public.open_diary(os.time() - 24 * 60 * 60)
    end,

    --- Opens a diary entry for today's date
    diary_today = function()
        module.public.open_diary()
    end,

    create_template = function()
        local workspace = module.config.public.workspace
        local folder_name = module.config.public.journal_folder
        local template_name = module.config.public.template_name

        module.required["core.dirman"].create_file(
            folder_name .. config.pathsep .. template_name,
            workspace or module.required["core.dirman"].get_current_workspace()[1]
        )
    end,

    --- Opens the toc file
    open_toc = function()
        local workspace = module.config.public.workspace or module.required["core.dirman"].get_current_workspace()[1]
        local index = modules.get_module_config("core.dirman").index
        local folder_name = module.config.public.journal_folder

        -- If the toc exists, open it, if not, create it
        if module.required["core.dirman"].file_exists(folder_name .. config.pathsep .. index) then
            module.required["core.dirman"].open_file(workspace, folder_name .. config.pathsep .. index)
        else
            module.public.create_toc()
        end
    end,

    --- Creates or updates the toc file
    create_toc = function()
        local workspace = module.config.public.workspace or module.required["core.dirman"].get_current_workspace()[1]
        local index = modules.get_module_config("core.dirman").index
        local workspace_path = module.required["core.dirman"].get_workspace(workspace)
        local workspace_name_for_links = module.config.public.workspace or ""
        local folder_name = module.config.public.journal_folder

        -- Each entry is a table that contains tables like { yy, mm, dd, link, title }
        local toc_entries = {}

        -- Get a filesystem handle for the files in the journal folder
        -- path is for each subfolder
        local get_fs_handle = function(path)
            path = path or ""
            local handle =
                vim.loop.fs_scandir(workspace_path .. config.pathsep .. folder_name .. config.pathsep .. path)

            if type(handle) ~= "userdata" then
                error(lib.lazy_string_concat("Failed to scan directory '", workspace, path, "': ", handle))
            end

            return handle
        end

        ---Gets the title from the metadata of a file, must be called in a vim.schedule
        ---@param file PathlibPath | string
        ---@return string?
        local get_title = function(file)
            local path = workspace_path / folder_name / file
            local meta
            if vim.fn.bufexists(tostring(path)) == 1 then
                local buf = vim.fn.bufnr(tostring(path))
                meta = ts.get_document_metadata(buf)
            else
                meta = ts.get_document_metadata(path)
            end
            if meta then
                return meta.title
            end
        end

        vim.loop.fs_scandir(workspace_path .. config.pathsep .. folder_name .. config.pathsep, function(err, handle)
            assert(not err, lib.lazy_string_concat("Unable to generate TOC for directory '", folder_name, "' - ", err))

            while true do
                -- Name corresponds to either a YYYY-mm-dd.norg file, or just the year ("nested" strategy)
                local name, type = vim.loop.fs_scandir_next(handle) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>

                if not name then
                    break
                end

                -- Handle nested entries
                if type == "directory" then
                    local years_handle = get_fs_handle(name)
                    while true do
                        -- mname is the month
                        local mname, mtype = vim.loop.fs_scandir_next(years_handle)

                        if not mname then
                            break
                        end

                        if mtype == "directory" then
                            local months_handle = get_fs_handle(name .. config.pathsep .. mname)
                            while true do
                                -- dname is the day
                                local dname, dtype = vim.loop.fs_scandir_next(months_handle)

                                if not dname then
                                    break
                                end

                                -- If it's a .norg file, also ensure it is a day entry
                                if dtype == "file" and string.match(dname, "%d%d%.norg") then
                                    -- Split the file name
                                    local file = vim.split(dname, ".", { plain = true })

                                    vim.schedule(function()
                                        -- Get the title from the metadata, else, it just defaults to the name of the file
                                        local title = get_title(
                                            name .. config.pathsep .. mname .. config.pathsep .. dname
                                        ) or file[1]

                                        -- Insert a new entry
                                        table.insert(toc_entries, {
                                            tonumber(name),
                                            tonumber(mname),
                                            tonumber(file[1]),
                                            "{:$"
                                                .. workspace_name_for_links
                                                .. config.pathsep
                                                .. module.config.public.journal_folder
                                                .. config.pathsep
                                                .. name
                                                .. config.pathsep
                                                .. mname
                                                .. config.pathsep
                                                .. file[1]
                                                .. ":}",
                                            title,
                                        })
                                    end)
                                end
                            end
                        end
                    end
                end

                -- Handles flat entries
                -- If it is a .norg file, but it's not any user generated file.
                -- The match is here to avoid handling files made by the user, like a template file, or
                -- the toc file
                if type == "file" and string.match(name, "%d+-%d+-%d+%.norg") then
                    -- Split yyyy-mm-dd to a table
                    local file = vim.split(name, ".", { plain = true })
                    local parts = vim.split(file[1], "-")

                    -- Convert the parts into numbers
                    for k, v in pairs(parts) do
                        parts[k] = tonumber(v) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
                    end

                    vim.schedule(function()
                        -- Get the title from the metadata, else, it just defaults to the name of the file
                        local title = get_title(name) or parts[3]

                        -- And insert a new entry that corresponds to the file
                        table.insert(toc_entries, {
                            parts[1],
                            parts[2],
                            parts[3],
                            "{:$"
                                .. workspace_name_for_links
                                .. config.pathsep
                                .. module.config.public.journal_folder
                                .. config.pathsep
                                .. file[1]
                                .. ":}",
                            title,
                        })
                    end)
                end
            end

            vim.schedule(function()
                -- Gets a default format for the entries
                local format = module.config.public.toc_format
                    or function(entries)
                        local months_text = {
                            "January",
                            "February",
                            "March",
                            "April",
                            "May",
                            "June",
                            "July",
                            "August",
                            "September",
                            "October",
                            "November",
                            "December",
                        }
                        -- Convert the entries into a certain format to be written
                        local output = {}
                        local current_year
                        local current_month
                        for _, entry in ipairs(entries) do
                            -- Don't print the year and month if they haven't changed
                            if not current_year or current_year < entry[1] then
                                current_year = entry[1]
                                current_month = nil
                                table.insert(output, "* " .. current_year)
                            end
                            if not current_month or current_month < entry[2] then
                                current_month = entry[2]
                                table.insert(output, "** " .. months_text[current_month])
                            end

                            -- Prints the file link
                            table.insert(output, "   " .. entry[4] .. string.format("[%s]", entry[5]))
                        end

                        return output
                    end

                module.required["core.dirman"].create_file(
                    folder_name .. config.pathsep .. index,
                    workspace or module.required["core.dirman"].get_current_workspace()[1]
                )

                -- The current buffer now must be the toc file, so we set our toc entries there
                vim.api.nvim_buf_set_lines(0, 0, -1, false, format(toc_entries))
                vim.cmd("w")
            end)
        end)
    end,

    --- Parses the `range` argument for `:Neorg journal agenda` into an inclusive
    --- `[from, to]` epoch-second pair, relative to `anchor_time` (defaults to now).
    --- Accepted values: `"day"`, `"week"` (Monday-Sunday), `"month"` (calendar month),
    --- or a string of digits `"<N>"` meaning "the N days up to and including `anchor_time`".
    --- Falls back to `module.config.public.agenda_default_range` when `range_arg` is nil.
    ---@param range_arg string?
    ---@param anchor_time number?
    ---@return number? from, number? to
    parse_agenda_range = function(range_arg, anchor_time)
        local range = range_arg or module.config.public.agenda_default_range
        local anchor = os.date("*t", anchor_time or os.time())
        local anchor_start =
            os.time({ year = anchor.year, month = anchor.month, day = anchor.day, hour = 0, min = 0, sec = 0 })
        local day_secs = 24 * 60 * 60

        if range == "day" then
            return anchor_start, anchor_start + day_secs - 1
        elseif range == "week" then
            local offset_from_monday = (anchor.wday + 5) % 7 -- os.date wday: 1=Sun..7=Sat
            local monday = anchor_start - offset_from_monday * day_secs
            return monday, monday + 7 * day_secs - 1
        elseif range == "month" then
            local first = os.time({ year = anchor.year, month = anchor.month, day = 1, hour = 0 })
            local last = os.time({ year = anchor.year, month = anchor.month + 1, day = 1, hour = 0 }) - 1
            return first, last
        elseif range:match("^%d+$") then
            local n = tonumber(range)
            return anchor_start - (n - 1) * day_secs, anchor_start + day_secs - 1
        end

        log.error("[journal.agenda] Invalid range '" .. range .. "'. Expected 'day', 'week', 'month', or an integer.")
        return nil
    end,

    --- Collects every journal entry whose date falls within `[from_time, to_time]`
    --- (both epoch seconds, inclusive), sorted chronologically.
    ---@param from_time number
    ---@param to_time number
    ---@return { year: number, month: number, day: number, relpath: string, abs_path: string, time: number }[]
    get_entries_in_range = function(from_time, to_time)
        local workspace = module.config.public.workspace or module.required["core.dirman"].get_current_workspace()[1]
        local workspace_path = module.required["core.dirman"].get_workspace(workspace)
        local folder_name = module.config.public.journal_folder

        local entries = {}
        walk_journal_entries(workspace_path, folder_name, function(year, month, day, relpath)
            local ok, entry_time = pcall(os.time, { year = year, month = month, day = day, hour = 12 })
            if ok and entry_time >= from_time and entry_time <= to_time then
                table.insert(entries, {
                    year = year,
                    month = month,
                    day = day,
                    relpath = relpath,
                    abs_path = tostring(workspace_path / folder_name / relpath),
                    time = entry_time,
                })
            end
        end)

        table.sort(entries, function(a, b)
            return a.time < b.time
        end)
        return entries
    end,

    --- Reads each entry's body (title + full content, metadata block stripped) and assembles
    --- the flat line list (plus a line->source lookup table) that the agenda buffer renders.
    ---@param entries table[]
    ---@return string[] lines, table<integer, { path: string, row: integer, col: integer }> line_map
    build_agenda_lines = function(entries)
        local lines, line_map = {}, {}
        local paths = vim.tbl_map(function(e)
            return e.abs_path
        end, entries)

        local i = 0
        utils.read_files(paths, function(bufnr, _filename)
            i = i + 1
            local entry = entries[i]
            local meta = ts.get_document_metadata(bufnr)
            local title = meta and meta.title ~= vim.NIL and meta.title or nil
            local date = string.format("%04d-%02d-%02d", entry.year, entry.month, entry.day)

            local heading_fmt = module.config.public.agenda_heading_format
            local heading = heading_fmt and heading_fmt({ entry.year, entry.month, entry.day, title })
                or "* " .. (title and (date .. " - " .. title) or date)

            table.insert(lines, heading)
            line_map[#lines] = { path = entry.abs_path, row = 0, col = 0 }
            table.insert(lines, "")

            local body_lines, body_start_row = get_body_lines(bufnr)
            for j, body_line in ipairs(body_lines) do
                table.insert(lines, body_line)
                line_map[#lines] = { path = entry.abs_path, row = body_start_row + j - 1, col = 0 }
            end
            table.insert(lines, "")
        end)

        return lines, line_map
    end,

    --- Opens the agenda view: a read-only aggregation of every journal entry's full content
    --- within `range_arg` (see `parse_agenda_range`), in chronological order, anchored on
    --- today. The rendered buffer supports `f`/`b` to page forward/backward by one span and
    --- `.` to jump back to today (mirroring Emacs org-agenda). Pass `mode_arg == "qflist"`
    --- to send a one-line-per-entry summary to the quickfix list instead (no paging there).
    ---@param range_arg string?
    ---@param mode_arg string?
    open_agenda = function(range_arg, mode_arg)
        local range_kind = range_arg or module.config.public.agenda_default_range

        if mode_arg == "qflist" then
            local from, to = module.public.parse_agenda_range(range_kind)
            if not from then
                return
            end

            local entries = module.public.get_entries_in_range(from, to)
            if vim.tbl_isempty(entries) then
                log.warn("[journal.agenda] No journal entries found in the selected range.")
                return
            end

            agenda_qflist(entries)
            return
        end

        render_agenda_buffer(range_kind, os.time())
    end,
}

module.on_event = function(event)
    if event.split_type[1] == "core.neorgcmd" then
        if event.split_type[2] == "journal.tomorrow" then
            module.public.diary_tomorrow()
        elseif event.split_type[2] == "journal.yesterday" then
            module.public.diary_yesterday()
        elseif event.split_type[2] == "journal.custom" then
            if not event.content[1] then
                local calendar = modules.get_module("core.ui.calendar")

                if not calendar then
                    log.error("[ERROR]: `core.ui.calendar` is not loaded! Said module is required for this operation.")
                    return
                end

                calendar.select_date({
                    callback = vim.schedule_wrap(function(osdate)
                        module.public.open_diary(
                            nil,
                            string.format("%04d", osdate.year)
                                .. "-"
                                .. string.format("%02d", osdate.month)
                                .. "-"
                                .. string.format("%02d", osdate.day)
                        )
                    end),
                })
            else
                module.public.open_diary(nil, event.content[1])
            end
        elseif event.split_type[2] == "journal.today" then
            module.public.diary_today()
        elseif event.split_type[2] == "journal.template" then
            module.public.create_template()
        elseif event.split_type[2] == "journal.toc.open" then
            module.public.open_toc()
        elseif event.split_type[2] == "journal.toc.update" then
            module.public.create_toc()
        elseif event.split_type[2] == "journal.agenda" then
            module.public.open_agenda(event.content[1], event.content[2])
        end
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["journal.yesterday"] = true,
        ["journal.tomorrow"] = true,
        ["journal.today"] = true,
        ["journal.custom"] = true,
        ["journal.template"] = true,
        ["journal.toc.update"] = true,
        ["journal.toc.open"] = true,
        ["journal.agenda"] = true,
    },
}

return module
