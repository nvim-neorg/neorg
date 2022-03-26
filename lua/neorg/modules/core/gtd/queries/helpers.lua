local module = neorg.modules.extend("core.gtd.queries.helpers")

--- @class dateDiff
--- @field weeks number
--- @field days number

---@class core.gtd.queries
module.public = {
    -- Convert a date from text to YYYY-MM-dd format
    -- If the date is a quick capture (like 2w, 10d, 4m), it will convert to a standardized date
    -- Supported formats ($ treated as number):
    --   - $d: days from now (e.g 2d is 2 days from now)
    --   - $w: weeks from now (e.g 2w is 2 weeks from now)
    --   - $m: months from now (e.g 2m is 2 months from now)
    --   - tomorrow: tomorrow's date
    --   - today: today's date
    --   The format for date is YYYY-mm-dd
    -- @param text string #The text to use
    -- @return string
    date_converter = function(text)
        vim.validate({ text = { text, "string" } })
        local values = {
            sun = 1,
            mon = 2,
            tue = 3,
            wed = 4,
            thu = 5,
            fri = 6,
            sat = 7,
        }

        if text == "today" then
            return os.date("%Y-%m-%d")
        elseif text == "tomorrow" then
            -- Return tomorrow's date in YY-MM-DD format
            return os.date("%Y-%m-%d", os.time() + 24 * 60 * 60)
        elseif vim.tbl_contains(vim.tbl_keys(values), text) then
            local date = os.date("*t")
            if values[text] > date.wday then
                date.day = date.day + values[text] - date.wday
            else
                date.day = date.day + 7 - (date.wday - values[text])
            end
            local time = os.time(date)
            return os.date("%Y-%m-%d", time)
        end
        local amount, weekday = text:match("^(%d+)(%a%a%a)$")
        if not vim.tbl_contains(vim.tbl_keys(values), weekday) then
            weekday = nil
        end

        if amount and weekday then
            local date = os.date("*t")
            if values[weekday] > date.wday then
                date.day = date.day + values[weekday] - date.wday + (amount - 1) * 7
            else
                date.day = date.day + amount * 7 - (date.wday - values[weekday])
            end
            local time = os.time(date)
            return os.date("%Y-%m-%d", time)
        end

        local year, month, day = text:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
        if year and month and day then
            return text
        end

        local number, type = text:match("^(%d+)([hdwmy])$")
        if not (number and type) then
            return
        end

        -- Function to calculate a date that'll occur in x months.
        local function get_date_in_x_months(months)
            local date = os.date("*t")
            date.month = date.month + months
            if date.month > 12 then
                date.month = date.month - 12
                date.year = date.year + 1
            end
            return os.time(date)
        end

        -- Function to calculate a date that'll occur in x days.
        local function get_date_in_x_days(days)
            -- Create a table to store the number of days in each month
            local month_days = {
                31,
                28,
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
            }

            local date = os.date("*t")
            date.day = date.day + days

            if date.day > month_days[date.month] then
                date.day = date.day - month_days[date.month]
                date.month = date.month + 1
                if date.month > 12 then
                    date.month = date.month - 12
                    date.year = date.year + 1
                end
            end

            return os.time(date)
        end

        -- Function to calculate a date that'll occur in x years.
        local function get_date_in_x_years(years)
            local date = os.date("*t")
            date.year = date.year + years
            return os.time(date)
        end

        -- Function to calculate a date that'll occur in x hours.
        local function get_date_in_x_hours(hours)
            local date = os.date("*t")
            date.hour = date.hour + hours
            return os.time(date)
        end

        -- Function to calculate a date that'll occur in x weeks
        local function get_date_in_x_weeks(weeks)
            local date = os.date("*t")
            date.day = date.day + 7 * weeks
            return os.time(date)
        end

        return os.date(
            "%Y-%m-%d",
            ({
                h = get_date_in_x_hours, -- TODO(vhyrro): Add internal support for hours
                d = get_date_in_x_days,
                w = get_date_in_x_weeks,
                m = get_date_in_x_months,
                y = get_date_in_x_years,
            })[type](number)
        )
    end,

    --- Parses a date string to table relative to today's date
    --- (e.g { weeks = 2, days = 2 } for in 2 weeks and 2 days)
    --- @param date string #A date formatted with YY-MM-dd format
    --- @return dateDiff
    diff_with_today = function(date)
        vim.validate({
            date = { date, "string" },
        })

        -- Get today's date
        local now = os.date("%Y-%m-%d")
        local y_now, m_now, d_now = now:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
        local now_timestamp = os.time({ year = y_now, month = m_now, day = d_now })

        -- Parse date parameter
        local y, m, d = date:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
        if not (y and m and d) then
            return
        end

        local date_timestamp = os.time({ year = y, month = m, day = d })

        -- Find out how many elapsed seconds between now and the date
        local elapsed_seconds = os.difftime(date_timestamp, now_timestamp)

        local elapsed = module.private.convert_seconds(elapsed_seconds)

        return elapsed
    end,

    --- Checks whether the date starts after today
    --- @param date string
    --- @param strict boolean #if true, do not count today as started
    --- @return boolean
    starting_after_today = function(date, strict)
        local diff = module.public.diff_with_today(date)

        if strict then
            local today = diff.days == 0 and diff.weeks == 0
            if today then
                return false
            end
        end

        return diff.days >= 0 and diff.weeks >= 0
    end,
}

module.private = {
    --- Insert formatted `content` in `t`, with `prefix` before it. Mutates `t` !
    --- @param t table
    --- @param content string|table
    --- @param prefix string
    insert_content = function(t, content, prefix)
        vim.validate({
            t = { t, "table" },
            content = {
                content,
                function(c)
                    return vim.tbl_contains({ "nil", "string", "table" }, type(c))
                end,
                "string|table",
            },
            prefix = { prefix, "string" },
        })

        if not content then
            return
        end

        if type(content) == "string" then
            table.insert(t, prefix .. " " .. content)
        elseif type(content) == "table" then
            local inserted = prefix
            for _, v in pairs(content) do
                inserted = inserted .. " " .. v
            end
            table.insert(t, inserted)
        end
    end,

    --- Converts seconds to an actual table
    --- @param seconds number
    --- @return dateDiff
    convert_seconds = function(seconds)
        local negative_values = false
        if seconds < 0 then
            seconds = math.abs(seconds)
            negative_values = true
        end

        local weeksDiff = math.floor(seconds / 604800)
        local remainder = (seconds % 604800)
        local daysDiff = math.floor(remainder / 86400)

        if negative_values then
            weeksDiff = weeksDiff ~= 0 and -weeksDiff or 0
            daysDiff = daysDiff ~= 0 and -daysDiff or 0
        end

        local res = {
            weeks = weeksDiff,
            days = daysDiff,
        }
        return res
    end,
}

return module
