local module = neorg.modules.extend("core.ui.calendar", "core.ui")

module.private = {
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
                {
                    dates = {},
                },
            },
        },
    },

    namespaces = {
        logical = vim.api.nvim_create_namespace("neorg/calendar/decorational"),
        decorational = vim.api.nvim_create_namespace("neorg/calendar/logical"),
    },

    set_decorational_extmark = function(ui_info, row, col, virt_text, alignment)
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
        })
    end,

    set_logical_extmark = function(ui_info, row, col, virt_text, alignment)
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

        return vim.api.nvim_buf_set_extmark(ui_info.buffer, module.private.namespaces.logical, row, col, {
            virt_text = virt_text,
            virt_text_pos = "overlay",
        })
    end,

    render_month_banner = function(ui_info, date)
        local month_name = os.date(
            "%B",
            os.time({
                year = date.year,
                month = date.month,
                day = date.day,
            })
        )

        module.private.extmarks.decorational.month_headings[month_name] =
            module.private.set_decorational_extmark(ui_info, 4, 0, { { month_name, "TSUnderline" } }, "center")

        -- Render the days of the week
        -- To effectively do this, we grab all the weekdays from a constant time.
        -- This makes the weekdays retrieved locale dependent (which is what we want).
        local weekdays = {}
        local weekdays_string_length = 0

        for i = 1, 7 do
            table.insert(weekdays, {
                os
                    .date(
                        "%a",
                        os.time({
                            year = 2000,
                            month = 5,
                            day = i,
                        })
                    )
                    :sub(1, 2),
                "TSTitle",
            })
            table.insert(weekdays, { "  " })
            weekdays_string_length = weekdays_string_length + 4
        end

        table.insert(
            module.private.extmarks.decorational.weekday_displays,
            module.private.set_decorational_extmark(ui_info, 6, 0, weekdays, "center")
        )
    end,

    -- render_month = function()
    --     --> Month rendering routine
    --     -- We render the first month at the very center of the screen. Each
    --     -- month takes up a static amount of characters.

    --     -- Render the top text of the month (June, August etc.)
    --     -- Render the numbers for weekdays
    --     local days_of_month = {
    --         -- [day of month] = <day of week>,
    --     }

    --     local days_in_current_month = ({
    --         31,
    --         (tonumber(year) % 4 == 0) and 29 or 28,
    --         31,
    --         30,
    --         31,
    --         30,
    --         31,
    --         31,
    --         30,
    --         31,
    --         30,
    --         31,
    --     })[tonumber(
    --         month
    --     )]

    --     for i = 1, days_in_current_month do
    --         days_of_month[i] = tonumber(os.date(
    --             "%u",
    --             os.time({
    --                 year = year,
    --                 month = month,
    --                 day = i,
    --             })
    --         ))
    --     end

    --     local beginning_of_weekday_extmark = vim.api.nvim_buf_get_extmark_by_id(
    --         ui_info.buffer,
    --         module.private.namespaces.decorational,
    --         days_of_week_extmark,
    --         {}
    --     )

    --     local render_column = days_of_month[1] - 1
    --     local render_row = 1

    --     for day_of_month, day_of_week in ipairs(days_of_month) do
    --         vim.api.nvim_buf_set_extmark(
    --             buffer,
    --             module.private.namespaces.logical,
    --             beginning_of_weekday_extmark[1] + render_row,
    --             beginning_of_weekday_extmark[2] + (4 * render_column),
    --             {
    --                 virt_text = {
    --                     {
    --                         (day_of_month < 10 and "0" or "") .. tostring(day_of_month),
    --                         (tostring(day_of_month) == day and "TSTodo" or nil),
    --                     },
    --                 },
    --                 virt_text_pos = "overlay",
    --             }
    --         )

    --         if day_of_week == 7 then
    --             render_column = 0
    --             render_row = render_row + 1
    --         else
    --             render_column = render_column + 1
    --         end
    --     end
    -- end,
}

module.public = {
    create_calendar = function(buffer, window, options)
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
                calendar_text = module.private.set_decorational_extmark(ui_info, 0, 0, {
                    { "CALENDAR", "TSStrong" },
                }, "center"),

                -- Help text at the bottom left of the screen
                help_and_custom_input = module.private.set_decorational_extmark(ui_info, height - 1, 0, {
                    { "?", "TSCharacter" },
                    { " - " },
                    { "help", "TSStrong" },
                    { "    " },
                    { "i", "TSCharacter" },
                    { " - " },
                    { "custom input", "TSStrong" },
                }),

                -- The current view (bottom right of the screen)
                current_view = module.private.set_decorational_extmark(
                    ui_info,
                    height - 1,
                    0,
                    { { "[", "Whitespace" }, { view, "TSLabel" }, { "]", "Whitespace" } },
                    "right"
                ),
            })
        end

        local year, month, day = os.date("%Y-%m-%d"):match("(%d+)%-(%d+)%-(%d+)")

        -- Display the current year (i.e. `< 2022 >`)
        module.private.extmarks.logical.year = module.private.set_logical_extmark(
            ui_info,
            2,
            0,
            { { "< ", "Whitespace" }, { tostring(year), "TSNumber" }, { " >", "Whitespace" } },
            "center"
        )

        module.private.render_month_banner(ui_info, {
            year = year,
            month = month,
            day = day,
        })
    end,

    select_date = function(options)
        local buffer, window =
            module.public.create_split("calendar", {}, options.height or math.floor(vim.opt.lines:get() * 0.3))

        return module.public.create_calendar(buffer, window, options)
    end,
}

return module
