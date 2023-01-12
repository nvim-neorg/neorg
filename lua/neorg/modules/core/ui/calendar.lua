-- NOTICE: Consider this whole module a demo for now
-- A lot of stuff is hardcoded in order to prove that it can work

local module = neorg.modules.extend("core.ui.calendar", "core.ui")

local function reformat_time(date)
    return os.date("*t", os.time(date))
end

module.private = {
    -- TODO(vhyrro): Localize this to the functions themselves
    -- and return extmarks data within the functions.
    -- Right now only a single calendar can be open at once
    -- which is a little cringe.
    extmarks = {
        decorational = {
            calendar_text = -1,
            help_and_custom_input = -1,
            current_view = -1,
            month_headings = {},
            weekday_displays = {},
        },
        logical = {
            year = -1,
            months = {
                -- [3] = { [31] = <id> }
            },
        },
    },

    namespaces = {
        logical = vim.api.nvim_create_namespace("neorg/calendar/logical"),
        decorational = vim.api.nvim_create_namespace("neorg/calendar/decorational"),
    },

    set_decorational_extmark = function(ui_info, row, col, length, virt_text, alignment)
        if alignment then
            local text_length = 0

            for _, tuple in ipairs(virt_text) do
                text_length = text_length + tuple[1]:len()
            end

            if alignment == "center" then
                col = col + (ui_info.half_width - math.floor(text_length / 2))
            elseif alignment == "right" then
                col = col + (ui_info.width - text_length)
            end
        end

        return vim.api.nvim_buf_set_extmark(ui_info.buffer, module.private.namespaces.decorational, row, col, {
            virt_text = virt_text,
            virt_text_pos = "overlay",
            end_col = col + length,
        })
    end,

    set_logical_extmark = function(ui_info, row, col, virt_text, alignment, extra)
        if alignment then
            local text_length = 0

            for _, tuple in ipairs(virt_text) do
                text_length = text_length + tuple[1]:len()
            end

            if alignment == "center" then
                col = col + (ui_info.half_width - math.floor(text_length / 2))
            elseif alignment == "right" then
                col = col + (ui_info.width - text_length)
            end
        end

        return vim.api.nvim_buf_set_extmark(
            ui_info.buffer,
            module.private.namespaces.logical,
            row,
            col,
            vim.tbl_deep_extend("force", {
                virt_text = virt_text,
                virt_text_pos = "overlay",
            }, extra or {})
        )
    end,

    render_month_banner = function(ui_info, date, weekday_banner_extmark_id)
        local month_name = os.date(
            "%B",
            os.time({
                year = date.year,
                month = date.month,
                day = date.day,
            })
        )

        local weekday_banner_id = vim.api.nvim_buf_get_extmark_by_id(
            ui_info.buffer,
            module.private.namespaces.decorational,
            weekday_banner_extmark_id,
            {
                details = true,
            }
        )

        module.private.extmarks.decorational.month_headings[month_name] = module.private.set_decorational_extmark(
            ui_info,
            4,
            weekday_banner_id[2]
                + math.ceil((weekday_banner_id[3].end_col - weekday_banner_id[2]) / 2)
                - math.floor(month_name:len() / 2),
            month_name:len(),
            { { month_name, "@text.underline" } }
        )
    end,

    render_weekday_banner = function(ui_info, offset, distance)
        offset = offset or 0
        distance = distance or 4

        -- Render the days of the week
        -- To effectively do this, we grab all the weekdays from a constant time.
        -- This makes the weekdays retrieved locale dependent (which is what we want).
        local weekdays = {}
        local weekdays_string_length = 0

        for i = 1, 7 do
            table.insert(weekdays, {
                os.date(
                    "%a",
                    os.time({
                        year = 2000,
                        month = 5,
                        day = i,
                    })
                ):sub(1, 2),
                "@text.title",
            })

            if i ~= 7 then
                table.insert(weekdays, { "  " })
            end

            weekdays_string_length = weekdays_string_length + (i ~= 7 and 4 or 2)
        end

        local weekday_banner_id = module.private.set_decorational_extmark(
            ui_info,
            6,
            (weekdays_string_length * offset)
                + (offset < 0 and -distance or (offset > 0 and distance or 0)) * math.abs(offset),
            weekdays_string_length,
            weekdays,
            "center"
        )

        table.insert(module.private.extmarks.decorational.weekday_displays, weekday_banner_id)

        return weekday_banner_id
    end,

    render_month = function(ui_info, target_date, current_date, weekday_banner_extmark_id)
        --> Month rendering routine
        -- We render the first month at the very center of the screen. Each
        -- month takes up a static amount of characters.

        -- Render the top text of the month (June, August etc.)
        -- Render the numbers for weekdays
        local days_of_month = {
            -- [day of month] = <day of week>,
        }

        local day, month, year = target_date.day, target_date.month, target_date.year

        local days_in_current_month = ({
            31,
            (tonumber(year) % 4 == 0) and 29 or 28,
            31,
            30,
            31,
            30,
            31,
            31,
            30,
            31,
            30,
            31,
        })[tonumber(month)]

        for i = 1, days_in_current_month do
            days_of_month[i] = tonumber(os.date(
                "%u",
                os.time({
                    year = year,
                    month = month,
                    day = i,
                })
            ))
        end

        local beginning_of_weekday_extmark = vim.api.nvim_buf_get_extmark_by_id(
            ui_info.buffer,
            module.private.namespaces.decorational,
            weekday_banner_extmark_id,
            {}
        )

        local render_column = days_of_month[1] - 1
        local render_row = 1

        for day_of_month, day_of_week in ipairs(days_of_month) do
            local month_as_number = tonumber(month)
            module.private.extmarks.logical.months[month_as_number] = module.private.extmarks.logical.months[month_as_number]
                or {}

            local is_current_day = current_date.year == target_date.year
                and current_date.month == target_date.month
                and tostring(day_of_month) == day

            local start_row = beginning_of_weekday_extmark[1] + render_row
            local start_col = beginning_of_weekday_extmark[2] + (4 * render_column)

            if is_current_day then
                -- TODO: Make this configurable. The user might want the cursor to start
                -- on a specific date in a specific month.
                -- Just look up the extmark and place the cursor there.
                vim.api.nvim_win_set_cursor(ui_info.window, { start_row + 1, start_col })
            end

            module.private.extmarks.logical.months[month_as_number][day_of_month] =
                vim.api.nvim_buf_set_extmark(ui_info.buffer, module.private.namespaces.logical, start_row, start_col, {
                    virt_text = {
                        {
                            (day_of_month < 10 and "0" or "") .. tostring(day_of_month),
                            (is_current_day and "@text.todo" or nil),
                        },
                    },
                    virt_text_pos = "overlay",
                })

            if day_of_week == 7 then
                render_column = 0
                render_row = render_row + 1
            else
                render_column = render_column + 1
            end
        end
    end,
}

module.public = {
    create_calendar = function(buffer, window, options)
        options.distance = options.distance or 4

        -- Variables
        local width = vim.api.nvim_win_get_width(window)
        local height = vim.api.nvim_win_get_height(window)

        local half_width = math.floor(width / 2)
        local half_height = math.floor(height / 2)

        local ui_info = {
            window = window,
            buffer = buffer,
            width = width,
            height = height,
            half_width = half_width,
            half_height = half_height,
        }

        local view = options.view or "MONTHLY"

        vim.api.nvim_buf_clear_namespace(buffer, module.private.namespaces.decorational, 0, -1)
        vim.api.nvim_buf_clear_namespace(buffer, module.private.namespaces.logical, 0, -1)

        --------------------------------------------------

        -- There are many steps to render a calendar.
        -- The first step is to fill the entire buffer with spaces. This lets
        -- us place extmarks at any position in the document. Won't be used for
        -- the meaty stuff, but will come in handy for rendering decorational
        -- elements.
        do
            local fill = {}
            local filler = string.rep(" ", width)

            for i = 1, height do
                fill[i] = filler
            end

            vim.api.nvim_buf_set_lines(buffer, 0, -1, true, fill)
        end

        -- This `do .. end` block is a routine that draws (almost) all
        -- decorational content like the "CALENDAR" text, the "help", "custom
        -- input" and "[VIEW]" texts.
        do
            --> Decorational section
            -- CALENDAR text:
            module.private.extmarks.decorational = vim.tbl_deep_extend("force", module.private.extmarks.decorational, {
                calendar_text = module.private.set_decorational_extmark(ui_info, 0, 0, 0, {
                    { "CALENDAR", "@text.strong" },
                }, "center"),

                -- Help text at the bottom left of the screen
                help_and_custom_input = module.private.set_decorational_extmark(ui_info, height - 1, 0, 0, {
                    { "?", "@character" },
                    { " - " },
                    { "help", "@text.strong" },
                    { "    " },
                    { "i", "@character" },
                    { " - " },
                    { "custom input", "@text.strong" },
                }),

                -- The current view (bottom right of the screen)
                current_view = module.private.set_decorational_extmark(
                    ui_info,
                    height - 1,
                    0,
                    0,
                    { { "[", "Whitespace" }, { view, "@label" }, { "]", "Whitespace" } },
                    "right"
                ),
            })
        end

        -- TODO: These are strings, even though they shouldn't be
        -- Refactor to autoconvert these into real numbers.
        -- Maybe just os.date("*t")?
        local year, month, day = os.date("%Y-%m-%d"):match("(%d+)%-(%d+)%-(%d+)")

        -- Display the current year (i.e. `< 2022 >`)
        module.private.extmarks.logical.year = module.private.set_logical_extmark(
            ui_info,
            2,
            0,
            { { "< ", "Whitespace" }, { tostring(year), "@number" }, { " >", "Whitespace" } },
            "center"
        )

        -- TODO: implement monthly/yearly/daily/weekly logic

        -- Render the first weekday banner in the middle
        local current_date = {
            year = year,
            month = month,
            day = day,
        }

        local weekday_banner = module.private.render_weekday_banner(ui_info, 0, options.distance)
        module.private.render_month_banner(ui_info, current_date, weekday_banner)
        module.private.render_month(ui_info, current_date, current_date, weekday_banner)

        do
            local blockid = 1

            while math.floor(width / (26 + options.distance)) > blockid * 2 do
                weekday_banner = module.private.render_weekday_banner(ui_info, blockid, options.distance)

                local positive_target_date = reformat_time({
                    year = year,
                    month = month + blockid,
                    day = day,
                })

                module.private.render_month_banner(ui_info, positive_target_date, weekday_banner)
                module.private.render_month(ui_info, positive_target_date, current_date, weekday_banner)

                weekday_banner = module.private.render_weekday_banner(ui_info, blockid * -1)

                local negative_target_date = reformat_time({
                    year = year,
                    month = month - blockid,
                    day = day,
                })

                module.private.render_month_banner(ui_info, negative_target_date, weekday_banner, options.distance)
                module.private.render_month(ui_info, negative_target_date, current_date, weekday_banner)

                blockid = blockid + 1
            end
        end

        do
            local current_day, current_month, current_year = tonumber(day), tonumber(month), tonumber(year)

            local function update_year(new_year)
                module.private.set_logical_extmark(
                    ui_info,
                    2,
                    0,
                    { { "< ", "Whitespace" }, { tostring(new_year), "@number" }, { " >", "Whitespace" } },
                    "center",
                    {
                        id = module.private.extmarks.logical.year,
                    }
                )
            end

            -- TODO: Make cursor wrapping behaviour configurable
            vim.api.nvim_buf_set_keymap(buffer, "n", "l", "", {
                callback = function()
                    local next_extmark_id = module.private.extmarks.logical.months[current_month]
                            and module.private.extmarks.logical.months[current_month][current_day + 1]
                        or nil

                    if not next_extmark_id then
                        if current_month + 1 == 13 then
                            current_month = 0
                            current_year = current_year + 1
                            update_year(current_year)
                        end

                        local next_month = module.private.extmarks.logical.months[current_month + 1]

                        if not next_month then
                            return
                        end

                        current_day = 1
                        current_month = current_month + 1
                        next_extmark_id = next_month[current_day]
                    else
                        current_day = current_day + 1
                    end

                    local next = vim.api.nvim_buf_get_extmark_by_id(
                        buffer,
                        module.private.namespaces.logical,
                        next_extmark_id,
                        {}
                    )
                    vim.api.nvim_win_set_cursor(window, { next[1] + 1, next[2] })
                end,
            })

            vim.api.nvim_buf_set_keymap(buffer, "n", "h", "", {
                callback = function()
                    local prev_extmark_id = module.private.extmarks.logical.months[current_month][current_day - 1]

                    if not prev_extmark_id then
                        if current_month - 1 == 0 then
                            current_month = 13
                            current_year = current_year - 1
                            update_year(current_year)
                        end

                        local prev_month = module.private.extmarks.logical.months[current_month - 1]

                        if not prev_month then
                            return
                        end

                        current_day = #prev_month
                        current_month = current_month - 1
                        prev_extmark_id = prev_month[current_day]
                    else
                        current_day = current_day - 1
                    end

                    local prev = vim.api.nvim_buf_get_extmark_by_id(
                        buffer,
                        module.private.namespaces.logical,
                        prev_extmark_id,
                        {}
                    )
                    vim.api.nvim_win_set_cursor(window, { prev[1] + 1, prev[2] })
                end,
            })
        end
    end,

    select_date = function(options)
        local buffer, window =
            module.public.create_split("calendar", {}, options.height or math.floor(vim.opt.lines:get() * 0.3))

        return module.public.create_calendar(buffer, window, options)
    end,
}

return module
