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
            calendar_text = nil,
            help_and_custom_input = nil,
            current_view = nil,
            month_headings = {},
            weekday_displays = {},
        },
        logical = {
            year = nil,
            months = {
                -- [3] = { [31] = <id> }
            },
        },
    },

    namespaces = {
        logical = vim.api.nvim_create_namespace("neorg/calendar/logical"),
        decorational = vim.api.nvim_create_namespace("neorg/calendar/decorational"),
    },

    set_extmark = function(ui_info, namespace, row, col, length, virt_text, alignment, extra)
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

        local default_extra = {
            virt_text = virt_text,
            virt_text_pos = "overlay",
        }

        if length then
            default_extra.end_col = col + length
        end

        return vim.api.nvim_buf_set_extmark(
            ui_info.buffer,
            namespace,
            row,
            col,
            vim.tbl_deep_extend("force", default_extra, extra or {})
        )
    end,

    set_decorational_extmark = function(ui_info, row, col, length, virt_text, alignment, extra)
        return module.private.set_extmark(
            ui_info,
            module.private.namespaces.decorational,
            row, col, length, virt_text, alignment, extra
        )
    end,

    set_logical_extmark = function(ui_info, row, col, virt_text, alignment, extra)
        return module.private.set_extmark(
            ui_info,
            module.private.namespaces.logical,
            row, col, nil, virt_text, alignment, extra
        )
    end,

    -- TODO: implemant distance like in render_weekday_banner
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

        module.private.extmarks.decorational.month_headings[weekday_banner_extmark_id] = module.private.set_decorational_extmark(
            ui_info,
            4,
            weekday_banner_id[2]
                + math.ceil((weekday_banner_id[3].end_col - weekday_banner_id[2]) / 2)
                - math.floor(month_name:len() / 2),
            month_name:len(),
            { { month_name, "@text.underline" } },
            nil,
            {
                id = module.private.extmarks.decorational.month_headings[weekday_banner_extmark_id],
            }
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

        local absolute_offset = offset + (offset < 0 and (-offset * 100) or 0)

        local weekday_banner_id = module.private.set_decorational_extmark(
            ui_info,
            6,
            (weekdays_string_length * offset)
                + (offset < 0 and -distance or (offset > 0 and distance or 0)) * math.abs(offset),
            weekdays_string_length,
            weekdays,
            "center",
            {
                id = module.private.extmarks.decorational.weekday_displays[absolute_offset],
            }
        )

        module.private.extmarks.decorational.weekday_displays[absolute_offset] = weekday_banner_id

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

        local days_in_current_month = module.private.get_month_length(month, year)

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

        module.private.extmarks.logical.months[month] = module.private.extmarks.logical.months[month] or {}

        for day_of_month, day_of_week in ipairs(days_of_month) do
            local is_current_day = current_date.year == target_date.year
                and current_date.month == target_date.month
                and day_of_month == day

            local start_row = beginning_of_weekday_extmark[1] + render_row
            local start_col = beginning_of_weekday_extmark[2] + (4 * render_column)

            if is_current_day then
                -- TODO: Make this configurable. The user might want the cursor to start
                -- on a specific date in a specific month.
                -- Just look up the extmark and place the cursor there.
                vim.api.nvim_win_set_cursor(ui_info.window, { start_row + 1, start_col })
            end

            module.private.extmarks.logical.months[month][day_of_month] =
                vim.api.nvim_buf_set_extmark(ui_info.buffer, module.private.namespaces.logical, start_row, start_col, {
                    virt_text = {
                        {
                            (day_of_month < 10 and "0" or "") .. tostring(day_of_month),
                            (is_current_day and "@text.todo" or nil),
                        },
                    },
                    virt_text_pos = "overlay",
                    id = module.private.extmarks.logical.months[month][day_of_month],
                })

            if day_of_week == 7 then
                render_column = 0
                render_row = render_row + 1
            else
                render_column = render_column + 1
            end
        end
    end,

    render_month_array = function (ui_info, date, options)
        -- Render the first weekday banner in the middle
        local weekday_banner = module.private.render_weekday_banner(ui_info, 0, options.distance)
        module.private.render_month_banner(ui_info, date, weekday_banner)
        module.private.render_month(ui_info, date, date, weekday_banner)

        local months_to_render = module.private.rendered_months_in_width(ui_info.width, options.distance)
        months_to_render = math.floor(months_to_render / 2)

        for i=1,months_to_render do
            weekday_banner = module.private.render_weekday_banner(ui_info, i, options.distance)

            local positive_target_date = reformat_time({
                year = date.year,
                month = date.month + i,
                day = 1,
            })

            module.private.render_month_banner(ui_info, positive_target_date, weekday_banner)
            module.private.render_month(ui_info, positive_target_date, date, weekday_banner)

            weekday_banner = module.private.render_weekday_banner(ui_info, i * -1)

            local negative_target_date = reformat_time({
                year = date.year,
                month = date.month - i,
                day = 1,
            })

            module.private.render_month_banner(ui_info, negative_target_date, weekday_banner)
            module.private.render_month(ui_info, negative_target_date, date, weekday_banner)
        end
    end,

    render_year_tag = function(ui_info, year)
        -- Display the current year (i.e. `< 2022 >`)
        local extra = nil

        if module.private.extmarks.logical.year ~= nil then
            extra = {
                id = module.private.extmarks.logical.year,
            }
        end

        local extmark = module.private.set_logical_extmark(
            ui_info,
            2,
            0,
            { { "< ", "Whitespace" }, { tostring(year), "@number" }, { " >", "Whitespace" } },
            "center",
            extra
        )

        if (module.private.extmarks.logical.year == nil) then
            module.private.extmarks.logical.year = extmark
        end
    end,

    render_decorative_text = function (ui_info, view)
        --> Decorational section
        -- CALENDAR text:
        module.private.extmarks.decorational = vim.tbl_deep_extend("force", module.private.extmarks.decorational, {
            calendar_text = module.private.set_decorational_extmark(ui_info, 0, 0, 0, {
                { "CALENDAR", "@text.strong" },
            }, "center"),

            -- Help text at the bottom left of the screen
            help_and_custom_input = module.private.set_decorational_extmark(ui_info, ui_info.height - 1, 0, 0, {
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
                ui_info.height - 1,
                0,
                0,
                { { "[", "Whitespace" }, { view, "@label" }, { "]", "Whitespace" } },
                "right"
            ),
        })
    end,

    select_current_day = function(ui_info, date)
        local extmark_id = module.private.extmarks.logical.months[date.month][date.day]

        local position = vim.api.nvim_buf_get_extmark_by_id(
            ui_info.buffer,
            module.private.namespaces.logical,
            extmark_id,
            {}
        )

        vim.api.nvim_win_set_cursor(ui_info.window, { position[1] + 1, position[2] })
    end,

    render_view = function (ui_info, view, date, previous_date, options)
        local is_first_render = (previous_date == nil)

        if is_first_render then
            module.private.fill_buffer(ui_info)
            module.private.render_decorative_text(ui_info, view)
            module.private.render_year_tag(ui_info, date.year)
            module.private.render_month_array(ui_info, date, options)
            module.private.select_current_day(ui_info, date)
            return
        end

        local year_changed = (date.year ~= previous_date.year)
        local month_changed = (date.month ~= previous_date.month)
        local day_changed = (date.day ~= previous_date.day)

        if year_changed then
            module.private.render_year_tag(ui_info, date.year)
        end

        if year_changed or month_changed then
            module.private.render_month_array(ui_info, date, options)
            module.private.clear_extmarks(ui_info, date, options)
        end

        if year_changed or month_changed or day_changed then
            module.private.select_current_day(ui_info, date)
        end
    end,

    clear_extmarks = function(ui_info, current_date, options)
        local cur_month = current_date.month

        local rendered_months_offset = math.floor(module.private.rendered_months_in_width(ui_info.width, options.distance) / 2)

        -- Mimics ternary operator to be concise
        local month_min = cur_month - rendered_months_offset
        month_min = month_min <= 0 and (12 + month_min) or month_min

        local month_max = cur_month + rendered_months_offset
        month_max = month_max > 12 and (month_max - 12) or month_max

        local clear_extmarks_for_month = function (month)
            for _, extmark_id in ipairs(module.private.extmarks.logical.months[month]) do
                vim.api.nvim_buf_del_extmark(
                    ui_info.buffer,
                    module.private.namespaces.logical,
                    extmark_id
                )
            end

            module.private.extmarks.logical.months[month] = nil
        end

        for month, _ in pairs(module.private.extmarks.logical.months) do
            if month_min < month_max then
                if month_min > month or month > month_max then
                    clear_extmarks_for_month(month)
                end
            elseif month_min > month_max then
                if month_max < month and month < month_min then
                    clear_extmarks_for_month(month)
                end
            elseif month_min == month_max then
                if month ~= cur_month then
                    clear_extmarks_for_month(month)
                end
            end
        end
    end,

    fill_buffer = function(ui_info)
        -- There are many steps to render a calendar.
        -- The first step is to fill the entire buffer with spaces. This lets
        -- us place extmarks at any position in the document. Won't be used for
        -- the meaty stuff, but will come in handy for rendering decorational
        -- elements.
        local fill = {}
        local filler = string.rep(" ", ui_info.width)

        for i = 1, ui_info.height do
            fill[i] = filler
        end

        vim.api.nvim_buf_set_lines(ui_info.buffer, 0, -1, true, fill)
    end,

    get_month_length = function(month, year)
        return ({
            31,
            (module.private.is_leap_year(year)) and 29 or 28,
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
        })[month]
    end,

    is_leap_year = function(year)
        if year % 4 ~= 0 then
            return false
        end

        -- Years disible by 100 are leap years only if also divisible by 400
        if year % 100 == 0 and year % 400 ~= 0 then
            return false
        end

        return true
    end,

    rendered_months_in_width = function(width, distance)
        local rendered_month_width = 26
        local months = math.floor(width / (rendered_month_width + distance))
        if months % 2 == 0 then
            return months - 1
        end
        return months
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

        local current_date = os.date("*t")

        module.private.render_view(ui_info, view, current_date, nil, options)

        do
            -- TODO: Make cursor wrapping behaviour configurable
            vim.keymap.set("n", "l",
                function()
                    local new_date = reformat_time({
                        year = current_date.year,
                        month = current_date.month,
                        day = current_date.day + 1
                    })
                    module.private.render_view(ui_info, view, new_date, current_date, options)
                    current_date = new_date
                end,
                { buffer = buffer }
            )

            vim.keymap.set("n", "h",
                function()
                    local new_date = reformat_time({
                        year = current_date.year,
                        month = current_date.month,
                        day = current_date.day - 1
                    })
                    module.private.render_view(ui_info, view, new_date, current_date, options)
                    current_date = new_date
                end,
                { buffer = buffer }
            )

            vim.keymap.set("n", "j",
                function()
                    local new_date = reformat_time({
                        year = current_date.year,
                        month = current_date.month,
                        day = current_date.day + 7
                    })
                    module.private.render_view(ui_info, view, new_date, current_date, options)
                    current_date = new_date
                end,
                { buffer = buffer }
            )

            vim.keymap.set("n", "k",
                function()
                    local new_date = reformat_time({
                        year = current_date.year,
                        month = current_date.month,
                        day = current_date.day - 7
                    })
                    module.private.render_view(ui_info, view, new_date, current_date, options)
                    current_date = new_date
                end,
                { buffer = buffer }
            )
        end
    end,

    select_date = function(options)
        local buffer, window =
            module.public.create_split("calendar", {}, options.height or math.floor(vim.opt.lines:get() * 0.3))

        -- This would fix an issue with the calendar going over the window width
        -- However, it would probably be better to implement this inside the "create_split" function
        -- vim.api.nvim_win_set_option(window, 'signcolumn', 'no')

        return module.public.create_calendar(buffer, window, options)
    end,
}

return module
