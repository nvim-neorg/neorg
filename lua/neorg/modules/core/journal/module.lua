--[[
    file: Journal
    title: Dear diary...
    description: The journal module allows you to take personal notes with zero friction.
    summary: Easily track a journal within Neorg.
    ---
Journals are "periodic" in Neorg. You can have a daily journal, a weekly journal, a quarterly
journal, etc, (or all of them at once). The `daily` journal is the default, and Neorg ships with
`daily`, `weekly`, `monthly`, and `yearly` journals already defined.

### Commands:

The main commands are: `:Neorg journal previous|current|next <name?>`, where `<name>` is the name of
a periodic journal--either one of the pre-defined journal names mentioned above, or a custom name
added in configuration. Eliding `name` will use the default journal (usually `daily` but this is
configurable)

Additionally, you can specify a custom date with `:Neorg journal custom <name?> <date?>`. The date
can be either:
- a date in `YYYY-mm-dd` format, e.g. `2023-01-01`
- a date in the Norg date format: `<day>?,? <day-of-month> <month> -?<year> <time> <timezone>`, eg:
    - `Sat, 29 Oct 1994 19:43.31 GMT`
    - `We 12th Jan 2022`

If an exact date isn't given, it will go to the previous valid date. For example: `:Neorg journal
custom monthly 2024-01-12` will be the same as `:Neorg journal custom monthly 2024-01-01`; both will
take you to Jan 2024's monthly note. If you leave `date` out Neorg will prompt you to select a date
via the calendar.

Some aliases exist for convenience:
- `Neorg journal today|yesterday|tomorrow`, allow you to access daily journal entries for a given
time relative to today. A file will be opened with the respective date as a `.norg` file. (as such,
you cannot name a periodic journal "today", "yesterday", or "tomorrow"). These commands _always_ use
the `daily` journal.

The `:Neorg journal template <name>` command creates or opens a template file which will be used as
the base whenever a new journal entry is created.

Last but not least, the `:Neorg journal toc open|update <name>` commands open or create/update
a Table of Contents file found in the root of the journal. This file contains links to all other
journal entries, alongside their titles.
--]]

local neorg = require("neorg.core")
local config, lib, log, modules = neorg.config, neorg.lib, neorg.log, neorg.modules
---@type core.tempus
local tempus

local module = modules.create("core.journal")

module.config.public = {
    -- Which workspace to use for the journal files, the default behaviour
    -- is to use the current workspace.
    --
    -- It is recommended to set this to a static workspace, but the most optimal
    -- behaviour may vary from workflow to workflow.
    workspace = nil,

    -- The name for the folder in which the journal files are put.
    journal_folder = "journal",

    -- when a journal command is used without a name, this is the journal that it will default to
    default_journal_name = "daily",

    -- The strategy to use to create directories.
    -- May be "flat" (`2022-03-02.norg`), "nested" (`2022/03/02.norg`),
    -- a lua string with the format given to `os.date()` or a lua function
    -- that returns a lua string with the same format.
    strategy = "nested",

    -- The name of the template file to use (sans the `.norg`) when running `:Neorg journal
    -- template`. The actual file path will be: `base_template_name .. "-" .. journal_name .. ".norg"`
    -- for the default  journal template this looks like: `"template-daily.norg"`
    base_template_name = "template",

    -- Whether to apply the template file to new journal entries.
    use_template = true,

    -- Formatter function used to generate the toc file.
    -- Receives a table that contains tables like { yy, mm, dd, link, title }.
    --
    -- The function must return a table of strings.
    toc_format = nil,

    -- this is where you can define additional periodic journals
    --
    -- an example entry looks like:
    -- ```lua
    -- sprint = {
    --   start_date = os.time({ year = 2024, month = 06, day = 17 }), -- a Monday
    --   period = { day = 14 },
    --   path_format_strategy = "%Y/%m/%d-sprint.norg"
    -- }
    -- ```
    -- - `sprint` is the name of the journal, it's how you refer to the journal in commands.
    -- - `start_date` can be any time, including days in the future
    -- - `period` can contain `days` or (`months` and `years`). You can't mix `days` with
    -- `months`/`years` due to inconsistencies with the length of the later group
    -- - `path_format_strategy` accepts the same values as `strategy`, _and_ it is optional. By
    -- default the normal journal strategy is used with `-journal_name` appended to the end
    --
    -- You can override default journal behaviours with this table. For example, if you want your
    -- daily journal to run a little into the next day so you can use `:Neorg journal today` at 1am
    -- and get the previous day's journal, you can do something like this:
    -- ```lua
    -- daily = {
    --   start_date = os.time({ year = 2024, month = 06, day = 01, hour = 1 })
    --   -- other fields will stay default
    -- }
    -- ```
    journals = {},
}

module.config.private = {
    strategies = {
        flat = "%Y-%m-%d.norg",
        nested = "%Y" .. config.pathsep .. "%m" .. config.pathsep .. "%d.norg",
    },
}

module.setup = function()
    return {
        success = true,
        requires = {
            "core.dirman",
            "core.integrations.treesitter",
            "core.tempus",
        },
    }
end

module.load = function()
    tempus = module.required["core.tempus"]
    if module.config.private.strategies[module.config.public.strategy] then
        module.config.public.strategy = module.config.private.strategies[module.config.public.strategy]
    end

    ---alter a format strategy to include the name of the journal at the end (to avoid name
    ---collisions with the default journal)
    local function alter_strategy(strat, name)
        -- use the default strategy for the default journal
        if name == module.config.public.default_journal_name then
            return strat
        end

        if type(strat) == "string" then
            return strat:gsub("%.norg$", "-" .. name .. ".norg")
        end

        if type(strat) == "function" then
            return function(t)
                local str = strat(t)
                return str:gsub("%.norg$", "-" .. name .. ".norg")
            end
        end

        return strat
    end

    ---@class JournalMonthTimePeriod
    ---@field year number?
    ---@field month number?

    ---@class JournalDayTimePeriod
    ---@field day number?

    ---@alias JournalTimePeriod JournalDayTimePeriod | JournalMonthTimePeriod

    ---@class JournalSpec
    ---@field start_date integer time
    ---@field period JournalTimePeriod
    ---@field path_format_strategy string | function

    ---@type table<any, JournalSpec>
    module.config.private.journals = {
        daily = {
            start_date = os.time({ year = 2024, month = 06, day = 01, hour = 0 }),
            period = { day = 1 },
            path_format_strategy = alter_strategy(module.config.public.strategy, "daily"),
        },
        weekly = {
            -- NOTE: this makes the week start on a Monday
            start_date = os.time({ year = 2024, month = 06, day = 03, hour = 0 }),
            period = { day = 7 },
            path_format_strategy = alter_strategy(module.config.public.strategy, "weekly"),
        },
        monthly = {
            start_date = os.time({ year = 2024, month = 01, day = 01, hour = 0 }),
            period = { month = 1 },
            path_format_strategy = alter_strategy(module.config.public.strategy, "monthly"),
        },
    }

    -- validate journal periods
    for name, journal in pairs(module.config.public.journals) do
        if journal.period then
            if journal.period.day and (journal.period.month or journal.period.year) then
                log.warn(
                    "Journals cannot have a period that mixes days with months or years. Days will be ignored for journal: "
                        .. name
                )
            end
        end
        if not journal.path_format_strategy then
            journal.path_format_strategy = alter_strategy(module.config.public.strategy, name)
        end
    end

    module.config.public.journals =
        vim.tbl_deep_extend("keep", module.config.public.journals, module.config.private.journals)

    modules.await("core.neorgcmd", function(neorgcmd)
        local journal_names = vim.tbl_keys(module.config.public.journals)
        neorgcmd.add_commands_from_table({
            journal = {
                min_args = 1,
                subcommands = {
                    tomorrow = { args = 0, name = "journal.tomorrow" },
                    yesterday = { args = 0, name = "journal.yesterday" },
                    today = { args = 0, name = "journal.today" },
                    previous = {
                        min_args = 0,
                        max_args = 1,
                        name = "journal.previous",
                        complete = { journal_names },
                    },
                    current = {
                        min_args = 0,
                        max_args = 1,
                        name = "journal.current",
                        complete = { journal_names },
                    },
                    next = {
                        min_args = 0,
                        max_args = 1,
                        name = "journal.next",
                        complete = { journal_names },
                    },
                    custom = {
                        min_args = 1,
                        name = "journal.custom",
                        complete = { journal_names },
                    },
                    template = {
                        max_args = 1,
                        name = "journal.template",
                        complete = { journal_names },
                    },
                    toc = {
                        args = 1,
                        name = "journal.toc",
                        subcommands = {
                            open = {
                                max_args = 1,
                                name = "journal.toc.open",
                                complete = { journal_names },
                            },
                            update = {
                                max_args = 1,
                                name = "journal.toc.update",
                                complete = { journal_names },
                            },
                        },
                    },
                },
            },
        })
    end)
end

---@class core.journal
module.public = {
    ---Opens a diary entry at the given time
    ---@param journal_name string journal name
    ---@param date? number #The time to open the journal entry at as returned by `os.time()`
    open_journal = function(journal_name, date)
        local workspace = module.config.public.workspace or module.required["core.dirman"].get_current_workspace()[1]
        local folder_name = module.config.public.journal_folder
        local template_name = module.private.get_template_name(journal_name)

        local journal = module.config.public.journals[journal_name]
        if not journal then
            local valid_names = vim.iter(vim.tbl_keys(module.config.public.journals)):join(", ")
            log.error(
                ("Cannot find journal with name: `%s`\nHere is a list of recognized journal names: %s"):format(
                    journal_name,
                    valid_names
                )
            )
            return
        end

        local path = os.date(
            ---@diagnostic disable-next-line: param-type-mismatch
            (type(journal.path_format_strategy) == "function" and journal.path_format_strategy(os.date("*t", date)))
                or journal.path_format_strategy,
            ---@diagnostic disable-next-line: param-type-mismatch
            date
        )

        local workspace_path = module.required["core.dirman"].get_workspace(workspace)

        local journal_file_exists =
            module.required["core.dirman"].file_exists(workspace_path .. "/" .. folder_name .. config.pathsep .. path)

        module.required["core.dirman"].create_file(folder_name .. config.pathsep .. path, workspace)

        if
            not journal_file_exists
            and module.config.public.use_template
            and module.required["core.dirman"].file_exists(workspace_path .. "/" .. folder_name .. "/" .. template_name)
        then
            vim.cmd("$read " .. workspace_path .. "/" .. folder_name .. "/" .. template_name .. "| w")
        end
    end,
}

module.private = {
    journal_previous = function(args)
        local journal_name = args[1]
        local journal = module.config.public.journals[journal_name]
        local current = module.private.get_period_date(journal_name)
        module.public.open_journal(journal_name, tempus.sub_time(current, journal.period))
    end,

    journal_next = function(args)
        local journal_name = args[1]
        local journal = module.config.public.journals[journal_name]
        local current = module.private.get_period_date(journal_name)
        module.public.open_journal(journal_name, tempus.add_time(current, journal.period))
    end,

    ---Get the date at the start of the period which contains the given time for the given journal.
    ---When time is nil, use the current time
    ---@param journal_name string
    ---@param time number?
    ---@return number os.time or 0 when given an invalid journal
    get_period_date = function(journal_name, time)
        local journal = module.config.public.journals[journal_name]
        if not journal then
            return 0
        end

        local start_date = os.date("*t", journal.start_date)
        local start_as_Date = tempus.to_date(os.date("*t", journal.start_date) --[[@as osdate]])

        time = time or os.time()
        local date = os.date("*t", time)

        if journal.period.month or journal.period.year then -- months/years take priority, and days will be ignored if present
            -- calculate based on months
            local period_months = (journal.period.month or 0) + (journal.period.year or 0) * 12
            local start_months = (start_date.month or 0) + (start_date.year or 0) * 12
            local current_months = (date.month or 0) + (date.year or 0) * 12
            local month_diff = current_months - start_months
            local time_periods_since_start = math.floor(month_diff / period_months)

            -- TODO: is this off by one or okay?
            return tempus.add_time(start_as_Date, {
                month = time_periods_since_start * period_months
            })
        else
            -- calculate based on days, this calculation would work for everything if months were
            -- a consistent length :|
            local diff = os.difftime(os.time(date --[[@as osdateparam]]), journal.start_date)
            local start_plus_period = tempus.add_time(start_as_Date, journal.period)
            local period_as_int = os.difftime(start_plus_period, journal.start_date)

            local time_periods_since_start = math.floor(diff / period_as_int)

            return tempus.add_time(start_as_Date, {
                day = time_periods_since_start * (journal.period.day or 0),
            })
        end
    end,

    ---@param args string[]
    journal_current = function(args)
        local journal_name = args[1]
        local current = module.private.get_period_date(journal_name)
        module.public.open_journal(journal_name, current)
    end,

    --- Opens a journal entry for tomorrow's date
    journal_tomorrow = function()
        module.private.journal_next({ "daily" })
    end,

    --- Opens a journal entry for yesterday's date
    journal_yesterday = function()
        module.private.journal_previous({ "daily" })
    end,

    --- Opens a journal entry for today's date
    journal_today = function()
        module.private.journal_current({ "daily" })
    end,

    get_template_name = function(journal_name)
        return module.config.public.base_template_name
            .. "-"
            .. (journal_name or module.config.public.default_journal_name)
            .. ".norg"
    end,

    --- Creates a template file
    create_template = function(args)
        local workspace = module.config.public.workspace
        local folder_name = module.config.public.journal_folder
        local template_name = module.private.get_template_name(args[1])

        module.required["core.dirman"].create_file(
            folder_name .. config.pathsep .. template_name,
            workspace or module.required["core.dirman"].get_current_workspace()[1]
        )
    end,

    -- TODO: file paths for this are going to be weird I think...
    -- might just want another config option for TOC file paths/locations on each periodic journal
    --- Opens the toc file
    ---@param args string[]
    open_toc = function(args)
        local journal_name = args[1] or module.config.public.default_journal_name
        local workspace = module.config.public.workspace or module.required["core.dirman"].get_current_workspace()[1]
        local index = modules.get_module_config("core.dirman").index
        local folder_name = module.config.public.journal_folder

        -- If the toc exists, open it, if not, create it
        if module.required["core.dirman"].file_exists(folder_name .. config.pathsep .. index) then
            module.required["core.dirman"].open_file(workspace, folder_name .. config.pathsep .. index)
        else
            module.private.create_toc({ journal_name })
        end
    end,

    -- TODO: I'm putting this off b/c it's annoying and a lot of work, and I want to get the basics
    -- first anyway
    --- Creates or updates the toc file for a given journal
    ---@param args string[]
    create_toc = function(args)
        local journal_name = args[1] or module.config.public.default_journal_name
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

        -- Gets the title from the metadata of a file, must be called in a vim.schedule
        local get_title = function(file)
            local buffer = vim.fn.bufadd(workspace_path .. config.pathsep .. folder_name .. config.pathsep .. file)
            local meta = module.required["core.integrations.treesitter"].get_document_metadata(buffer)
            return meta.title
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
}

local function handle_custom(args)
    local journal_name = args[1] or module.config.public.default_journal_name
    if not args[2] then
        local calendar = modules.get_module("core.ui.calendar")

        if not calendar then
            log.error("[ERROR]: `core.ui.calendar` is not loaded but is required for this operation.")
            return
        end

        calendar.select_date({
            callback = vim.schedule_wrap(function(osdate)
                module.public.open_journal(journal_name, module.private.get_period_date(journal_name, os.time(osdate)))
            end),
        })
    else
        local year, month, day = args[2]:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")

        if not year or not month or not day then
            -- try to treat it like a Norg date
            local date = tempus.parse_date(vim.iter(args):skip(1):join(" "))
            if type(date) == "string" then
                log.error("Error trying to parse date: ", date)
                return
            end

            year = date.year
            month = date.month.number
            day = date.day
        end

        if not year or not month or not day then
            log.error("Must specify year month and day, in either YYYY-mm-dd or Neorg date format")
            return
        end
        local time = os.time({
            year = year,
            month = month,
            day = day,
        })

        module.public.open_journal(journal_name, module.private.get_period_date(journal_name, time))
    end
end

local event_handlers = {
    ["core.neorgcmd.events.journal.previous"] = module.private.journal_previous,
    ["core.neorgcmd.events.journal.current"] = module.private.journal_current,
    ["core.neorgcmd.events.journal.next"] = module.private.journal_next,
    ["core.neorgcmd.events.journal.yesterday"] = module.private.journal_yesterday,
    ["core.neorgcmd.events.journal.tomorrow"] = module.private.journal_tomorrow,
    ["core.neorgcmd.events.journal.today"] = module.private.journal_today,
    ["core.neorgcmd.events.journal.custom"] = handle_custom,
    ["core.neorgcmd.events.journal.template"] = module.private.create_template,
    ["core.neorgcmd.events.journal.toc.update"] = module.private.create_toc,
    ["core.neorgcmd.events.journal.toc.open"] = module.private.open_toc,
}

module.on_event = function(event)
    if event_handlers[event.type] then
        return event_handlers[event.type](event.content)
    end
end

module.events.subscribed = {
    ["core.neorgcmd"] = {
        ["journal.yesterday"] = true,
        ["journal.tomorrow"] = true,
        ["journal.today"] = true,
        ["journal.previous"] = true,
        ["journal.current"] = true,
        ["journal.next"] = true,
        ["journal.custom"] = true,
        ["journal.template"] = true,
        ["journal.toc.update"] = true,
        ["journal.toc.open"] = true,
    },
}

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

return module
