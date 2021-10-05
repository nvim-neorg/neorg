local module = neorg.modules.extend("core.gtd.queries.helpers")

--- @class dateDiff
--- @field weeks number
--- @field days number

module.public = {
    -- @Summary Convert a date from text to YY-MM-dd format
    -- @Description If the date is a quick capture (like 2w, 10d, 4m), it will convert to a standardized date
    -- Supported formats ($ treated as number):
    --   - $d: days from now (e.g 2d is 2 days from now)
    --   - $w: weeks from now (e.g 2w is 2 weeks from now)
    --   - $m: months from now (e.g 2m is 2 months from now)
    --   - tomorrow: tomorrow's date
    --   - today: today's date
    --   The format for date is YY-mm-dd
    -- @Param  text (string) the text to use
    date_converter = function(text)
        -- Get today's date
        local now = os.date("%Y-%m-%d")
        local y, m, d = now:match("(%d+)-(%d+)-(%d+)")

        -- Cases for converting quick dates to full dates (e.g 1w is one week from now)
        local converted_date
        local patterns = { weeks = "[%d]+w", days = "[%d]+d", months = "[%d]+m" }
        local days_matched = text:match(patterns.days)
        local weeks_matched = text:match(patterns.weeks)
        local months_matched = text:match(patterns.months)
        if text == "tomorrow" then
            converted_date = os.time({ year = y, month = m, day = d + 1 })
        elseif text == "today" then
            return now
        elseif weeks_matched ~= nil then
            converted_date = os.time({ year = y, month = m, day = d + 7 * weeks_matched:sub(1, -2) })
        elseif days_matched ~= nil then
            converted_date = os.time({ year = y, month = m, day = d + days_matched:sub(1, -2) })
        elseif months_matched ~= nil then
            converted_date = os.time({ year = y, month = m + months_matched:sub(1, -2), day = d })
        else
            return nil
        end
        return os.date("%Y-%m-%d", converted_date)
    end,

    --- Parses a date string to table relative to today's date
    --- (e.g { weeks = 2, days = 2, years= 0 } for in 2 weeks and 2 days)
    --- @param date string #A date formatted with YY-MM-dd format
    --- @return dateDiff
    diff_with_today = function(date)
        vim.validate({
            date = { date, "string" },
        })
        -- Get today's date
        local now = os.date("%Y-%m-%d")
        local y_now, m_now, d_now = now:match("(%d+)-(%d+)-(%d+)")
        local now_timestamp = os.time({ year = y_now, month = m_now, day = d_now })

        -- Parse date parameter
        local y, m, d = date:match("(%d+)-(%d+)-(%d+)")
        local date_timestamp = os.time({ year = y, month = m, day = d })

        -- Find out how many elapsed seconds between now and the date
        local elapsed_seconds = date_timestamp - now_timestamp
        elapsed_seconds = elapsed_seconds

        local elapsed = module.private.convert_seconds(elapsed_seconds)

        return elapsed
    end,
}

module.private = {
    --- Insert formatted `content` in `t`, with `prefix` before it. Mutates `t` !
    --- @param t table
    --- @param content string|table
    --- @param prefix string
    insert_content = function(t, content, prefix)
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
