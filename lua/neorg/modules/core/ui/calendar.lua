local module = neorg.modules.extend("core.ui.calendar", "core.ui")

module.public = {
    create_calendar = function(buffer, window, options)
        local width = vim.api.nvim_win_get_width(window)
        local height = vim.api.nvim_win_get_height(window)

        local half_width = math.floor(width / 2)
        local half_height = math.floor(height / 2)

        local view = options.view or "MONTHLY"

        do
            -- TODO: Remove, this is for debugging
            vim.api.nvim_buf_set_option(buffer, "textwidth", vim.api.nvim_win_get_width(window))

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

            -- Next, we need two namespaces: one for rendering decorational
            -- extmarks, and one for logical operations.
            local decorational_namespace = vim.api.nvim_create_namespace("neorg/calendar/decorational")

            vim.api.nvim_buf_clear_namespace(buffer, decorational_namespace, 0, -1)

            --> Decorational section
            -- CALENDAR text:
            vim.api.nvim_buf_set_extmark(buffer, decorational_namespace, 0, half_width - math.floor(string.len("CALENDAR") / 2), {
                virt_text = { { "CALENDAR", "TSStrong" } },
                virt_text_pos = "overlay"
            })

            -- Help text at the bottom right of the screen
            vim.api.nvim_buf_set_extmark(buffer, decorational_namespace, height - 1, 0, {
                virt_text = { { "?", "TSCharacter" }, { " - " }, { "help", "TSStrong" }, { "    " }, { "i", "TSCharacter" }, { " - " }, { "custom input", "TSStrong" } },
                virt_text_pos = "overlay"
            })

            vim.api.nvim_buf_set_extmark(buffer, decorational_namespace, height - 1, width - string.len("[" .. view .. "]"), {
                virt_text = { { "[", "Whitespace" }, { view, "TSLabel" }, { "]", "Whitespace" } },
                virt_text_pos = "overlay"
            })
        end

        local logical_namespace = vim.api.nvim_create_namespace("neorg/calendar/logical")

        vim.api.nvim_buf_clear_namespace(buffer, logical_namespace, 0, -1)

        local year, month, day = os.date("%Y-%m-%d"):match("(%d+)%-(%d+)%-(%d+)")

        -- Display the current year
        local year_extmark = vim.api.nvim_buf_set_extmark(buffer, logical_namespace, 2, half_width - math.floor(string.len("< " .. tostring(year) .. " >") / 2), {
            virt_text = { { "< ", "Whitespace" }, { tostring(year), "TSNumber" }, { " >", "Whitespace" } },
            virt_text_pos = "overlay",
        })

        --> Month rendering routine
        -- We render the first month at the very center of the screen. Each month takes up a static 26 characters.

        -- Render the top text of the month (June, August etc.)
        -- The top text displays the abbreviated month
        -- TODO: Extract this logic out into a function because different views
        -- will supply different abbreviations to render.
        local abbreviated_month_name = os.date("%b", os.time({
            year = year,
            month = month,
            day = day,
        }))

        vim.api.nvim_buf_set_extmark(buffer, logical_namespace, 4, half_width - math.floor(string.len(abbreviated_month_name) / 2), {
            virt_text = { { abbreviated_month_name, "TSUnderline" } },
            virt_text_pos = "overlay",
        })

        -- Render the days of the week
        -- To effectively do this, we grab all the weekdays from a constant time.
        -- This makes the weekdays retrieved locale dependent (which is what we want).
        local weekdays = {}

        for i = 1, 7 do
            table.insert(weekdays, { os.date("%a", os.time({
                year = 2000,
                month = 5,
                day = i,
            })):sub(1, 1), "TSTitle" })
            table.insert(weekdays, { " " })
        end

        vim.api.nvim_buf_set_extmark(buffer, logical_namespace, 5, half_width - math.floor(#weekdays / 2) + 1, {
            virt_text = weekdays,
            virt_text_pos = "overlay",
        })
    end,

    select_date = function(options)
        local buffer, window = module.public.create_split("calendar", {}, math.floor(vim.opt.lines:get() * 0.4))

        return module.public.create_calendar(buffer, window, options)
    end,
}

return module
